import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/popup_service.dart';

class SiswaAdministrasiScreen extends StatefulWidget {
  final String siswaId;
  const SiswaAdministrasiScreen({super.key, required this.siswaId});

  @override
  State<SiswaAdministrasiScreen> createState() => _SiswaAdministrasiScreenState();
}

class _SiswaAdministrasiScreenState extends State<SiswaAdministrasiScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUploading = false;

  Map<String, dynamic> _biodata = {};
  List<Map<String, dynamic>> _riwayatBayar = [];
  
  // 🔥 REVISI DOSEN & AKUNTANSI: SPP DIHITUNG PER 1 SEMESTER (6 BULAN x Rp 250.000)
  final Map<String, int> _katalogTagihan = {
    'SPP Bulanan (1 Semester)': 1500000,
    'Semester (PTS/PAS)': 200000,
    'LKS': 300000,
    'Seragam': 850000,
    'Kegiatan PKL': 400000,
    'Daftar Ulang': 1500000,
  };

  final List<String> _listBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDataKeuangan();
  }

  Future<void> _fetchDataKeuangan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prof = await _supabase.from('profiles').select('*').eq('id', widget.siswaId).single();
      _biodata = prof;

      final resBayar = await _supabase.from('pembayaran').select('*').eq('siswa_id', widget.siswaId).order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _riwayatBayar = List<Map<String, dynamic>>.from(resBayar);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(context, 'Gagal memuat data keuangan Anda.', isSuccess: false, judul: 'Koneksi Error');
      }
    }
  }

  // =========================================================================
  // 🔥 DIALOG INPUT BAYAR / UNGGAH BUKTI TRANSAKSI OLEH SISWA
  // =========================================================================
  void _bukaDialogUploadBukti(String jenisTagihan, int sisaTagihan) {
    String kelasSiswa = (_biodata['kelas'] ?? '').toString().toLowerCase();
    bool isKelas10 = RegExp(r'\b(10|x)\b').hasMatch(kelasSiswa);
    bool isSPP = jenisTagihan.contains('SPP');
    
    int nominalFinal = isSPP ? 250000 : sisaTagihan;
    if (isSPP && isKelas10) {
      nominalFinal = 0; // Gratis Khusus Kelas 10
    }

    if (sisaTagihan == 0 || (nominalFinal == 0 && isKelas10)) {
      PopupService.show(context, 'Hore! Tagihan $jenisTagihan ini sudah LUNAS atau GRATIS untuk kelas Anda.', isSuccess: true, judul: 'Tagihan Selesai');
      return;
    }

    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final nominalCtrl = TextEditingController(text: formatter.format(nominalFinal));
    final keteranganCtrl = TextEditingController();
    String selectedBulan = _listBulan[DateTime.now().month - 1];
    XFile? fileBukti;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Bayar $jenisTagihan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isSPP 
                                ? 'Total 1 Semester: Rp 1.500.000\nSisa Belum Dibayar: Rp ${NumberFormat('#,###', 'id_ID').format(sisaTagihan)}'
                                : 'Sisa yang harus dibayar: Rp ${NumberFormat('#,###', 'id_ID').format(sisaTagihan)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade900, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isSPP) ...[
                      const Text('Pilih Bulan yang Dibayar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedBulan,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        items: _listBulan.map((b) => DropdownMenuItem(value: b, child: Text('SPP Bulan $b (Rp 250.000)', style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) { if (val != null) setStateDialog(() => selectedBulan = val); },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nominalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Nominal yang Dibayar (Rp)', prefixText: 'Rp ', border: OutlineInputBorder(), hintText: 'Bisa bayar penuh atau cicil'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keteranganCtrl,
                      decoration: const InputDecoration(labelText: 'Catatan (Opsional)', border: OutlineInputBorder(), hintText: 'Cth: Transfer via BCA a.n Budi'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Unggah Foto Bukti Transfer / Struk:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final foto = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
                        if (foto != null) setStateDialog(() => fileBukti = foto);
                      },
                      child: Container(
                        height: 80, width: double.infinity, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue)),
                        child: Center(
                          child: fileBukti == null 
                              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file, color: Colors.blue.shade700, size: 28), const SizedBox(height: 4), Text('Pilih Foto Galeri', style: TextStyle(color: Colors.blue.shade700, fontSize: 11, fontWeight: FontWeight.w600))])
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, color: Colors.green, size: 24), const SizedBox(width: 8), Text('Bukti Terlampir (${fileBukti!.name})', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: isSubmitting ? null : () async {
                    final nominalBersih = nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                    final nominal = int.tryParse(nominalBersih);
                    if (nominal == null || nominal <= 0) {
                      PopupService.show(context, 'Nominal pembayaran tidak valid.', isSuccess: false, judul: 'Peringatan'); return;
                    }
                    if (fileBukti == null) {
                      PopupService.show(context, 'Wajib melampirkan foto bukti transfer/pembayaran!', isSuccess: false, judul: 'Bukti Kosong'); return;
                    }

                    setStateDialog(() => isSubmitting = true);
                    try {
                      final user = _supabase.auth.currentUser;
                      if (user == null) throw 'Sesi habis, silakan login ulang.';

                      final ekstensi = fileBukti!.path.split('.').last;
                      final namaFile = 'BUKTI_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ekstensi';
                      await _supabase.storage.from('foto_absensi').upload(namaFile, File(fileBukti!.path));
                      final urlBukti = _supabase.storage.from('foto_absensi').getPublicUrl(namaFile);

                      String ketFinal = isSPP ? 'SPP Bulan $selectedBulan' : jenisTagihan;
                      if (keteranganCtrl.text.trim().isNotEmpty) {
                        ketFinal += ' - ${keteranganCtrl.text.trim()}';
                      }

                      await _supabase.from('pembayaran').insert({
                        'siswa_id': user.id,
                        'jenis_pembayaran': jenisTagihan,
                        'bulan_tagihan': ketFinal,
                        'nominal': nominal,
                        'status': 'Pending',
                        'foto_bukti': urlBukti,
                        'tanggal_bayar': DateTime.now().toIso8601String(),
                        'penerima': 'Menunggu Verifikasi TU',
                      });

                      if (!mounted) return;
                      Navigator.pop(context);
                      _fetchDataKeuangan();
                      PopupService.show(context, 'Pembayaran berhasil dikirim!\nSilakan tunggu admin Tata Usaha memverifikasi bukti transfer Anda.', isSuccess: true, judul: 'Terkirim!');
                    } catch (e) {
                      setStateDialog(() => isSubmitting = false);
                      PopupService.show(context, 'Gagal mengirim pembayaran: $e', isSuccess: false, judul: 'Gagal');
                    }
                  },
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Kirim Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 🔥 MUNCULKAN BOTTOM SHEET & TOMBOL PDF
  // =========================================================================
  void _bukaDetailHistori(String kategori, List<Map<String, dynamic>> riwayatItem, int totalDibayar, int kewajiban, int sisaKurang, bool isLunas) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isLunas ? Colors.green.shade50 : Colors.blue.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(
                  children: [
                    Icon(isLunas ? Icons.check_circle : Icons.history_rounded, color: isLunas ? Colors.green : const Color(0xFF1E40AF), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Histori Pembayaran', style: TextStyle(fontSize: 11, color: isLunas ? Colors.green.shade800 : Colors.blue.shade800, fontWeight: FontWeight.bold)),
                          Text(kategori, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              
              // RINGKASAN SALDO
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _itemSummary('Total Biaya', formatter.format(kewajiban), Colors.black87),
                    _itemSummary('Sudah Bayar', formatter.format(totalDibayar), Colors.green.shade700),
                    _itemSummary('Sisa Kurang', formatter.format(sisaKurang), isLunas ? Colors.green : Colors.red.shade700),
                  ],
                ),
              ),
              const Divider(height: 1),

              // DAFTAR RIWAYAT
              Expanded(
                child: riwayatItem.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Belum ada riwayat transaksi\nuntuk tagihan ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: riwayatItem.length,
                        itemBuilder: (context, index) {
                          final b = riwayatItem[index];
                          final nominal = b['nominal'] ?? 0;
                          final status = (b['status'] ?? 'Pending').toString().toUpperCase();
                          final ket = (b['bulan_tagihan'] ?? '-').toString();
                          final penerima = (b['penerima'] ?? '-').toString();

                          String waktuTampil = '-';
                          final rawDate = (b['tanggal_bayar'] ?? b['created_at'] ?? '').toString();
                          try {
                            if (rawDate.isNotEmpty) {
                              waktuTampil = DateFormat('dd MMMM yyyy | HH:mm WIB').format(DateTime.parse(rawDate).toLocal());
                            }
                          } catch (_) {}

                          Color badgeColor = Colors.orange;
                          if (status == 'LUNAS') badgeColor = Colors.green;
                          if (status == 'DITOLAK') badgeColor = Colors.red;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(formatter.format(nominal), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 14)),
                                      // 🔥 TOMBOL CETAK PDF
                                      if (status == 'LUNAS')
                                        IconButton(icon: const Icon(Icons.print, color: Colors.red, size: 20), tooltip: 'Cetak Kwitansi', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _cetakKwitansiPDF(b)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: badgeColor.withOpacity(0.4))),
                                        child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(waktuTampil, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Keterangan: $ket', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  const SizedBox(height: 2),
                                  Text('Kasir/Verifikator: $penerima', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
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
      },
    );
  }

  // =========================================================================
  // 🔥 FUNGSI PDF GENERATOR (MENGGUNAKAN DATA _biodata)
  // =========================================================================
  Future<void> _cetakKwitansiPDF(Map<String, dynamic> dataBayar) async {
    try {
      final pdf = pw.Document();
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      final rawDate = (dataBayar['tanggal_bayar'] ?? dataBayar['created_at'] ?? '').toString();
      String tglCetak = rawDate;
      try {
        if (rawDate.isNotEmpty) {
          tglCetak = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.parse(rawDate).toLocal());
        } else {
          tglCetak = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());
        }
      } catch (_) {
        tglCetak = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());
      }

      // 🔥 Menggunakan data dari state _biodata
      final namaSiswa = (_biodata['full_name'] ?? '-').toString();
      final kelasSiswa = (_biodata['kelas'] ?? '-').toString();
      final nisnSiswa = (_biodata['nisn'] ?? '-').toString();
      
      final nominal = dataBayar['nominal'] ?? 0;
      final jenisPembayaran = (dataBayar['jenis_pembayaran'] ?? '-').toString();
      final bulanTagihan = (dataBayar['bulan_tagihan'] ?? '-').toString();
      final penerima = (dataBayar['penerima'] ?? 'Menunggu Verifikasi TU').toString();
      final statusBayar = (dataBayar['status'] ?? 'PENDING').toString().toUpperCase();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5.landscape,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'BUKTI PEMBAYARAN RESMI (KWITANSI)',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'SMK ISLAM AL AYANIAH TANGERANG',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Container(width: 120, child: pw.Text('Telah Terima Dari')),
                      pw.Text(': $namaSiswa'),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Container(width: 120, child: pw.Text('Kelas / NISN')),
                      pw.Text(': $kelasSiswa / $nisnSiswa'),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Container(width: 120, child: pw.Text('Uang Sejumlah')),
                      pw.Text(
                        ': ${formatter.format(nominal)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 120, child: pw.Text('Untuk Pembayaran')),
                      pw.Expanded(
                        child: pw.Text(': $jenisPembayaran${bulanTagihan != '-' ? ' ($bulanTagihan)' : ''}'),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: statusBayar == 'LUNAS' ? PdfColors.green : PdfColors.orange),
                        ),
                        child: pw.Text(
                          'STATUS: $statusBayar',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: statusBayar == 'LUNAS' ? PdfColors.green : PdfColors.orange,
                          ),
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('Tangerang, $tglCetak', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(height: 40),
                          pw.Text(penerima, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text('Verifikator / Staf Keuangan', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Kwitansi_$namaSiswa',
      );
    } catch (e) {
      debugPrint('Error _cetakKwitansiPDF: $e');
      if (mounted) {
        PopupService.show(context, 'Gagal mencetak kwitansi: $e', isSuccess: false, judul: 'Error');
      }
    }
  }

  Widget _itemSummary(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    String kelasSiswa = (_biodata['kelas'] ?? '').toString().toLowerCase();
    bool isKelas10 = RegExp(r'\b(10|x)\b').hasMatch(kelasSiswa);

    Map<String, List<Map<String, dynamic>>> groupedBayar = {};
    for (var b in _riwayatBayar) {
      final jenis = (b['jenis_pembayaran'] ?? 'Lainnya').toString();
      groupedBayar.putIfAbsent(jenis, () => []).add(b);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tagihan & SPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading || _isUploading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchDataKeuangan,
            color: const Color(0xFF1E40AF),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700]), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Informasi Keuangan Siswa', style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4),
                      Text(_biodata['full_name'] ?? 'Siswa', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('Kelas: ${_biodata['kelas'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('DAFTAR KEWAJIBAN & STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 4),
                const Text('Klik pada kartu untuk melihat rincian tanggal & cetak kwitansi.', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _katalogTagihan.length,
                  itemBuilder: (context, index) {
                    final namaTagihan = _katalogTagihan.keys.elementAt(index);
                    final int kewajibanAsli = _katalogTagihan[namaTagihan]!;
                    final listTransaksi = groupedBayar[namaTagihan] ?? [];

                    bool isSPP = namaTagihan.contains('SPP');
                    bool isGratis = isSPP && isKelas10;
                    int kewajiban = isGratis ? 0 : kewajibanAsli;

                    int totalDibayar = 0;
                    bool adaPending = false;
                    for (var t in listTransaksi) {
                      final st = (t['status'] ?? '').toString().toUpperCase();
                      if (st == 'LUNAS') {
                        totalDibayar += (t['nominal'] is num) ? (t['nominal'] as num).toInt() : 0;
                      } else if (st == 'PENDING') {
                        adaPending = true;
                      }
                    }

                    final int sisaKurang = (kewajiban - totalDibayar) > 0 ? (kewajiban - totalDibayar) : 0;
                    final bool isLunas = isGratis || (sisaKurang == 0 && totalDibayar > 0);

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isLunas ? Colors.green.shade400 : Colors.grey.shade300, width: isLunas ? 1.5 : 1.0),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _bukaDetailHistori(namaTagihan, listTransaksi, totalDibayar, kewajiban, sisaKurang, isLunas),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isLunas ? Colors.green.shade50 : (adaPending ? Colors.orange.shade50 : Colors.blue.shade50),
                                child: Icon(
                                  isLunas ? Icons.verified_rounded : (adaPending ? Icons.access_time_filled_rounded : Icons.receipt_long_rounded),
                                  color: isLunas ? Colors.green : (adaPending ? Colors.orange : Colors.blue.shade900),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(namaTagihan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 4),
                                    
                                    if (isGratis)
                                      const Text('GRATIS (Siswa Kelas 10)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green))
                                    else if (isLunas)
                                      const Text('TELAH DIBAYAR LUNAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.green))
                                    else if (totalDibayar > 0) ...[
                                      Text('Total: ${formatter.format(kewajiban)} | Masuk: ${formatter.format(totalDibayar)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text('Sisa Kurang: ${formatter.format(sisaKurang)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                      if (adaPending)
                                        Text('⏳ Ada pembayaran menunggu verifikasi', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.orange.shade800)),
                                    ] else ...[
                                      Text('Total Tagihan: ${formatter.format(kewajiban)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text('Status: Belum Dibayar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                      if (adaPending)
                                        Text('⏳ Ada pembayaran menunggu verifikasi', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.orange.shade800)),
                                    ],
                                  ],
                                ),
                              ),

                              if (isLunas)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.check_circle, color: Colors.green, size: 34),
                                )
                              else
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                                  onPressed: () => _bukaDialogUploadBukti(namaTagihan, sisaKurang),
                                  child: const Text('BAYAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }
}