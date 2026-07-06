import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  
  @override
  void initState() {
    super.initState();
    _fetchDaftarKelas();
  }

  Future<void> _fetchDaftarKelas() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('profiles').select('kelas').eq('role', 'siswa');
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
      final res = await _supabase.from('profiles').select('id, full_name, nisn').eq('role', 'siswa').eq('kelas', kelas).order('full_name', ascending: true);
      setState(() {
        _listSiswa = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ==============================================================
  // 🔥 PERBAIKAN: EXPORT EXCEL DENGAN GROUPING KATEGORI NILAI
  // ==============================================================
  Future<void> _exportExcelSatuKelas() async {
    if (_selectedKelas == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyiapkan file Excel...'), backgroundColor: Colors.blue));
    
    try {
      // Ambil id siswa dari kelas yang dipilih
      final resSiswa = await _supabase.from('profiles').select('id, full_name, nisn').eq('role', 'siswa').eq('kelas', _selectedKelas!);
      List<String> listIdSiswa = resSiswa.map((e) => e['id'].toString()).toList();

      if(listIdSiswa.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada siswa di kelas ini'), backgroundColor: Colors.orange));
        return;
      }

      // Ambil semua nilai berdasarkan ID siswa
      final resNilai = await _supabase.from('nilai').select('*').filter('siswa_id', 'in', listIdSiswa);

      // Kelompokkan data per Siswa dan per Mapel
      Map<String, Map<String, dynamic>> rekapData = {};
      for (var item in resNilai) {
        String sId = item['siswa_id'].toString();
        String mapel = item['mapel'] ?? '-';
        String key = "${sId}_$mapel";

        if(!rekapData.containsKey(key)) {
          var dataSiswa = resSiswa.firstWhere((s) => s['id'].toString() == sId, orElse: () => {'full_name': '-', 'nisn': '-'});
          rekapData[key] = {
            'nama': dataSiswa['full_name'] ?? '-',
            'nisn': dataSiswa['nisn'] ?? '-',
            'mapel': mapel,
            'tugas': 0.0,
            'uts': 0.0,
            'uas': 0.0
          };
        }

        String kategori = (item['kategori'] ?? '').toString().toLowerCase();
        double nilai = double.tryParse(item['nilai']?.toString() ?? '0') ?? 0;

        if (kategori.contains('tugas')) rekapData[key]!['tugas'] = nilai;
        else if (kategori.contains('uts') || kategori.contains('pts')) rekapData[key]!['uts'] = nilai;
        else if (kategori.contains('uas') || kategori.contains('pas')) rekapData[key]!['uas'] = nilai;
      }
      
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Rekap_Kelas_$_selectedKelas'];
      excel.setDefaultSheet('Rekap_Kelas_$_selectedKelas');

      sheetObject.appendRow([TextCellValue('REKAPITULASI NILAI KELAS $_selectedKelas')]);
      sheetObject.appendRow([TextCellValue('')]);
      sheetObject.appendRow([TextCellValue('Nama Siswa'), TextCellValue('NISN'), TextCellValue('Mapel'), TextCellValue('Tugas'), TextCellValue('UTS'), TextCellValue('UAS'), TextCellValue('Nilai Akhir')]);

      // Masukkan data ke format baris
      rekapData.values.forEach((n) {
        double tugas = n['tugas'];
        double uts = n['uts'];
        double uas = n['uas'];
        double akhir = (tugas * 0.3) + (uts * 0.3) + (uas * 0.4);

        sheetObject.appendRow([
          TextCellValue(n['nama']), TextCellValue(n['nisn']), TextCellValue(n['mapel']),
          DoubleCellValue(tugas), DoubleCellValue(uts), DoubleCellValue(uas), DoubleCellValue(double.parse(akhir.toStringAsFixed(1))),
        ]);
      });

      Directory dir = await getApplicationDocumentsDirectory();
      String path = '${dir.path}/Rekap_Nilai_Kelas_$_selectedKelas.xlsx';
      File(path)..createSync(recursive: true)..writeAsBytesSync(excel.encode()!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil! Tersimpan di: $path'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Super Manajemen Nilai', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_shared_rounded, color: Color(0xFF1E40AF), size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedKelas, decoration: InputDecoration(labelText: 'Pilih Kelas', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: _listKelas.map((k) => DropdownMenuItem(value: k, child: Text('Kelas $k', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) { if (val != null) { setState(() => _selectedKelas = val); _fetchSiswaByKelas(val); } },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _listSiswa.isEmpty ? null : _exportExcelSatuKelas,
                    icon: const Icon(Icons.download_rounded), label: Text('Download Excel (Seluruh Kelas $_selectedKelas)'),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator())
              : _listSiswa.isEmpty ? const Center(child: Text('Belum ada siswa di kelas ini.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16), itemCount: _listSiswa.length,
                      itemBuilder: (context, index) {
                        final siswa = _listSiswa[index];
                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.person, color: Color(0xFF1E40AF))),
                            title: Text(siswa['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('NISN: ${siswa['nisn']}'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RaporDetailScreen(idSiswa: siswa['id'], namaSiswa: siswa['full_name'], kelas: _selectedKelas!, nisn: siswa['nisn'] ?? '-'))),
                              child: const Text('Buka Rapor'),
                            ),
                          ),
                        );
                      },
                    )
          )
        ],
      ),
    );
  }
}

class RaporDetailScreen extends StatefulWidget {
  final String idSiswa, namaSiswa, kelas, nisn;
  const RaporDetailScreen({super.key, required this.idSiswa, required this.namaSiswa, required this.kelas, required this.nisn});

  @override
  State<RaporDetailScreen> createState() => _RaporDetailScreenState();
}

class _RaporDetailScreenState extends State<RaporDetailScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _nilaiData = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetchNilaiSiswa(); }

  // ==============================================================
  // 🔥 PERBAIKAN: GROUPING DATA MATA PELAJARAN DI E-RAPOR PDF
  // ==============================================================
  Future<void> _fetchNilaiSiswa() async {
    final res = await _supabase.from('nilai').select('*').eq('siswa_id', widget.idSiswa);
    
    Map<String, Map<String, dynamic>> mapelData = {};

    for(var item in res) {
      String mapel = item['mapel'] ?? '-';
      String kategori = (item['kategori'] ?? '').toString().toLowerCase();
      double nilai = double.tryParse(item['nilai']?.toString() ?? '0') ?? 0;

      if (!mapelData.containsKey(mapel)) {
        mapelData[mapel] = {'tugas': 0.0, 'uts': 0.0, 'uas': 0.0};
      }

      // Memilah nilai masuk ke kantong yang mana
      if (kategori.contains('tugas')) {
        mapelData[mapel]!['tugas'] = nilai;
      } else if (kategori.contains('uts') || kategori.contains('pts')) {
        mapelData[mapel]!['uts'] = nilai;
      } else if (kategori.contains('uas') || kategori.contains('pas')) {
        mapelData[mapel]!['uas'] = nilai;
      }
    }

    List<Map<String, dynamic>> cleanedData = [];
    
    mapelData.forEach((mapel, scores) {
      double tugas = scores['tugas'];
      double uts = scores['uts'];
      double uas = scores['uas'];
      
      // Rumus Penilaian
      double akhir = (tugas * 0.3) + (uts * 0.3) + (uas * 0.4);
      String predikat = akhir >= 90 ? 'A' : akhir >= 80 ? 'B' : akhir >= 70 ? 'C' : 'D';

      cleanedData.add({
        'mapel': mapel,
        'tugas': tugas.toStringAsFixed(0),
        'uts': uts.toStringAsFixed(0),
        'uas': uas.toStringAsFixed(0),
        'akhir': akhir.toStringAsFixed(1),
        'predikat': predikat
      });
    });

    setState(() { _nilaiData = cleanedData; _isLoading = false; });
  }

  Future<void> _cetakPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Text('LAPORAN HASIL BELAJAR (RAPOR)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('SMK ISLAM YIA TANGERANG', style: pw.TextStyle(fontSize: 12))),
            pw.SizedBox(height: 20),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Nama Siswa : ${widget.namaSiswa}'), pw.Text('NISN       : ${widget.nisn}')]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Kelas      : ${widget.kelas}'), pw.Text('Semester   : Ganjil')]),
            ]),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              cellAlignment: pw.Alignment.center, headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headers: ['Mata Pelajaran', 'Tugas', 'UTS', 'UAS', 'Akhir', 'Predikat'],
              data: _nilaiData.map((n) => [n['mapel'], n['tugas'], n['uts'], n['uas'], n['akhir'], n['predikat']]).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Rapor Akademik', style: TextStyle(color: Colors.black, fontSize: 16)), backgroundColor: Colors.white, elevation: 0.5, iconTheme: const IconThemeData(color: Colors.black)),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: Text('LAPORAN HASIL BELAJAR SISWA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const Divider(thickness: 2, color: Colors.black, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Nama: ${widget.namaSiswa}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('NISN: ${widget.nisn}')]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Kelas: ${widget.kelas}', style: const TextStyle(fontWeight: FontWeight.bold)), const Text('Semester: Ganjil')]),
                ],
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  border: TableBorder.all(color: Colors.grey.shade400), headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                  columns: const [
                    DataColumn(label: Text('Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tugas')), DataColumn(label: Text('UTS')), DataColumn(label: Text('UAS')),
                    DataColumn(label: Text('Nilai Akhir', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Predikat')),
                  ],
                  rows: _nilaiData.map((n) {
                    return DataRow(cells: [
                      DataCell(Text(n['mapel'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))), 
                      DataCell(Text(n['tugas'])), DataCell(Text(n['uts'])), DataCell(Text(n['uas'])),
                      DataCell(Text(n['akhir'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                      DataCell(Text(n['predikat'], style: TextStyle(color: n['predikat'] == 'D' ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, onPressed: _cetakPDF, icon: const Icon(Icons.picture_as_pdf), label: const Text('Cetak Rapor PDF')),
    );
  }
}