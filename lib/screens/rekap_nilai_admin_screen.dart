import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:cross_file/cross_file.dart'; 

import 'nilai_rapor_screen.dart';

class RekapNilaiAdminScreen extends StatefulWidget {
  const RekapNilaiAdminScreen({super.key});

  @override
  State<RekapNilaiAdminScreen> createState() => _RekapNilaiAdminScreenState();
}

class _RekapNilaiAdminScreenState extends State<RekapNilaiAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<String> _listKelas = [];
  String? _selectedKelas;
  List<Map<String, dynamic>> _listSiswa = [];
  String _searchQuery = ''; 

  // 🔥 VARIABEL HISTORI SEMESTER & TAHUN AJARAN
  String _selectedSmt = 'Ganjil';
  String _selectedTa = '';
  final List<String> _listTahunAjaran = ['2024/2025', '2025/2026', '2026/2027', '2027/2028'];

  @override
  void initState() {
    super.initState();
    
    // Otomatis mendeteksi Tahun Ajaran dan Semester berjalan saat ini
    DateTime now = DateTime.now();
    int currentYear = now.month >= 7 ? now.year : now.year - 1;
    _selectedTa = '$currentYear/${currentYear + 1}';
    _selectedSmt = now.month >= 7 ? 'Ganjil' : 'Genap';

    _fetchDaftarKelas();
  }

  Future<void> _fetchDaftarKelas() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('kelas')
          .eq('role', 'siswa');
          
      final Set<String> kelasSet = {};
      for (var item in res) {
        if (item['kelas'] != null && item['kelas'].toString().trim().isNotEmpty) {
          kelasSet.add(item['kelas'].toString().trim());
        }
      }

      setState(() {
        _listKelas = kelasSet.toList()..sort();
        if (_listKelas.isNotEmpty) _selectedKelas = _listKelas.first;
      });

      if (_selectedKelas != null) {
        await _fetchSiswaByKelas(_selectedKelas!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSiswaByKelas(String kelas) async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, nisn, kelas, foto_profil')
          .eq('role', 'siswa')
          .eq('kelas', kelas)
          .order('full_name', ascending: true);
          
      setState(() {
        _listSiswa = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 EXCEL SEKARANG MENGGUNAKAN FILTER HISTORI
  Future<void> _exportExcelSatuKelas() async {
    if (_selectedKelas == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyiapkan file Excel...'), backgroundColor: Colors.blue),
    );

    try {
      final resSiswa = await _supabase
          .from('profiles')
          .select('id, full_name, nisn')
          .eq('role', 'siswa')
          .eq('kelas', _selectedKelas!);
          
      List<String> listIdSiswa = resSiswa.map((e) => e['id'].toString()).toList();

      if (listIdSiswa.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada siswa di kelas ini'), backgroundColor: Colors.orange),
        );
        return;
      }

      // 🔥 FILTER DATA NILAI BERDASARKAN SEMESTER & TAHUN AJARAN YANG DIPILIH
      String smtFilter = _selectedSmt == 'Ganjil' ? 'Semester 1 (Ganjil)' : 'Semester 2 (Genap)';
      
      final resNilai = await _supabase
          .from('nilai')
          .select('*')
          .filter('siswa_id', 'in', listIdSiswa)
          .eq('semester', smtFilter)
          .eq('tahun_ajaran', _selectedTa);

      Map<String, Map<String, dynamic>> rekapData = {};
      for (var item in resNilai) {
        String sId = item['siswa_id'].toString();
        String mapel = item['mapel'] ?? '-';
        String key = "${sId}_$mapel";

        if (!rekapData.containsKey(key)) {
          var dataSiswa = resSiswa.firstWhere(
            (s) => s['id'].toString() == sId,
            orElse: () => {'full_name': '-', 'nisn': '-'},
          );
          rekapData[key] = {
            'nama': dataSiswa['full_name'] ?? '-',
            'nisn': dataSiswa['nisn'] ?? '-',
            'mapel': mapel,
            'harian': 0.0,
            'tugas': 0.0,
            'praktek': 0.0,
            'pts': 0.0,
            'pas': 0.0,
          };
        }

        String kategori = (item['kategori'] ?? '').toString().toLowerCase();
        double nilai = double.tryParse(item['nilai']?.toString() ?? '0') ?? 0;

        if (kategori.contains('harian') || kategori.contains('ulangan')) {
            rekapData[key]!['harian'] = nilai;
        } else if (kategori.contains('tugas')) {
            rekapData[key]!['tugas'] = nilai;
        } else if (kategori.contains('praktek')) {
            rekapData[key]!['praktek'] = nilai;
        } else if (kategori.contains('uts') || kategori.contains('pts')) {
            rekapData[key]!['pts'] = nilai;
        } else if (kategori.contains('uas') || kategori.contains('pas')) {
            rekapData[key]!['pas'] = nilai;
        }
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Rekap_Kelas_$_selectedKelas'];
      excel.setDefaultSheet('Rekap_Kelas_$_selectedKelas');

      CellStyle headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      sheetObject.appendRow([TextCellValue('REKAPITULASI NILAI KELAS $_selectedKelas')]);
      sheetObject.appendRow([TextCellValue('PERIODE: $_selectedSmt - $_selectedTa')]);
      sheetObject.appendRow([TextCellValue('')]);
      
      var headerRow = [
        TextCellValue('Nama Siswa'),
        TextCellValue('NISN'),
        TextCellValue('Mata Pelajaran'),
        TextCellValue('Rata2 Harian/Tugas'),
        TextCellValue('Praktek'),
        TextCellValue('PTS'),
        TextCellValue('PAS'),
        TextCellValue('Nilai Akhir'),
        TextCellValue('Mutu'),
      ];
      sheetObject.appendRow(headerRow);
      
      for (int i = 0; i < headerRow.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
        cell.cellStyle = headerStyle;
      }

      rekapData.values.forEach((n) {
        double harian = n['harian'];
        double tugas = n['tugas'];
        double rataHarian = (harian + tugas) / (harian > 0 && tugas > 0 ? 2 : 1); 
        if (harian == 0 && tugas == 0) rataHarian = 0;

        double praktek = n['praktek'];
        double pts = n['pts'];
        double pas = n['pas'];
        
        double akhir = (rataHarian * 0.3) + (praktek * 0.2) + (pts * 0.2) + (pas * 0.3);

        String mutu = 'D';
        if (akhir >= 90) mutu = 'A';
        else if (akhir >= 80) mutu = 'B';
        else if (akhir >= 70) mutu = 'C';

        sheetObject.appendRow([
          TextCellValue(n['nama']),
          TextCellValue(n['nisn']),
          TextCellValue(n['mapel']),
          DoubleCellValue(double.parse(rataHarian.toStringAsFixed(1))),
          DoubleCellValue(praktek),
          DoubleCellValue(pts),
          DoubleCellValue(pas),
          DoubleCellValue(double.parse(akhir.toStringAsFixed(1))),
          TextCellValue(mutu),
        ]);
      });

      Directory dir = await getApplicationDocumentsDirectory();
      String namaSmt = _selectedSmt.toLowerCase();
      String namaTa = _selectedTa.replaceAll('/', '-');
      String path = '${dir.path}/Rekap_Nilai_${_selectedKelas}_${namaSmt}_$namaTa.xlsx';
      
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil dibuat! Membuka opsi bagikan...'), backgroundColor: Colors.green),
      );

      await Share.shareXFiles([XFile(path)], text: 'Ini adalah file Excel Rekap Nilai Kelas $_selectedKelas ($_selectedSmt $_selectedTa)');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredSiswa = _listSiswa.where((u) {
      if (_searchQuery.isEmpty) return true;
      final nama = (u['full_name'] ?? '').toString().toLowerCase();
      final nisn = (u['nisn'] ?? '').toString().toLowerCase();
      return nama.contains(_searchQuery) || nisn.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Super Manajemen E-Rapor',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // 🔥 TAMBAHAN FILTER HISTORI
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedSmt,
                        decoration: InputDecoration(labelText: 'Semester', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        items: ['Ganjil', 'Genap'].map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
                        onChanged: (val) { if (val != null) setState(() => _selectedSmt = val); },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedTa,
                        decoration: InputDecoration(labelText: 'Tahun Ajaran', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        items: _listTahunAjaran.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
                        onChanged: (val) { if (val != null) setState(() => _selectedTa = val); },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.folder_shared_rounded, color: Colors.indigo, size: 26)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedKelas,
                        decoration: InputDecoration(labelText: 'Pilih Kelas', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        items: _listKelas.map((k) => DropdownMenuItem(value: k, child: Text('Kelas $k', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedKelas = val);
                            _fetchSiswaByKelas(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(hintText: 'Cari Nama / NISN Siswa...', prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _listSiswa.isEmpty ? null : _exportExcelSatuKelas,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text('Download Excel (Periode $_selectedSmt $_selectedTa)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSiswa.isEmpty
                ? const Center(child: Text('Belum ada siswa di kelas ini.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredSiswa.length,
                    itemBuilder: (context, index) {
                      final siswa = filteredSiswa[index];
                      String fotoProfil = siswa['foto_profil'] ?? '';
                      
                      return Card(
                        elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            radius: 22, backgroundColor: const Color(0xFFDBEAFE),
                            backgroundImage: fotoProfil.isNotEmpty ? NetworkImage(fotoProfil) : null,
                            child: fotoProfil.isEmpty ? const Icon(Icons.person, color: Color(0xFF1E40AF)) : null,
                          ),
                          title: Text(siswa['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('NISN: ${siswa['nisn']}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NilaiRaporScreen(
                                  siswaId: siswa['id'].toString(),
                                  // 🔥 Mengirim parameter ke e-Rapor
                                  initialSemester: _selectedSmt, 
                                  initialTahunAjaran: _selectedTa,
                                ),
                              ),
                            ),
                            child: const Text('Buka Rapor', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}