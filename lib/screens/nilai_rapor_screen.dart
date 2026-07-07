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
        String mapel = n['mapel'] ?? n['mata_pelajaran'] ?? '-';
        String kategori = (n['kategori'] ?? '').toString().toLowerCase();
        double nilai = double.tryParse(n['nilai'].toString()) ?? 0.0;

        if (!pivot.containsKey(mapel)) {
          pivot[mapel] = {'Ulangan Harian': 0.0, 'Praktek': 0.0, 'PTS': 0.0, 'PAS': 0.0};
        }

        // 🔥 TUGAS & HARIAN OTOMATIS MASUK KE KOLOM "ULANGAN HARIAN"
        if (kategori.contains('tugas') || kategori.contains('harian')) {
          if (pivot[mapel]!['Ulangan Harian'] == 0.0) {
            pivot[mapel]!['Ulangan Harian'] = nilai;
          } else {
            pivot[mapel]!['Ulangan Harian'] = (pivot[mapel]!['Ulangan Harian']! + nilai) / 2;
          }
        } 
        else if (kategori.contains('praktek')) pivot[mapel]!['Praktek'] = nilai;
        else if (kategori.contains('uts') || kategori.contains('pts')) pivot[mapel]!['PTS'] = nilai;
        else if (kategori.contains('uas') || kategori.contains('pas')) pivot[mapel]!['PAS'] = nilai;
      }

      List<Map<String, dynamic>> tempPivotData = pivot.entries.map((e) {
        double ulanganHarian = e.value['Ulangan Harian']!; 
        double praktek = e.value['Praktek']!; 
        double pts = e.value['PTS']!; 
        double pas = e.value['PAS']!;
        
        // Rumus Nilai Akhir
        double akhir = (ulanganHarian + praktek + pts + pas) / 4; 
        
        String predikat;
        if (akhir >= 90) predikat = 'A';
        else if (akhir >= 80) predikat = 'B';
        else if (akhir >= 70) predikat = 'C';
        else predikat = 'D';

        return {
          'mapel': e.key, 
          'ulangan_harian': ulanganHarian, 
          'praktek': praktek, 
          'pts': pts, 
          'pas': pas, 
          'akhir': akhir,
          'predikat': predikat
        };
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
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            final now = DateTime.now();
            return pw.Column(
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
                          pw.Text('YAYASAN ISLAM AL AYANIAH', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('SMK ISLAM AL AYANIAH TANGERANG', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.SizedBox(height: 4),
                          pw.Text('Jl. Halim Perdana Kusuma No 56-60 Kebon Besar Batu Ceper', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Kota Tangerang - BANTEN 15122 | Telp : 0899-8687-769', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.Image(imgSmk, width: 65, height: 65),
                  ],
                ),
                pw.SizedBox(height: 8), pw.Container(height: 2, color: PdfColors.black), pw.SizedBox(height: 1.5), pw.Container(height: 0.5, color: PdfColors.black), pw.SizedBox(height: 20),
                
                pw.Center(child: pw.Text('PENCAPAIAN KOMPETENSI PESERTA DIDIK', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 16),
                
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Nama Siswa  : $_namaSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.SizedBox(height: 4), 
                      pw.Text('NISN / NIPD   : $_nisnSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
                    ])),
                    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text('Kelas Aktif  : $_kelasSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.SizedBox(height: 4), 
                      pw.Text('Semester    : $_selectedSemester', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
                    ])),
                  ],
                ),
                pw.SizedBox(height: 16),
                
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5), 
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10), 
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900), 
                  cellHeight: 28, cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignments: { 0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.center, 5: pw.Alignment.center, 6: pw.Alignment.center },
                  // 🔥 NAMA KOLOM DIUBAH MENJADI "Ulangan Harian"
                  headers: ['No', 'Mata Pelajaran', 'KKM', 'Ulangan Harian', 'Praktek', 'PTS/PAS', 'Nilai Akhir', 'Huruf'],
                  data: List<List<dynamic>>.generate(_dataRaporPivoted.length, (index) {
                    final n = _dataRaporPivoted[index];
                    double ptsPasAvg = (n['pts'] + n['pas']) / 2;
                    return [
                      (index + 1).toString(),
                      n['mapel'], 
                      '75', // KKM
                      n['ulangan_harian'] == 0 ? '-' : n['ulangan_harian'].toStringAsFixed(0), 
                      n['praktek'] == 0 ? '-' : n['praktek'].toStringAsFixed(0), 
                      ptsPasAvg == 0 ? '-' : ptsPasAvg.toStringAsFixed(0), 
                      n['akhir'].toStringAsFixed(0),
                      n['predikat']
                    ];
                  }),
                ),
                
                pw.SizedBox(height: 40),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Mengetahui,', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Orang Tua / Wali', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 60),
                        pw.Text('( ......................................... )', style: const pw.TextStyle(fontSize: 10)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Tangerang, ${now.day} ${_getNamaBulan(now.month)} ${now.year}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Kepala Sekolah,', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5), pw.Image(imgTtdStempel, width: 120, height: 80), pw.SizedBox(height: 5),
                        pw.Text('AGUS RAHMADANI, SE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'E-Rapor_${_namaSiswa}_$_selectedSemester');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rapor Akademik', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.print, size: 16), label: const Text('Cetak e-Rapor'),
            onPressed: _dataRaporPivoted.isEmpty ? null : _generatePdf,
          ), 
          const SizedBox(width: 16)
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: DropdownButtonFormField<String>(
              value: _selectedSemester, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1E40AF)),
              decoration: InputDecoration(
                labelText: 'Pilih Semester',
                filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFF1E40AF), width: 2)),
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
                        headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blue.shade900), columnSpacing: 25,
                        columns: const [
                          DataColumn(label: Text('Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          // 🔥 NAMA KOLOM DI APLIKASI JUGA DIGANTI MENJADI "Ulangan Harian"
                          DataColumn(label: Text('Ulangan Harian', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text('Praktek', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text('PTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text('PAS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text('Akhir', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                          DataColumn(label: Text('Mutu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        ],
                        rows: _dataRaporPivoted.map((n) {
                          bool isLulus = n['akhir'] >= 75.0; // KKM
                          return DataRow(
                            cells: [
                              DataCell(Text(n['mapel'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              DataCell(Text(n['ulangan_harian'] == 0 ? '-' : n['ulangan_harian'].toStringAsFixed(1))),
                              DataCell(Text(n['praktek'] == 0 ? '-' : n['praktek'].toStringAsFixed(1))),
                              DataCell(Text(n['pts'] == 0 ? '-' : n['pts'].toStringAsFixed(1))),
                              DataCell(Text(n['pas'] == 0 ? '-' : n['pas'].toStringAsFixed(1))),
                              DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isLulus ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text(n['akhir'].toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: isLulus ? Colors.green.shade700 : Colors.red.shade700)))),
                              DataCell(Text(n['predikat'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLulus ? Colors.blue.shade900 : Colors.red))),
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