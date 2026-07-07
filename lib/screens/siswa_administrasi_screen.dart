import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

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
  
  // 🔥 KELUHAN SISWA REAL-LIFE: TAGIHAN BIAYA
  final List<Map<String, dynamic>> _daftarTagihanWajib = [
    {'jenis': 'LKS', 'nominal': 300000},
    {'jenis': 'Kegiatan PKL', 'nominal': 400000},
    {'jenis': 'Seragam', 'nominal': 850000},
    {'jenis': 'Semester (PTS/PAS)', 'nominal': 200000},
    {'jenis': 'SPP Bulanan', 'nominal': 250000}, 
  ];

  @override
  void initState() {
    super.initState();
    _fetchDataKeuangan();
  }

  Future<void> _fetchDataKeuangan() async {
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _bukaDialogUploadBukti(String jenisTagihan, int nominalAsli) {
    String kelasSiswa = (_biodata['kelas'] ?? '').toString().toLowerCase();
    
    // 🔥 PERBAIKAN LOGIKA CERDAS: Mencegah kelas XI dan XII ikut jadi gratis
    bool isKelas10 = RegExp(r'\b(10|x)\b').hasMatch(kelasSiswa);
    bool isSPP = jenisTagihan == 'SPP Bulanan';
    
    int nominalFinal = nominalAsli;
    if (isSPP && isKelas10) {
      nominalFinal = 0; // Gratis Khusus Kelas 10
    }

    if (nominalFinal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hore! Tagihan ini GRATIS untuk kelas Anda.'), backgroundColor: Colors.green));
      return;
    }

    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final nominalCtrl = TextEditingController(text: formatter.format(nominalFinal));
    final keteranganCtrl = TextEditingController();
    XFile? fileBukti;

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
                    const Text('Nominal Transfer (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 4),
                    // KUNCI NOMINAL AGAR SISWA TIDAK BISA NGEDIT (MENCEGAH KURANG BAYAR)
                    TextField(
                      controller: nominalCtrl, 
                      readOnly: true, 
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(), 
                        prefixText: 'Rp ',
                        filled: true,
                        fillColor: Colors.grey.shade200, 
                      )
                    ),
                    const SizedBox(height: 12),
                    
                    // KOLOM BULAN HANYA MUNCUL JIKA YANG DIBAYAR ADALAH SPP
                    if (isSPP) ...[
                      const Text('Pembayaran Bulan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(controller: keteranganCtrl, decoration: const InputDecoration(hintText: 'Cth: SPP Bulan Juli', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                    ],

                    const Text('Upload Bukti Transfer / Struk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final foto = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                        if (foto != null) setStateDialog(() => fileBukti = foto);
                      },
                      child: Container(
                        height: 80, width: double.infinity, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue)),
                        child: fileBukti == null 
                            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file, color: Colors.blue), Text('Pilih Foto Galeri', style: TextStyle(color: Colors.blue, fontSize: 11))])
                            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Foto Terpilih', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                  onPressed: () async {
                    if (fileBukti == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap upload bukti transfer!'), backgroundColor: Colors.red));
                      return;
                    }
                    if (isSPP && keteranganCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulan SPP wajib diisi!'), backgroundColor: Colors.red));
                      return;
                    }
                    
                    Navigator.pop(context);
                    String ketAkhir = isSPP ? keteranganCtrl.text.trim() : '-';
                    _prosesUploadPembayaran(jenisTagihan, nominalFinal.toString(), ketAkhir, fileBukti!);
                  },
                  child: const Text('Kirim ke TU', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Future<void> _prosesUploadPembayaran(String jenis, String nominalStr, String keterangan, XFile foto) async {
    setState(() => _isUploading = true);
    try {
      String ext = foto.path.split('.').last;
      String namaFile = 'BUKTI_${widget.siswaId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      await _supabase.storage.from('foto_absensi').upload(namaFile, File(foto.path));
      String urlBukti = _supabase.storage.from('foto_absensi').getPublicUrl(namaFile);

      await _supabase.from('pembayaran').insert({
        'siswa_id': widget.siswaId,
        'jenis_pembayaran': jenis,
        'bulan_tagihan': keterangan,
        'nominal': int.parse(nominalStr.replaceAll(RegExp(r'[^0-9]'), '')),
        'status': 'Pending', 
        'tanggal_bayar': DateTime.now().toIso8601String(),
        'penerima': 'Menunggu Verifikasi',
        'foto_bukti': urlBukti
      });

      _fetchDataKeuangan();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti berhasil dikirim. Menunggu verifikasi TU.'), backgroundColor: Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    String kelasSiswa = (_biodata['kelas'] ?? '').toString().toLowerCase();
    bool isKelas10 = RegExp(r'\b(10|x)\b').hasMatch(kelasSiswa);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Tagihan & SPP', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: _isLoading || _isUploading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700]), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informasi Keuangan', style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4),
                    Text(_biodata['full_name'] ?? 'Siswa', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('Kelas: ${_biodata['kelas'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Katalog Tagihan Tersedia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              
              ..._daftarTagihanWajib.map((tagihan) {
                bool isSPP = tagihan['jenis'] == 'SPP Bulanan';
                bool isGratis = isSPP && isKelas10;
                String nominalTampil = isGratis ? 'GRATIS (Siswa Kelas 10)' : formatter.format(tagihan['nominal']);

                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.receipt_long, color: Colors.blue)),
                    title: Text(tagihan['jenis'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(nominalTampil, style: TextStyle(color: isGratis ? Colors.green : Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                    trailing: isGratis 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: () => _bukaDialogUploadBukti(tagihan['jenis'], tagihan['nominal']),
                          child: const Text('Bayar', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),
              const Text('Riwayat & Status Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              if (_riwayatBayar.isEmpty)
                 const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada riwayat pembayaran.', style: TextStyle(color: Colors.grey))))
              else
                ..._riwayatBayar.map((bayar) {
                  bool isLunas = bayar['status'].toString().toUpperCase() == 'LUNAS';
                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isLunas ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(6)), child: Text(bayar['status'].toString().toUpperCase(), style: TextStyle(color: isLunas ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 10))),
                              Text(bayar['bulan_tagihan'] ?? '-', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(bayar['jenis_pembayaran'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(formatter.format(bayar['nominal'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade900)),
                          if (!isLunas) ...[
                            const SizedBox(height: 8),
                            const Text('*Menunggu diverifikasi oleh pihak Tata Usaha', style: TextStyle(fontSize: 10, color: Colors.red, fontStyle: FontStyle.italic))
                          ]
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
    );
  }
}