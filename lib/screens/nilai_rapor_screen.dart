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
  List<Map<String, dynamic>> _dataNilai = [];
  bool _isLoading = true;
  String _selectedSemester = 'Semester 1 (Ganjil)';

  // Tambahan variabel untuk menyimpan data profil siswa
  String _namaSiswa = 'Memuat...';
  String _kelasSiswa = '-';
  String _nisnSiswa = '-';

  @override
  void initState() {
    super.initState();
    _fetchNilaiDanProfil();
  }

  Future<void> _fetchNilaiDanProfil() async {
    setState(() => _isLoading = true);

    try {
      // 1. Mengambil Profil Siswa (Nama, Kelas, NISN)
      final profileRes = await _supabase
          .from('profiles')
          .select('full_name, kelas, nisn')
          .eq('id', widget.siswaId)
          .single();

      if (mounted) {
        setState(() {
          _namaSiswa = profileRes['full_name'] ?? 'Nama Tidak Diketahui';
          _kelasSiswa = profileRes['kelas'] ?? '-';
          _nisnSiswa = profileRes['nisn'] ?? '-';
        });
      }

      // 2. Mengambil Data Nilai Rapor
      final resNilai = await _supabase
          .from('nilai')
          .select('*')
          .eq('siswa_id', widget.siswaId)
          .eq('semester', _selectedSemester)
          .order('mapel', ascending: true);

      if (mounted) {
        setState(() {
          _dataNilai = List<Map<String, dynamic>>.from(resNilai);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch nilai rapor: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil data rapor.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getNamaBulan(int bulan) {
    List<String> namaBulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return namaBulan[bulan - 1];
  }

  // 🔥 FUNGSI GENERATE PDF
  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    try {
      final imgBanten = await imageFromAssetBundle(
        'assets/images/logo_banten.jpg',
      );
      final imgSmk = await imageFromAssetBundle('assets/images/logo_smk.png');
      final imgTtdStempel = await imageFromAssetBundle(
        'assets/images/ttd_stempel.png',
      );

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
                  // ==========================================
                  // KOP SURAT SMK ISLAM YIA
                  // ==========================================
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(imgBanten, width: 65, height: 65),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'SEKOLAH MENENGAH KEJURUAN',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'SMK ISLAM YIA',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            // ✅ ERROR KOTAK SILANG DIPERBAIKI: Menggunakan strip biasa '-'
                            pw.Text(
                              'Jl. Halim Perdana Kusuma No 56-60 Kebon Besar Batu Ceper',
                              style: pw.TextStyle(fontSize: 9),
                            ),
                            pw.Text(
                              'Kota Tangerang - BANTEN 15122',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Telp : 0899 - 8687 - 769',
                              style: pw.TextStyle(fontSize: 9),
                            ),
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

                  // JUDUL DOKUMEN LAPORAN
                  pw.Center(
                    child: pw.Text(
                      'LAPORAN HASIL BELAJAR SISWA',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // ==========================================
                  // DATA IDENTITAS SISWA YANG SUDAH DIPERBAIKI
                  // ==========================================
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Nama Siswa  : $_namaSiswa',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'NISN             : $_nisnSiswa',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Kelas      : $_kelasSiswa',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Periode  : $_selectedSemester',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),

                  // TABEL DATA NILAI AKADEMIK
                  pw.Table.fromTextArray(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      fontSize: 10,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.blue900,
                    ),
                    cellHeight: 26,
                    cellStyle: pw.TextStyle(fontSize: 10),
                    cellAlignments: {
                      0: pw.Alignment.centerLeft,
                      1: pw.Alignment.center,
                      2: pw.Alignment.center,
                    },
                    headers: [
                      'Mata Pelajaran',
                      'Jenis Ujian',
                      'Nilai Akhir',
                    ], // Judul Kolom diubah
                    data: _dataNilai.map((n) {
                      return [
                        n['mapel']?.toString() ?? '-',
                        n['kategori']?.toString() ?? '-',
                        n['nilai']?.toString() ?? '-',
                      ];
                    }).toList(),
                  ),

                  pw.SizedBox(height: 45),

                  // ==========================================
                  // TANDA TANGAN & STEMPEL YIA
                  // ==========================================
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Tangerang, ${now.day} ${_getNamaBulan(now.month)} ${now.year}',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Kepala Sekolah,',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),

                        pw.Image(imgTtdStempel, width: 120, height: 80),

                        pw.SizedBox(height: 5),
                        pw.Text(
                          'AGUS RAHMADANI, SE',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'Rapor_${_namaSiswa}_$_selectedSemester', // Nama file PDF otomatis memakai nama siswa
      );
    } catch (e) {
      debugPrint('Gagal cetak PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Rapor Akademik',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF1E40AF),
            ),
            tooltip: 'Cetak PDF Rapor',
            onPressed: _dataNilai.isEmpty ? null : _generatePdf,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // DROPDOWN PILIHAN SEMESTER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedSemester,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF1E40AF),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blue.shade100,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1E40AF),
                    width: 2,
                  ),
                ),
              ),
              items: ['Semester 1 (Ganjil)', 'Semester 2 (Genap)']
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null && val != _selectedSemester) {
                  setState(() => _selectedSemester = val);
                  _fetchNilaiDanProfil(); // Panggil ulang saat semester ganti
                }
              },
            ),
          ),

          // DAFTAR NILAI DI LAYAR HP
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
                  )
                : _dataNilai.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada nilai yang diinputkan\nuntuk $_selectedSemester.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _dataNilai.length,
                    itemBuilder: (context, index) {
                      final n = _dataNilai[index];
                      final namaMapel =
                          n['mapel'] ?? 'Mata Pelajaran Tidak Diketahui';
                      final kategori = n['kategori'] ?? 'Ujian';
                      final double nilaiAngka =
                          double.tryParse(n['nilai'].toString()) ?? 0.0;

                      final bool isLulus = nilaiAngka >= 75.0;
                      final Color warnaNilai = isLulus
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.book_rounded,
                                  color: Color(0xFF1E40AF),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      namaMapel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        kategori,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: warnaNilai.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: warnaNilai.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    nilaiAngka.toInt().toString(),
                                    style: TextStyle(
                                      color: warnaNilai,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
