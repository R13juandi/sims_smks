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

  @override
  void initState() {
    super.initState();
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
        if (item['kelas'] != null && item['kelas'].toString().isNotEmpty) {
          kelasSet.add(item['kelas'].toString());
        }
      }

      setState(() {
        _listKelas = kelasSet.toList()..sort();
        if (_listKelas.isNotEmpty) _selectedKelas = _listKelas.first;
        _isLoading = false;
      });

      if (_selectedKelas != null) _fetchSiswaByKelas(_selectedKelas!);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSiswaByKelas(String kelas) async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, nisn, kelas')
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

  // 🔥 FORMAT EXCEL DIRAPIKAN SESUAI INSTRUKSI (Harian, Praktek, PTS, PAS, Akhir, Mutu)
  Future<void> _exportExcelSatuKelas() async {
    if (_selectedKelas == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menyiapkan file Excel...'),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      final resSiswa = await _supabase
          .from('profiles')
          .select('id, full_name, nisn')
          .eq('role', 'siswa')
          .eq('kelas', _selectedKelas!);
      List<String> listIdSiswa = resSiswa
          .map((e) => e['id'].toString())
          .toList();

      if (listIdSiswa.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada siswa di kelas ini'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final resNilai = await _supabase
          .from('nilai')
          .select('*')
          .filter('siswa_id', 'in', listIdSiswa);

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

      // Styling untuk header
      CellStyle headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      sheetObject.appendRow([
        TextCellValue('REKAPITULASI NILAI KELAS $_selectedKelas')
      ]);
      sheetObject.appendRow([TextCellValue('')]);
      
      // Header Kolom
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
      
      // Menerapkan styling ke row header (asumsi index row 2)
      for (int i = 0; i < headerRow.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
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
        
        // Rumus sederhana (Bisa disesuaikan): 30% Harian, 20% Praktek, 20% PTS, 30% PAS
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
      String path = '${dir.path}/Rekap_Nilai_Kelas_$_selectedKelas.xlsx';
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil dibuat! Membuka opsi bagikan...'),
          backgroundColor: Colors.green,
        ),
      );

      await Share.shareXFiles([
        XFile(path),
      ], text: 'Ini adalah file Excel Rekap Nilai Kelas $_selectedKelas');
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
                Row(
                  children: [
                    const Icon(
                      Icons.folder_shared_rounded,
                      color: Color(0xFF1E40AF),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedKelas,
                        decoration: InputDecoration(
                          labelText: 'Pilih Kelas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _listKelas
                            .map(
                              (k) => DropdownMenuItem(
                                value: k,
                                child: Text(
                                  'Kelas $k',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
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
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari Nama / NISN Siswa...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _listSiswa.isEmpty
                        ? null
                        : _exportExcelSatuKelas,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      'Download Excel (Seluruh Kelas $_selectedKelas)',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSiswa.isEmpty
                ? const Center(child: Text('Belum ada siswa di kelas ini.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSiswa.length,
                    itemBuilder: (context, index) {
                      final siswa = filteredSiswa[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDBEAFE),
                            child: Icon(
                              Icons.analytics_rounded,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          title: Text(
                            siswa['full_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('NISN: ${siswa['nisn']}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NilaiRaporScreen(
                                  siswaId: siswa['id'].toString(),
                                  // 🔥 JIKA ANDA INGIN MENGIRIM DATA BIODATA SISWA KE RAPOR
                                  // pastikan NilaiRaporScreen menerima parameter tersebut jika diperlukan.
                                ),
                              ),
                            ),
                            child: const Text('Buka Rapor'),
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