import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RekapNilaiAdminScreen extends StatefulWidget {
  const RekapNilaiAdminScreen({super.key});

  @override
  State<RekapNilaiAdminScreen> createState() => _RekapNilaiAdminScreenState();
}

class _RekapNilaiAdminScreenState extends State<RekapNilaiAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _dataNilaiAsli = [];
  List<Map<String, dynamic>> _dataNilaiFiltered = [];

  String _searchQuery = '';
  String _selectedKelas = 'Semua';
  List<String> _listKelas = ['Semua'];

  @override
  void initState() {
    super.initState();
    _fetchSemuaNilai();
  }

  Future<void> _fetchSemuaNilai() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('nilai')
          .select('*, siswa:profiles!nilai_siswa_id_fkey(full_name, nisn)')
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _dataNilaiAsli = List<Map<String, dynamic>>.from(res);

          Set<String> kelasUnik = {'Semua'};
          for (var item in _dataNilaiAsli) {
            if (item['kelas'] != null && item['kelas'].toString().isNotEmpty) {
              kelasUnik.add(item['kelas'].toString());
            }
          }
          _listKelas = kelasUnik.toList();
          _listKelas.sort();

          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error rekap nilai admin: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal memuat data nilai: $e', Colors.red);
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _dataNilaiFiltered = _dataNilaiAsli.where((item) {
        final nama = (item['siswa']?['full_name'] ?? '')
            .toString()
            .toLowerCase();
        final mapel = (item['mapel'] ?? '').toString().toLowerCase();
        final kelas = (item['kelas'] ?? '').toString();

        final matchSearch =
            nama.contains(_searchQuery) || mapel.contains(_searchQuery);
        final matchKelas = _selectedKelas == 'Semua' || kelas == _selectedKelas;

        return matchSearch && matchKelas;
      }).toList();
    });
  }

  // ==============================================================
  // 🔥 FITUR CETAK PDF DENGAN KOP SURAT & STEMPEL NATURAL
  // ==============================================================
  Future<void> _cetakLaporanNilaiPDF() async {
    if (_dataNilaiFiltered.isEmpty) {
      _showSnackBar('Tidak ada data nilai yang bisa dicetak!', Colors.orange);
      return;
    }

    // 1. Memuat Gambar dari Assets
    pw.MemoryImage? logoBanten;
    pw.MemoryImage? logoSmk;
    pw.MemoryImage? stempelImage;

    try {
      final bantenBytes = await rootBundle.load(
        'assets/images/logo_banten.jpg',
      );
      logoBanten = pw.MemoryImage(bantenBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Gagal memuat logo banten: $e');
    }

    try {
      final smkBytes = await rootBundle.load('assets/images/logo_smk.png');
      logoSmk = pw.MemoryImage(smkBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Gagal memuat logo smk: $e');
    }

    try {
      final stempelBytes = await rootBundle.load(
        'assets/images/ttd_stempel.png',
      );
      stempelImage = pw.MemoryImage(stempelBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Gagal memuat stempel: $e');
    }

    // 2. Membuat Struktur Dokumen PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ================= KOP SURAT RESMI =================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBanten != null)
                    pw.Image(
                      logoBanten,
                      width: 70,
                      height: 70,
                      fit: pw.BoxFit.contain,
                    )
                  else
                    pw.SizedBox(width: 70),

                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'MAJELIS PENDIDIKAN DASAR DAN MENENGAH',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'PIMPINAN DAERAH MUHAMMADIYAH TANGERANG',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'SMK ISLAM YIA',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          'STATUS: TERAKREDITASI "A"',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Jl. Raya Rajeg, Kabupaten Tangerang, Banten 15540',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Email: info@smkislamyia.sch.id | Website: www.smkislamyia.sch.id',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),

                  if (logoSmk != null)
                    pw.Image(
                      logoSmk,
                      width: 70,
                      height: 70,
                      fit: pw.BoxFit.contain,
                    )
                  else
                    pw.SizedBox(width: 70),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 2, color: PdfColors.black),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 16),

              // ================= JUDUL DOKUMEN =================
              pw.Center(
                child: pw.Text(
                  'LAPORAN REKAPITULASI NILAI AKADEMIK SISWA',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // ================= TABEL DATA =================
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey500,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(25), // No
                  1: const pw.FlexColumnWidth(3), // Nama
                  2: const pw.FixedColumnWidth(45), // Kelas
                  3: const pw.FlexColumnWidth(3), // Mapel
                  4: const pw.FlexColumnWidth(2), // Kategori
                  5: const pw.FixedColumnWidth(35), // Nilai
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildPdfHeaderCell('No'),
                      _buildPdfHeaderCell('Nama Siswa'),
                      _buildPdfHeaderCell('Kelas'),
                      _buildPdfHeaderCell('Mata Pelajaran'),
                      _buildPdfHeaderCell('Kategori'),
                      _buildPdfHeaderCell('Nilai'),
                    ],
                  ),
                  ...List.generate(_dataNilaiFiltered.length, (index) {
                    final item = _dataNilaiFiltered[index];
                    final prof = item['siswa'] ?? {};
                    return pw.TableRow(
                      children: [
                        _buildPdfDataCell('${index + 1}', alignCenter: true),
                        _buildPdfDataCell(prof['full_name'] ?? '-'),
                        _buildPdfDataCell(
                          item['kelas'] ?? '-',
                          alignCenter: true,
                        ),
                        _buildPdfDataCell(item['mapel'] ?? '-'),
                        _buildPdfDataCell(item['kategori'] ?? '-'),
                        _buildPdfDataCell(
                          item['nilai']?.toString() ?? '0',
                          isBold: true,
                          alignCenter: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 40),

              // ================= TANDA TANGAN & STEMPEL (STACK/TIMPA) =================
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Stack(
                    alignment: pw.Alignment.center,
                    children: [
                      // Posisi stempel di belakang/tengah teks agar natural
                      if (stempelImage != null)
                        pw.Positioned(
                          top: 15,
                          left: 10,
                          child: pw.Image(
                            stempelImage,
                            width: 140,
                            height: 80,
                            fit: pw.BoxFit.contain,
                          ),
                        ),

                      // Teks Tanda Tangan
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Tangerang, ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            'Kepala SMK ISLAM YIA,',
                            style: const pw.TextStyle(fontSize: 10),
                          ),

                          pw.SizedBox(
                            height: 65,
                          ), // Jarak ruang untuk stempel dan TTD

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
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekap_Nilai_Admin_$_selectedKelas.pdf',
    );
  }

  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  pw.Widget _buildPdfDataCell(
    String text, {
    bool isBold = false,
    bool alignCenter = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: alignCenter
          ? pw.Center(
              child: pw.Text(
                text,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: isBold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            )
          : pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
    );
  }

  // ==============================================================
  // FITUR SAKTI ADMIN: EDIT NILAI
  // ==============================================================
  void _tampilkanDialogEdit(Map<String, dynamic> data) {
    final TextEditingController nilaiController = TextEditingController(
      text: data['nilai'].toString(),
    );
    final TextEditingController kategoriController = TextEditingController(
      text: data['kategori'].toString(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF)),
              SizedBox(width: 8),
              Text(
                'Edit Nilai (Admin Mode)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Siswa: ${data['siswa']?['full_name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'Mapel: ${data['mapel']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: kategoriController,
                decoration: InputDecoration(
                  labelText: 'Kategori (Tugas/UTS/UAS)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nilaiController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Angka Nilai (0-100)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
              ),
              onPressed: () async {
                if (nilaiController.text.isEmpty ||
                    kategoriController.text.isEmpty) {
                  _showSnackBar('Data tidak boleh kosong!', Colors.orange);
                  return;
                }
                Navigator.pop(context);
                _prosesEditNilai(
                  data['id'],
                  kategoriController.text.trim(),
                  int.parse(nilaiController.text.trim()),
                );
              },
              child: const Text(
                'Simpan Perubahan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _prosesEditNilai(
    int idNilai,
    String kategoriBaru,
    int nilaiBaru,
  ) async {
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('nilai')
          .update({'kategori': kategoriBaru, 'nilai': nilaiBaru})
          .eq('id', idNilai);

      _showSnackBar('Nilai berhasil diperbarui secara paksa.', Colors.green);
      _fetchSemuaNilai();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Gagal mengedit nilai: $e', Colors.red);
    }
  }

  // ==============================================================
  // FITUR SAKTI ADMIN: HAPUS NILAI
  // ==============================================================
  void _konfirmasiHapus(int idNilai, String nama) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Data Nilai?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          'Tindakan ini akan menghapus nilai milik $nama secara permanen dari sistem. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _prosesHapusNilai(idNilai);
            },
            child: const Text(
              'Ya, Hapus',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prosesHapusNilai(int idNilai) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('nilai').delete().eq('id', idNilai);
      _showSnackBar('Data nilai berhasil dihapus.', Colors.green);
      _fetchSemuaNilai();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Gagal menghapus nilai: $e', Colors.red);
    }
  }

  void _showSnackBar(String pesan, Color warna) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Super Rekap Nilai',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Color(0xFF1E40AF)),
            tooltip: 'Cetak Rekap PDF',
            onPressed: _cetakLaporanNilaiPDF,
          ),
        ],
      ),
      body: Column(
        children: [
          // PANEL FILTER & PENCARIAN
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        onChanged: (value) {
                          _searchQuery = value.toLowerCase();
                          _applyFilter();
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari Nama / Mapel...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedKelas,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.filter_list_rounded,
                              size: 18,
                            ),
                            items: _listKelas.map((k) {
                              return DropdownMenuItem(
                                value: k,
                                child: Text(
                                  k == 'Semua' ? 'Semua Kelas' : 'Kelas $k',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _selectedKelas = val;
                                _applyFilter();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // DAFTAR NILAI
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
                  )
                : _dataNilaiFiltered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.find_in_page_rounded,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Data nilai tidak ditemukan.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _dataNilaiFiltered.length,
                    itemBuilder: (context, index) {
                      final data = _dataNilaiFiltered[index];
                      final prof = data['siswa'] ?? {};
                      final String namaSiswa =
                          prof['full_name'] ?? 'Tidak Diketahui';
                      final String nisn = prof['nisn'] ?? '-';
                      final String mapel = data['mapel'] ?? '-';
                      final String kategori = data['kategori'] ?? '-';
                      final int angkaNilai = data['nilai'] ?? 0;
                      final String kelas = data['kelas'] ?? '-';
                      final String guru = data['guru_pengampu'] ?? 'Sistem';

                      Color warnaNilai = Colors.green;
                      if (angkaNilai < 75) warnaNilai = Colors.red;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // INDIKATOR ANGKA NILAI
                              Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: warnaNilai.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: warnaNilai.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    angkaNilai.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: warnaNilai,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // DETAIL TEKS
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      namaSiswa,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'NISN: $nisn • Kelas $kelas',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Divider(height: 12),
                                    Text(
                                      '📚 Mapel: $mapel',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E40AF),
                                      ),
                                    ),
                                    Text(
                                      '📝 Kategori: $kategori',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    Text(
                                      '👨‍🏫 Guru Pengampu: $guru',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // TOMBOL AKSI ADMIN (EDIT & HAPUS)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    tooltip: 'Edit Nilai',
                                    onPressed: () => _tampilkanDialogEdit(data),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    tooltip: 'Hapus Nilai',
                                    onPressed: () =>
                                        _konfirmasiHapus(data['id'], namaSiswa),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
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
