import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAdministrasiScreen extends StatefulWidget {
  const AdminAdministrasiScreen({super.key});

  @override
  State<AdminAdministrasiScreen> createState() => _AdminAdministrasiScreenState();
}

class _AdminAdministrasiScreenState extends State<AdminAdministrasiScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _listSiswa = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSiswa();
  }

  Future<void> _fetchSiswa() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('*')
          .eq('role', 'siswa')
          .order('full_name', ascending: true);
      
      if (mounted) {
        setState(() {
          _listSiswa = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter Pencarian
    List<Map<String, dynamic>> filteredSiswa = _listSiswa.where((u) {
      if (_searchQuery.isEmpty) return true;
      final nama = (u['full_name'] ?? '').toString().toLowerCase();
      final kelas = (u['kelas'] ?? '').toString().toLowerCase();
      final nisn = (u['nisn'] ?? '').toString().toLowerCase();
      return nama.contains(_searchQuery) || kelas.contains(_searchQuery) || nisn.contains(_searchQuery);
    }).toList();

    // 2. Kelompokkan Berdasarkan Kelas (Folder)
    Map<String, List<Map<String, dynamic>>> groupedByKelas = {};
    for (var s in filteredSiswa) {
      final k = s['kelas'] ?? 'Tanpa Kelas';
      if (!groupedByKelas.containsKey(k)) groupedByKelas[k] = [];
      groupedByKelas[k]!.add(s);
    }

    final sortedKelas = groupedByKelas.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Administrasi & Keuangan', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // PANEL PENCARIAN
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari Nama, Kelas, atau NISN...', prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true, fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // LIST FOLDER KELAS
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : sortedKelas.isEmpty ? const Center(child: Text('Data siswa tidak ditemukan', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: sortedKelas.length,
                        itemBuilder: (context, index) {
                          final kelas = sortedKelas[index];
                          final listSiswaKelas = groupedByKelas[kelas]!;

                          return Card(
                            elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                            child: ExpansionTile(
                              leading: const Icon(Icons.folder_shared_rounded, color: Colors.teal, size: 36),
                              title: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                              subtitle: Text('${listSiswaKelas.length} Siswa terdaftar', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              children: listSiswaKelas.map((siswa) {
                                return Container(
                                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                    leading: const CircleAvatar(backgroundColor: Color(0xFFE6FFFA), child: Icon(Icons.person, color: Colors.teal)),
                                    title: Text(siswa['full_name'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text('NISN: ${siswa['nisn'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => DetailKeuanganSiswaScreen(siswaData: siswa)));
                                      },
                                      child: const Text('Keuangan', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                );
                              }).toList(),
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

// =========================================================================
// 🔥 HALAMAN: DETAIL RIWAYAT & INPUT PEMBAYARAN PER SISWA
// =========================================================================
class DetailKeuanganSiswaScreen extends StatefulWidget {
  final Map<String, dynamic> siswaData;
  const DetailKeuanganSiswaScreen({super.key, required this.siswaData});

  @override
  State<DetailKeuanganSiswaScreen> createState() => _DetailKeuanganSiswaScreenState();
}

class _DetailKeuanganSiswaScreenState extends State<DetailKeuanganSiswaScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _riwayatBayar = [];

  // DAFTAR KATEGORI FOLDER PEMBAYARAN (Sesuai Urutan)
  final List<String> _kategoriFolder = [
    'SPP Bulanan',
    'Daftar Ulang',
    'PTS-1',
    'PAS-1',
    'LKS',
    'Seragam',
    'Kegiatan PKL',
    'Lainnya'
  ];

  // DATABASE HARGA OTOMATIS
  final Map<String, String> _hargaTagihan = {
    'SPP Bulanan': '250000',
    'Daftar Ulang': '1500000',
    'PTS-1': '150000',
    'PAS-1': '200000',
    'LKS': '120000',
    'Seragam': '850000',
    'Kegiatan PKL': '300000',
    'Lainnya': '0'
  };

  final List<String> _listBulan = ['-', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('pembayaran')
          .select('*')
          .eq('siswa_id', widget.siswaData['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _riwayatBayar = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _bukaDialogInputBayar() {
    String selectedJenis = 'SPP Bulanan';
    String selectedBulan = '-'; 
    final nominalCtrl = TextEditingController(text: _hargaTagihan['SPP Bulanan']);
    final keteranganCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isSPP = selectedJenis.contains('SPP');

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Input Bayar: ${widget.siswaData['full_name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Jenis Tagihan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedJenis, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: _hargaTagihan.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedJenis = val;
                            nominalCtrl.text = _hargaTagihan[val]!;
                            if (!val.contains('SPP')) selectedBulan = '-'; 
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    if (isSPP) ...[
                      const Text('Pembayaran Untuk Bulan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedBulan, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: _listBulan.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) { if (val != null) setStateDialog(() => selectedBulan = val); },
                      ),
                      const SizedBox(height: 12),
                    ],

                    const Text('Nominal (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nominalCtrl, keyboardType: TextInputType.number,
                      decoration: InputDecoration(prefixText: 'Rp ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),

                    const Text('Keterangan Tambahan (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: keteranganCtrl,
                      decoration: InputDecoration(hintText: 'Cth: Lunas via Transfer BCA', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    if (nominalCtrl.text.isEmpty) return;

                    String tagihanFinal = selectedBulan != '-' ? 'Bulan $selectedBulan' : '';
                    if (keteranganCtrl.text.isNotEmpty) {
                      tagihanFinal += tagihanFinal.isNotEmpty ? ' - ${keteranganCtrl.text}' : keteranganCtrl.text;
                    }
                    if (tagihanFinal.isEmpty) tagihanFinal = '-';

                    Navigator.pop(context); // Tutup dialog
                    _prosesSimpanPembayaran(selectedJenis, nominalCtrl.text, tagihanFinal);
                  },
                  child: const Text('Simpan Pembayaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _prosesSimpanPembayaran(String jenis, String nominalStr, String keterangan) async {
    setState(() => _isLoading = true);
    try {
      String nominalBersih = nominalStr.replaceAll(RegExp(r'[^0-9]'), '');
      final user = _supabase.auth.currentUser;
      final emailPenerima = user?.email ?? 'Admin / TU';

      await _supabase.from('pembayaran').insert({
        'siswa_id': widget.siswaData['id'],
        'jenis_pembayaran': jenis,
        'bulan_tagihan': keterangan,
        'nominal': int.parse(nominalBersih), 
        'status': 'LUNAS',
        'tanggal_bayar': DateTime.now().toIso8601String(),
        'penerima': emailPenerima 
      });
      
      _fetchRiwayat();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembayaran Lunas Tersimpan!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. KELOMPOKKAN RIWAYAT BERDASARKAN JENIS PEMBAYARAN (FOLDER)
    Map<String, List<Map<String, dynamic>>> groupedRiwayat = {};
    for (var bayar in _riwayatBayar) {
      final jenis = bayar['jenis_pembayaran'] ?? 'Lainnya';
      if (!groupedRiwayat.containsKey(jenis)) {
        groupedRiwayat[jenis] = [];
      }
      groupedRiwayat[jenis]!.add(bayar);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Detail Keuangan Siswa', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, iconTheme: const IconThemeData(color: Colors.black)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal, icon: const Icon(Icons.add_card, color: Colors.white),
        label: const Text('Input Pembayaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _bukaDialogInputBayar,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20), width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE6FFFA), child: Icon(Icons.person, color: Colors.teal, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.siswaData['full_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text('NISN: ${widget.siswaData['nisn']} | Kelas: ${widget.siswaData['kelas']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 8), alignment: Alignment.centerLeft,
            child: const Text('Folder Riwayat Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          ),
          
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _kategoriFolder.length, // Menampilkan folder sesuai urutan _kategoriFolder
                  itemBuilder: (context, index) {
                    final namaKategori = _kategoriFolder[index];
                    final listBayarKategori = groupedRiwayat[namaKategori] ?? [];
                    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

                    // Hitung total nominal per folder
                    double totalMasuk = 0;
                    for (var b in listBayarKategori) {
                      totalMasuk += (b['nominal'] ?? 0);
                    }

                    return Card(
                      elevation: 0, 
                      margin: const EdgeInsets.only(bottom: 12), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.folder, color: Colors.amber, size: 36),
                        title: Text(namaKategori, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                        subtitle: Text('${listBayarKategori.length} Transaksi | Total: ${formatter.format(totalMasuk)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        children: listBayarKategori.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Belum ada data pembayaran di kategori ini.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                              )
                            ]
                          : listBayarKategori.map((bayar) {
                              
                              String rawDate = bayar['tanggal_bayar'] ?? bayar['created_at'] ?? '';
                              String tanggalTampil = rawDate; 
                              try {
                                DateTime parsed = DateTime.parse(rawDate).toLocal();
                                tanggalTampil = DateFormat('dd MMM yyyy, HH:mm').format(parsed);
                              } catch (e) {}

                              return Container(
                                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)), child: const Text('LUNAS', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10))),
                                        Text(tanggalTampil, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(formatter.format(bayar['nominal'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(bayar['bulan_tagihan']?.toString().replaceAll('-', 'Tanpa Keterangan') ?? '', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                              const SizedBox(height: 4),
                                              Text('Diterima oleh: ${bayar['penerima'] ?? 'Admin'}', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                            ],
                                          )
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    );
                  },
                ),
          )
        ],
      ),
    );
  }
}