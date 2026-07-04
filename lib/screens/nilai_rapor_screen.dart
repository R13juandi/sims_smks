import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class NilaiRaporScreen extends StatefulWidget {
  final String siswaId;
  const NilaiRaporScreen({super.key, required this.siswaId});

  @override
  State<NilaiRaporScreen> createState() => _NilaiRaporScreenState();
}

class _NilaiRaporScreenState extends State<NilaiRaporScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _selectedSemester = 'Semester 1 (Ganjil)';

  String _namaSiswa = 'Memuat...';
  String _kelasSiswa = '-';
  String _nisnSiswa = '-';
  List<Map<String, dynamic>> _dataRaporPivoted = [];

  @override
  void initState() {
    super.initState();
    _fetchNilaiDanProfil();
  }

  Future<void> _fetchNilaiDanProfil() async {
    setState(() => _isLoading = true);

    try {
      final profileRes = await _supabase.from('profiles').select('full_name, kelas, nisn').eq('id', widget.siswaId).single();
      if (mounted) {
        setState(() {
          _namaSiswa = profileRes['full_name'] ?? 'Nama Tidak Diketahui';
          _kelasSiswa = profileRes['kelas'] ?? '-';
          _nisnSiswa = profileRes['nisn'] ?? '-';
        });
      }

      final resNilai = await _supabase.from('nilai').select('*').eq('siswa_id', widget.siswaId).eq('semester', _selectedSemester);

      Map<String, Map<String, double>> pivot = {};
      for (var n in resNilai) {
        String mapel = n['mata_pelajaran'] ?? n['mapel'] ?? '-';
        String kategori = (n['kategori'] ?? '').toString().toLowerCase();
        double nilai = double.tryParse(n['nilai'].toString()) ?? 0.0;

        if (!pivot.containsKey(mapel)) pivot[mapel] = {'Tugas': 0.0, 'UTS': 0.0, 'UAS': 0.0};

        if (kategori.contains('tugas') || kategori.contains('harian') || kategori.contains('praktek')) pivot[mapel]!['Tugas'] = nilai;
        else if (kategori.contains('uts')) pivot[mapel]!['UTS'] = nilai;
        else if (kategori.contains('uas')) pivot[mapel]!['UAS'] = nilai;
      }

      List<Map<String, dynamic>> tempPivotData = pivot.entries.map((e) {
        double t = e.value['Tugas']!; double uts = e.value['UTS']!; double uas = e.value['UAS']!;
        double akhir = (t + uts + uas) / 3; 
        return {'mapel': e.key, 'tugas': t, 'uts': uts, 'uas': uas, 'akhir': akhir};
      }).toList();

      tempPivotData.sort((a, b) => a['mapel'].compareTo(b['mapel']));

      if (mounted) {
        setState(() { _dataRaporPivoted = tempPivotData; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengambil data rapor.'), backgroundColor: Colors.red));
      }
    }
  }

  String _getNamaBulan(int bulan) {
    List<String> namaBulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return namaBulan[bulan - 1];
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    try {
      final imgBanten = await imageFromAssetBundle('assets/images/logo_banten.jpg');
      final imgSmk = await imageFromAssetBundle('assets/images/logo_smk.png');
      final imgTtdStempel = await imageFromAssetBundle('assets/images/ttd_stempel.png');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final now = DateTime.now();
            return pw.Padding(
              padding: pw.EdgeInsets.all(15),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(imgBanten, width: 65, height: 65),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('SEKOLAH MENENGAH KEJURUAN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.Text('SMK ISLAM YIA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text('Jl. Halim Perdana Kusuma No 56-60 Kebon Besar Batu Ceper', style: pw.TextStyle(fontSize: 9)),
                            pw.Text('Kota Tangerang - BANTEN 15122', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Telp : 0899 - 8687 - 769', style: pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                      pw.Image(imgSmk, width: 65, height: 65),
                    ],
                  ),
                  pw.SizedBox(height: 8), pw.Container(height: 2, color: PdfColors.black), pw.SizedBox(height: 1.5), pw.Container(height: 0.5, color: PdfColors.black), pw.SizedBox(height: 20),
                  pw.Center(child: pw.Text('LAPORAN HASIL BELAJAR SISWA', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Nama Siswa  : $_namaSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.SizedBox(height: 4), pw.Text('NISN             : $_nisnSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))])),
                      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text('Kelas      : $_kelasSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.SizedBox(height: 4), pw.Text('Periode  : $_selectedSemester', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))])),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Table.fromTextArray(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10), headerDecoration: pw.BoxDecoration(color: PdfColors.blue900), cellHeight: 26, cellStyle: pw.TextStyle(fontSize: 9),
                    cellAlignments: { 0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.center },
                    headers: ['Mata Pelajaran', 'Nilai Tugas', 'Nilai UTS', 'Nilai UAS', 'Nilai Akhir'],
                    data: _dataRaporPivoted.map((n) {
                      return [n['mapel'], n['tugas'] == 0 ? '-' : n['tugas'].toStringAsFixed(1), n['uts'] == 0 ? '-' : n['uts'].toStringAsFixed(1), n['uas'] == 0 ? '-' : n['uas'].toStringAsFixed(1), n['akhir'].toStringAsFixed(1)];
                    }).toList(),
                  ),
                  pw.SizedBox(height: 45),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Tangerang, ${now.day} ${_getNamaBulan(now.month)} ${now.year}', style: pw.TextStyle(fontSize: 10)),
                        pw.Text('Kepala Sekolah,', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5), pw.Image(imgTtdStempel, width: 120, height: 80), pw.SizedBox(height: 5),
                        pw.Text('AGUS RAHMADANI, SE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Rapor_${_namaSiswa}_$_selectedSemester');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rapor Akademik', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: false, automaticallyImplyLeading: false,
        actions: [IconButton(icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1E40AF)), tooltip: 'Cetak PDF Rapor', onPressed: _dataRaporPivoted.isEmpty ? null : _generatePdf), const SizedBox(width: 12)],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: DropdownButtonFormField<String>(
              value: _selectedSemester, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1E40AF)),
              decoration: InputDecoration(
                filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 2)),
              ),
              items: ['Semester 1 (Ganjil)', 'Semester 2 (Genap)'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))))).toList(),
              onChanged: (val) { if (val != null && val != _selectedSemester) { setState(() => _selectedSemester = val); _fetchNilaiDanProfil(); } },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
                : _dataRaporPivoted.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 60, color: Colors.grey.shade400), const SizedBox(height: 16), Text('Belum ada nilai yang diinputkan\nuntuk $_selectedSemester.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5))]))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blue.shade50), columnSpacing: 25,
                        columns: const [
                          DataColumn(label: Text('Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                          DataColumn(label: Text('Tugas', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                          DataColumn(label: Text('UTS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                          DataColumn(label: Text('UAS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                          DataColumn(label: Text('Akhir', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                        ],
                        rows: _dataRaporPivoted.map((n) {
                          bool isLulus = n['akhir'] >= 75.0;
                          return DataRow(
                            cells: [
                              DataCell(Text(n['mapel'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              DataCell(Text(n['tugas'] == 0 ? '-' : n['tugas'].toStringAsFixed(1))),
                              DataCell(Text(n['uts'] == 0 ? '-' : n['uts'].toStringAsFixed(1))),
                              DataCell(Text(n['uas'] == 0 ? '-' : n['uas'].toStringAsFixed(1))),
                              DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isLulus ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(n['akhir'].toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: isLulus ? Colors.green.shade700 : Colors.red.shade700)))),
                            ]
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}