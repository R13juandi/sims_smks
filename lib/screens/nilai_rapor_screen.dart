import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/popup_service.dart'; // 🔥 IMPOR POPUP TENGAH LAYAR

class NilaiRaporScreen extends StatefulWidget {
  final String siswaId;
  const NilaiRaporScreen({super.key, required this.siswaId});

  @override
  State<NilaiRaporScreen> createState() => _NilaiRaporScreenState();
}

class _NilaiRaporScreenState extends State<NilaiRaporScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // 🔥 REVISI PAK HALIM: STATE UNTUK PILIHAN HISTORI RAPOR (KELAS X, XI, XII)
  String _selectedSemesterLabel = 'Memuat...';
  String _selectedSemesterQuery = 'Semester 1 (Ganjil)';
  List<Map<String, String>> _daftarHistoriSemester = [];

  String _namaSiswa = 'Memuat...';
  String _kelasSiswa = '-';
  String _nisnSiswa = '-';
  List<Map<String, dynamic>> _dataRaporPivoted = [];

  @override
  void initState() {
    super.initState();
    _initProfilDanHistori();
  }

  // =========================================================================
  // 🔥 ALGORITMA PENETAPAN OPSI HISTORI BERDASARKAN TINGKAT KELAS
  // =========================================================================
  Future<void> _initProfilDanHistori() async {
    setState(() => _isLoading = true);
    try {
      final profileRes = await _supabase
          .from('profiles')
          .select('full_name, kelas, nisn')
          .eq('id', widget.siswaId)
          .single();

      String kelasAktif = (profileRes['kelas'] ?? 'X').toString();

      List<Map<String, String>> histori = [];
      if (kelasAktif.startsWith('XII') || kelasAktif.startsWith('12')) {
        histori = [
          {'label': 'XII - Semester 1 (Ganjil) [Aktif]', 'query': 'Semester 1 (Ganjil)'},
          {'label': 'XI - Semester 2 (Genap) [Histori]', 'query': 'Semester 2 (Genap)'},
          {'label': 'XI - Semester 1 (Ganjil) [Histori]', 'query': 'Semester 1 (Ganjil)'},
          {'label': 'X - Semester 2 (Genap) [Histori]', 'query': 'Semester 2 (Genap)'},
          {'label': 'X - Semester 1 (Ganjil) [Histori]', 'query': 'Semester 1 (Ganjil)'},
        ];
      } else if (kelasAktif.startsWith('XI') || kelasAktif.startsWith('11')) {
        histori = [
          {'label': 'XI - Semester 1 (Ganjil) [Aktif]', 'query': 'Semester 1 (Ganjil)'},
          {'label': 'X - Semester 2 (Genap) [Histori]', 'query': 'Semester 2 (Genap)'},
          {'label': 'X - Semester 1 (Ganjil) [Histori]', 'query': 'Semester 1 (Ganjil)'},
        ];
      } else {
        histori = [
          {'label': 'X - Semester 1 (Ganjil) [Aktif]', 'query': 'Semester 1 (Ganjil)'},
          {'label': 'X - Semester 2 (Genap) [Aktif]', 'query': 'Semester 2 (Genap)'},
        ];
      }

      if (mounted) {
        setState(() {
          _namaSiswa = profileRes['full_name'] ?? 'Nama Tidak Diketahui';
          _kelasSiswa = kelasAktif;
          _nisnSiswa = profileRes['nisn'] ?? '-';
          _daftarHistoriSemester = histori;
          _selectedSemesterLabel = histori.first['label']!;
          _selectedSemesterQuery = histori.first['query']!;
        });
      }

      await _fetchNilaiDanProfil();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(context, 'Gagal memuat profil siswa: $e', isSuccess: false, judul: 'Gagal');
      }
    }
  }

  // =========================================================================
  // 🔥 ALGORITMA AGREGASI RAPOR SEJATI: RATA-RATA ULANGAN HARIAN AKURAT 100%
  // =========================================================================
  Future<void> _fetchNilaiDanProfil() async {
    setState(() => _isLoading = true);

    try {
      // 1. Kueri ke Supabase menggunakan filter semester terpilih
      final resNilai = await _supabase
          .from('nilai')
          .select('*')
          .eq('siswa_id', widget.siswaId)
          .ilike('semester', '%$_selectedSemesterQuery%');

      Map<String, Map<String, List<double>>> pivotLists = {};

      for (var n in resNilai) {
        String mapel = n['mapel'] ?? n['mata_pelajaran'] ?? '-';
        String kategori = (n['kategori'] ?? '').toString().toLowerCase();
        double nilai = double.tryParse(n['nilai'].toString()) ?? 0.0;

        if (!pivotLists.containsKey(mapel)) {
          pivotLists[mapel] = {
            'Ulangan Harian': [],
            'Praktek': [],
            'PTS': [],
            'PAS': []
          };
        }

        // Klasifikasi nilai ke dalam array kategori
        if (kategori.contains('tugas') || kategori.contains('harian') || kategori.contains('ulangan') || kategori == 'uh') {
          pivotLists[mapel]!['Ulangan Harian']!.add(nilai);
        } else if (kategori.contains('praktek')) {
          pivotLists[mapel]!['Praktek']!.add(nilai);
        } else if (kategori.contains('uts') || kategori.contains('pts')) {
          pivotLists[mapel]!['PTS']!.add(nilai);
        } else if (kategori.contains('uas') || kategori.contains('pas')) {
          pivotLists[mapel]!['PAS']!.add(nilai);
        }
      }

      // 🔥 FUNGSI KALKULASI RATA-RATA SEJATI (Sum / Length) - REVISI PAK HALIM
      double hitungRataRata(List<double> listNilai) {
        if (listNilai.isEmpty) return 0.0;
        double total = listNilai.fold(0.0, (sum, item) => sum + item);
        return total / listNilai.length;
      }

      List<Map<String, dynamic>> tempPivotData = pivotLists.entries.map((e) {
        double ulanganHarian = hitungRataRata(e.value['Ulangan Harian']!);
        double praktek = hitungRataRata(e.value['Praktek']!);
        double pts = hitungRataRata(e.value['PTS']!);
        double pas = hitungRataRata(e.value['PAS']!);

        // Hitung pembagi dinamis agar tidak membagi kategori yang belum diinput
        int pembagi = 0;
        double totalBobot = 0.0;
        if (ulanganHarian > 0) { totalBobot += ulanganHarian; pembagi++; }
        if (praktek > 0) { totalBobot += praktek; pembagi++; }
        if (pts > 0) { totalBobot += pts; pembagi++; }
        if (pas > 0) { totalBobot += pas; pembagi++; }

        double akhir = pembagi > 0 ? (totalBobot / pembagi) : 0.0;

        String predikat;
        if (akhir >= 90) {
          predikat = 'A';
        } else if (akhir >= 80) {
          predikat = 'B';
        } else if (akhir >= 70) {
          predikat = 'C';
        } else {
          predikat = 'D';
        }

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
        setState(() {
          _dataRaporPivoted = tempPivotData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(
          context,
          'Gagal mengambil data rapor: $e',
          isSuccess: false,
          judul: 'Gagal Memuat',
        );
      }
    }
  }

  String _getNamaBulan(int bulan) {
    List<String> namaBulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
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
                pw.SizedBox(height: 8),
                pw.Container(height: 2, color: PdfColors.black),
                pw.SizedBox(height: 1.5),
                pw.Container(height: 0.5, color: PdfColors.black),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text('PENCAPAIAN KOMPETENSI PESERTA DIDIK', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 16),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nama Siswa  : $_namaSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.SizedBox(height: 4),
                          pw.Text('NISN / NIPD   : $_nisnSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Kelas Aktif  : $_kelasSiswa', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.SizedBox(height: 4),
                          pw.Text('Periode     : $_selectedSemesterLabel', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellHeight: 28,
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.center,
                    4: pw.Alignment.center,
                    5: pw.Alignment.center,
                    6: pw.Alignment.center,
                    7: pw.Alignment.center
                  },
                  headers: ['No', 'Mata Pelajaran', 'KKM', 'Ulangan Harian*', 'Praktek', 'PTS/PAS', 'Nilai Akhir', 'Huruf'],
                  data: List<List<dynamic>>.generate(_dataRaporPivoted.length, (index) {
                    final n = _dataRaporPivoted[index];
                    double ptsPasAvg = (n['pts'] + n['pas']) / 2;
                    return [
                      (index + 1).toString(),
                      n['mapel'],
                      '75', // KKM
                      n['ulangan_harian'] == 0 ? '-' : n['ulangan_harian'].toStringAsFixed(1),
                      n['praktek'] == 0 ? '-' : n['praktek'].toStringAsFixed(1),
                      ptsPasAvg == 0 ? '-' : ptsPasAvg.toStringAsFixed(1),
                      n['akhir'].toStringAsFixed(1),
                      n['predikat']
                    ];
                  }),
                ),
                pw.SizedBox(height: 6),
                pw.Text('*Keterangan: Nilai Ulangan Harian dihitung dari Rata-Rata seluruh ulangan/tugas di semester ini.', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                pw.SizedBox(height: 30),
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
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Tangerang, ${now.day} ${_getNamaBulan(now.month)} ${now.year}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Kepala Sekolah,', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Image(imgTtdStempel, width: 120, height: 80),
                        pw.SizedBox(height: 5),
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
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'E-Rapor_${_namaSiswa}_$_selectedSemesterQuery',
      );
    } catch (e) {
      PopupService.show(
        context,
        'Error saat mencetak PDF: $e',
        isSuccess: false,
        judul: 'Gagal Mencetak',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rapor Akademik & Histori', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade900,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Cetak e-Rapor'),
            onPressed: _dataRaporPivoted.isEmpty ? null : _generatePdf,
          ),
          const SizedBox(width: 16)
        ],
      ),
      body: Column(
        children: [
          // 🔥 REVISI PAK HALIM: DROPDOWN PILIH HISTORI PERIODE KELAS (X, XI, XII)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: _daftarHistoriSemester.isEmpty
                ? const SizedBox.shrink()
                : DropdownButtonFormField<String>(
                    value: _selectedSemesterLabel,
                    isExpanded: true,
                    icon: const Icon(Icons.history_edu_rounded, color: Color(0xFF1E40AF)),
                    decoration: InputDecoration(
                      labelText: 'Pilih Periode Rapor',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5)),
                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFF1E40AF), width: 2)),
                    ),
                    items: _daftarHistoriSemester
                        .map((item) => DropdownMenuItem(
                              value: item['label'],
                              child: Text(item['label']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedSemesterLabel) {
                        final target = _daftarHistoriSemester.firstWhere((element) => element['label'] == val);
                        setState(() {
                          _selectedSemesterLabel = target['label']!;
                          _selectedSemesterQuery = target['query']!;
                        });
                        _fetchNilaiDanProfil();
                      }
                    },
                  ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
                : _dataRaporPivoted.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada nilai yang diinputkan\nuntuk periode "$_selectedSemesterLabel".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blue.shade900),
                            columnSpacing: 25,
                            columns: const [
                              DataColumn(label: Text('Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                              DataColumn(label: Text('Ulangan Harian*', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
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
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: isLulus ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: Text(n['akhir'].toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: isLulus ? Colors.green.shade700 : Colors.red.shade700)),
                                  )),
                                  DataCell(Text(n['predikat'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLulus ? Colors.blue.shade900 : Colors.red))),
                                ],
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