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

  Map<String, dynamic> _biodata = {};
  List<Map<String, dynamic>> _riwayatBayar = [];
  
  // Katalog SPP & Administrasi
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
  // FUNGSI PDF GENERATOR (Kwitansi)
  // =========================================================================
  Future<void> _cetakKwitansiPDF(Map<String, dynamic> dataBayar) async {
    try {
      final pdf = pw.Document();
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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
                  pw.Center(child: pw.Text('BUKTI PEMBAYARAN RESMI (KWITANSI)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
                  pw.Center(child: pw.Text('SMK ISLAM AL AYANIAH TANGERANG', style: const pw.TextStyle(fontSize: 12))),
                  pw.Divider(thickness: 2),
                  pw.SizedBox(height: 10),
                  pw.Row(children: [pw.Container(width: 120, child: pw.Text('Telah Terima Dari')), pw.Text(': $namaSiswa')]),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [pw.Container(width: 120, child: pw.Text('Kelas / NISN')), pw.Text(': $kelasSiswa / $nisnSiswa')]),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [pw.Container(width: 120, child: pw.Text('Uang Sejumlah')), pw.Text(': ${formatter.format(nominal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                  pw.SizedBox(height: 4),
                  pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Container(width: 120, child: pw.Text('Untuk Pembayaran')), pw.Expanded(child: pw.Text(': $jenisPembayaran${bulanTagihan != '-' ? ' ($bulanTagihan)' : ''}'))]),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: statusBayar == 'LUNAS' ? PdfColors.green : PdfColors.orange)),
                        child: pw.Text('STATUS: $statusBayar', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: statusBayar == 'LUNAS' ? PdfColors.green : PdfColors.orange)),
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

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Kwitansi_$namaSiswa');
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal mencetak kwitansi: $e', isSuccess: false, judul: 'Error');
    }
  }

  // =========================================================================
  // BOTTOM SHEET: DETAIL HISTORI & FORM BAYAR DENGAN ANIMASI TRANSISI & UI KEREN
  // =========================================================================
  void _bukaDetailHistori(String kategori, int kewajibanAsli) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    String kelasSiswa = (_biodata['kelas'] ?? '').toString().toLowerCase();
    bool isKelas10 = RegExp(r'\b(10|x)\b').hasMatch(kelasSiswa);
    bool isSPP = kategori.contains('SPP');

    bool isFormBayar = false;
    final nominalCtrl = TextEditingController();
    final keteranganCtrl = TextEditingController();
    String selectedBulan = _listBulan[DateTime.now().month - 1];
    XFile? fileBukti;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final listTransaksi = _riwayatBayar.where((b) => b['jenis_pembayaran'] == kategori).toList();
            
            int totalLunas = 0;
            int totalPending = 0;
            
            for (var t in listTransaksi) {
              final status = (t['status'] ?? '').toString().toUpperCase();
              final nominal = (t['nominal'] is num) ? (t['nominal'] as num).toInt() : 0;
              if (status == 'LUNAS') {
                totalLunas += nominal;
              } else if (status == 'PENDING') {
                totalPending += nominal;
              }
            }

            int kewajiban = (isSPP && isKelas10) ? 0 : kewajibanAsli;
            int sisaKurangLunas = (kewajiban - totalLunas) > 0 ? (kewajiban - totalLunas) : 0;
            int sisaSetelahPending = (sisaKurangLunas - totalPending) > 0 ? (sisaKurangLunas - totalPending) : 0;

            bool isLunasTotal = (kewajiban == 0) || (sisaKurangLunas == 0 && totalLunas > 0);
            bool isLunasMenungguTU = !isLunasTotal && (sisaSetelahPending == 0 && totalPending > 0);

            if (isFormBayar && nominalCtrl.text.isEmpty && sisaSetelahPending > 0) {
              nominalCtrl.text = isSPP ? '250000' : sisaSetelahPending.toString();
            }

            Future<void> prosesKirimPembayaran() async {
              final nominalBersih = nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
              final nominal = int.tryParse(nominalBersih);
              if (nominal == null || nominal <= 0) {
                PopupService.show(context, 'Nominal pembayaran tidak valid.', isSuccess: false, judul: 'Peringatan'); return;
              }
              if (fileBukti == null) {
                PopupService.show(context, 'Wajib melampirkan foto bukti transfer!', isSuccess: false, judul: 'Bukti Kosong'); return;
              }

              setStateSheet(() => isSubmitting = true);
              try {
                final user = _supabase.auth.currentUser;
                final ekstensi = fileBukti!.path.split('.').last;
                final namaFile = 'BUKTI_${user!.id}_${DateTime.now().millisecondsSinceEpoch}.$ekstensi';
                await _supabase.storage.from('foto_absensi').upload(namaFile, File(fileBukti!.path));
                final urlBukti = _supabase.storage.from('foto_absensi').getPublicUrl(namaFile);

                String ketFinal = isSPP ? 'Bulan $selectedBulan' : kategori;
                if (keteranganCtrl.text.trim().isNotEmpty) {
                  ketFinal += ' - ${keteranganCtrl.text.trim()}';
                }

                await _supabase.from('pembayaran').insert({
                  'siswa_id': user.id,
                  'jenis_pembayaran': kategori,
                  'bulan_tagihan': ketFinal,
                  'nominal': nominal,
                  'status': 'Pending',
                  'foto_bukti': urlBukti,
                  'tanggal_bayar': DateTime.now().toIso8601String(),
                  'penerima': 'Menunggu Verifikasi TU',
                });

                if (!context.mounted) return;
                Navigator.pop(context); 
                _fetchDataKeuangan(); 
                PopupService.show(context, 'Pembayaran berhasil dikirim! Silakan tunggu admin memverifikasi.', isSuccess: true, judul: 'Terkirim!');
              } catch (e) {
                setStateSheet(() => isSubmitting = false);
                PopupService.show(context, 'Gagal mengirim pembayaran: $e', isSuccess: false, judul: 'Gagal');
              }
            }

            // ====================================================================
            // 💡 WIDGET HISTORI (Mode Default)
            // ====================================================================
            Widget viewHistori = Column(
              key: const ValueKey('histori'),
              children: [
                // Grid Ringkasan
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: _buildSummaryBox('Total Tagihan', formatter.format(kewajiban), Colors.blueGrey.shade700, Colors.grey.shade100)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildSummaryBox('Telah Masuk', formatter.format(totalLunas), Colors.green.shade700, Colors.green.shade50)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildSummaryBox('Sisa Kurang', formatter.format(sisaKurangLunas), isLunasTotal ? Colors.green.shade700 : Colors.red.shade700, isLunasTotal ? Colors.green.shade50 : Colors.red.shade50)),
                    ],
                  ),
                ),
                
                // List Riwayat
                Expanded(
                  child: listTransaksi.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/logo_smk.png', height: 80, color: Colors.grey.shade300, colorBlendMode: BlendMode.srcATop),
                              const SizedBox(height: 16),
                              const Text('Belum ada riwayat transaksi.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: listTransaksi.length,
                          itemBuilder: (context, index) {
                            final b = listTransaksi[index];
                            final nominal = b['nominal'] ?? 0;
                            final status = (b['status'] ?? 'Pending').toString().toUpperCase();
                            final ket = (b['bulan_tagihan'] ?? '-').toString();
                            final penerima = (b['penerima'] ?? '-').toString();

                            String waktuTampil = '-';
                            final rawDate = (b['tanggal_bayar'] ?? b['created_at'] ?? '').toString();
                            try {
                              if (rawDate.isNotEmpty) waktuTampil = DateFormat('dd MMM yyyy, HH:mm WIB').format(DateTime.parse(rawDate).toLocal());
                            } catch (_) {}

                            Color badgeColor = Colors.orange;
                            IconData statusIcon = Icons.access_time_filled_rounded;
                            if (status == 'LUNAS') { badgeColor = Colors.green; statusIcon = Icons.check_circle_rounded; }
                            if (status == 'DITOLAK') { badgeColor = Colors.red; statusIcon = Icons.cancel_rounded; }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                border: Border.all(color: Colors.grey.shade100)
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(formatter.format(nominal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                                      if (status == 'LUNAS')
                                        InkWell(
                                          onTap: () => _cetakKwitansiPDF(b),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                            child: Row(children: [Icon(Icons.print_rounded, color: Colors.red.shade700, size: 14), const SizedBox(width: 4), Text('CETAK', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 10))]),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Row(children: [Icon(statusIcon, color: badgeColor, size: 12), const SizedBox(width: 4), Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor))]),
                                      ),
                                      const SizedBox(width: 10), 
                                      Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade400), 
                                      const SizedBox(width: 4),
                                      Text(waktuTampil, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                                    ],
                                  ),
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                                  Text(ket, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text('Verifikator: $penerima', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Area Bawah (Tombol Bayar / Status Lunas)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))], borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  child: SafeArea(
                    top: false,
                    child: Builder(
                      builder: (context) {
                        if (isLunasTotal) {
                          return Container(
                            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 24), const SizedBox(width: 8), Text('TAGIHAN LUNAS SEPENUHNYA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 13))]),
                          );
                        } else if (isLunasMenungguTU) {
                          return Container(
                            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                            child: Row(children: [Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade800, size: 28), const SizedBox(width: 12), Expanded(child: Text('Menunggu Tata Usaha memverifikasi pembayaran Anda sebesar ${formatter.format(totalPending)}.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 12, height: 1.4)))]),
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (totalPending > 0)
                                      Text('Ada ${formatter.format(totalPending)} (Pending)', style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                                    Text(totalLunas == 0 ? 'Belum Ada Pembayaran' : 'Sisa Tagihan:', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(formatter.format(sisaSetelahPending), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.red.shade600)),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 4, shadowColor: const Color(0xFF0F172A).withOpacity(0.4)
                                ),
                                onPressed: () => setStateSheet(() => isFormBayar = true), // TRIGGER ANIMASI KE FORM
                                child: const Row(children: [Text('BAYAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 18)]),
                              )
                            ],
                          );
                        }
                      }
                    ),
                  ),
                ),
              ],
            );

            // ====================================================================
            // 💡 WIDGET FORM BAYAR (Mode Pembayaran)
            // ====================================================================
            Widget viewForm = Column(
              key: const ValueKey('form'),
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔥 KARTU INFORMASI REKENING SEKOLAH
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green.shade300, width: 1.5)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_balance_rounded, color: Colors.green.shade700, size: 24),
                                  const SizedBox(width: 8),
                                  Text('Informasi Rekening Sekolah', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 13)),
                                ]
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Divider(color: Colors.green.shade200),
                              ),
                              const Text('Bank Central Asia (BCA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('No. Rek: 7295237082', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              const Text('a.n. SMK ISLAM AL AYANIAH', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              Text('Silakan transfer sesuai nominal ke rekening di atas, lalu unggah buktinya di bawah ini.', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontStyle: FontStyle.italic)),
                            ]
                          )
                        ),
                        const SizedBox(height: 24),

                        // Card Info Sisa
                        Container(
                          padding: const EdgeInsets.all(16), 
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade200, width: 1.5)),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, color: Colors.blue.shade700, size: 28), 
                              const SizedBox(width: 14), 
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sisa Yang Harus Dibayar', style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(formatter.format(sisaSetelahPending), style: TextStyle(color: Colors.blue.shade900, fontSize: 18, fontWeight: FontWeight.w900))])),
                            ]
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        if (isSPP) ...[
                          const Text('Pilih Bulan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedBulan, 
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.calendar_month_rounded, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), 
                              filled: true, fillColor: Colors.grey.shade100,
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade400, width: 2))
                            ),
                            items: _listBulan.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                            onChanged: (val) { if (val != null) setStateSheet(() => selectedBulan = val); },
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        const Text('Nominal Transfer (Rp)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nominalCtrl, 
                          keyboardType: TextInputType.number, 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)), 
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.payments_rounded, color: Colors.blue.shade700),
                            prefixText: 'Rp ', 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), 
                            filled: true, fillColor: Colors.grey.shade100, 
                            hintText: 'Cth: 150000',
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade400, width: 2))
                          )
                        ),
                        
                        const SizedBox(height: 20),
                        const Text('Catatan (Opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: keteranganCtrl, 
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), 
                            filled: true, fillColor: Colors.grey.shade100, 
                            hintText: 'Cth: Transfer via BCA a.n Budi',
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade400, width: 2))
                          )
                        ),
                        
                        const SizedBox(height: 24),
                        const Text('Unggah Bukti Transfer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final foto = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60);
                            if (foto != null) setStateSheet(() => fileBukti = foto);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 140, 
                            width: double.infinity, 
                            decoration: BoxDecoration(
                              color: fileBukti == null ? Colors.blue.shade50.withOpacity(0.5) : Colors.green.shade50, 
                              borderRadius: BorderRadius.circular(16), 
                              border: Border.all(color: fileBukti == null ? Colors.blue.shade300 : Colors.green.shade400, width: 2, style: BorderStyle.solid)
                            ),
                            child: Center(
                              child: fileBukti == null 
                                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload_rounded, color: Colors.blue.shade600, size: 48), const SizedBox(height: 12), Text('Tap untuk pilih foto struk / bukti transfer', style: TextStyle(color: Colors.blue.shade800, fontSize: 13, fontWeight: FontWeight.w600))])
                                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48), const SizedBox(height: 12), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Bukti Berhasil Dilampirkan\n(${fileBukti!.name})', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis))]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Area Bawah Tombol Kirim Form
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))]),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, 
                          padding: const EdgeInsets.symmetric(vertical: 18), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                          elevation: 4, shadowColor: const Color(0xFF1E40AF).withOpacity(0.4)
                        ),
                        onPressed: isSubmitting ? null : () => prosesKirimPembayaran(),
                        child: isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('KIRIM BUKTI PEMBAYARAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                )
              ],
            );

            // ====================================================================
            // 💡 STRUKTUR UTAMA BOTTOM SHEET
            // ====================================================================
            return Container(
              height: MediaQuery.of(context).size.height * 0.90, // Lebih tinggi sedikit
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  // DRAG HANDLE & HEADER POPUP
                  Container(
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(isFormBayar ? Icons.arrow_back_rounded : Icons.close_rounded, color: const Color(0xFF0F172A), size: 28),
                                onPressed: () {
                                  if (isFormBayar) {
                                    setStateSheet(() => isFormBayar = false);
                                  } else {
                                    Navigator.pop(context);
                                  }
                                }
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isFormBayar ? 'Form Pembayaran' : 'Rincian Tagihan', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    Text(kategori, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                      ],
                    ),
                  ),
                  
                  // 🔥 ANIMASI TRANSISI ANTARA HISTORI DAN FORM BAYAR
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final offsetAnimation = Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(animation);
                        return FadeTransition(opacity: animation, child: SlideTransition(position: offsetAnimation, child: child));
                      },
                      child: isFormBayar ? viewForm : viewHistori,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryBox(String title, String amount, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: textColor.withOpacity(0.1))),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(amount, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textColor), textAlign: TextAlign.center),
        ],
      ),
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
      backgroundColor: const Color(0xFFF1F5F9), // Slate 50
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchDataKeuangan,
            color: const Color(0xFF1E40AF),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 220.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF0F172A),
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text('Administrasi & SPP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    titlePadding: const EdgeInsets.only(left: 48, bottom: 16),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Gradient
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                        ),
                        // Ornamen Abstrak
                        Positioned(
                          right: -50, top: -50,
                          child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withOpacity(0.05)),
                        ),
                        Positioned(
                          left: -30, bottom: -30,
                          child: CircleAvatar(radius: 70, backgroundColor: Colors.blue.withOpacity(0.1)),
                        ),
                        // Info Siswa
                        Positioned(
                          left: 20, bottom: 60,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_biodata['full_name'] ?? 'Siswa', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text('Kelas: ${_biodata['kelas'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text('NISN: ${_biodata['nisn'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text('DAFTAR TAGIHAN & KEWAJIBAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF475569), letterSpacing: 0.5)),
                          );
                        }
                        
                        final realIndex = index - 1;
                        final namaTagihan = _katalogTagihan.keys.elementAt(realIndex);
                        final int kewajibanAsli = _katalogTagihan[namaTagihan]!;
                        final listTransaksi = groupedBayar[namaTagihan] ?? [];

                        bool isSPP = namaTagihan.contains('SPP');
                        bool isGratis = isSPP && isKelas10;
                        int kewajiban = isGratis ? 0 : kewajibanAsli;

                        int totalLunas = 0;
                        int totalPending = 0;
                        
                        for (var t in listTransaksi) {
                          final st = (t['status'] ?? '').toString().toUpperCase();
                          final nominal = (t['nominal'] is num) ? (t['nominal'] as num).toInt() : 0;
                          if (st == 'LUNAS') {
                            totalLunas += nominal;
                          } else if (st == 'PENDING') {
                            totalPending += nominal;
                          }
                        }

                        int sisaKurangLunas = (kewajiban - totalLunas) > 0 ? (kewajiban - totalLunas) : 0;
                        int sisaSetelahPending = (sisaKurangLunas - totalPending) > 0 ? (sisaKurangLunas - totalPending) : 0;

                        bool isLunasTotal = (kewajiban == 0) || (sisaKurangLunas == 0 && totalLunas > 0);
                        bool isLunasMenungguTU = !isLunasTotal && (sisaSetelahPending == 0 && totalPending > 0);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _bukaDetailHistori(namaTagihan, kewajibanAsli),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isLunasTotal 
                                              ? [Colors.green.shade400, Colors.green.shade600] 
                                              : (isLunasMenungguTU ? [Colors.orange.shade400, Colors.orange.shade600] : [Colors.blue.shade400, Colors.blue.shade700]),
                                          begin: Alignment.topLeft, end: Alignment.bottomRight
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: (isLunasTotal ? Colors.green : (isLunasMenungguTU ? Colors.orange : Colors.blue)).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                      ),
                                      child: Icon(
                                        isLunasTotal ? Icons.verified_rounded : (isLunasMenungguTU ? Icons.hourglass_top_rounded : Icons.receipt_long_rounded),
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(namaTagihan, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                                          const SizedBox(height: 6),
                                          
                                          if (isGratis)
                                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)), child: Text('GRATIS (Kls 10)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green.shade700)))
                                          else if (isLunasTotal)
                                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)), child: Text('LUNAS SEPENUHNYA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green.shade700)))
                                          else if (isLunasMenungguTU) ...[
                                            Text('Sisa Tagihan: Rp 0', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Text('⏳ Menunggu Verifikasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                          ]
                                          else if (totalLunas > 0) ...[
                                            Text('Telah Dibayar: ${formatter.format(totalLunas)}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Text('Sisa: ${formatter.format(sisaSetelahPending)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                                          ] else ...[
                                            Text('Total: ${formatter.format(kewajiban)}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Text('Belum Dibayar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Indikator Panah
                                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _katalogTagihan.length + 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}