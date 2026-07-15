import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminAdministrasiScreen extends StatefulWidget {
  const AdminAdministrasiScreen({super.key});

  @override
  State<AdminAdministrasiScreen> createState() =>
      _AdminAdministrasiScreenState();
}

class _AdminAdministrasiScreenState extends State<AdminAdministrasiScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _listSiswa = [];
  List<Map<String, dynamic>> _listVerifikasi = [];
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDataAwal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDataAwal() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final resSiswa = await _supabase
          .from('profiles')
          .select('*')
          .eq('role', 'siswa')
          .order('full_name', ascending: true);

      final resPending = await _supabase
          .from('pembayaran')
          .select('*')
          .eq('status', 'Pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _listSiswa = List<Map<String, dynamic>>.from(resSiswa as List);
          _listVerifikasi = List<Map<String, dynamic>>.from(resPending as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error _fetchDataAwal: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          'Gagal memuat data keuangan. Periksa koneksi internet.',
          Colors.red,
        );
      }
    }
  }

  Future<void> _verifikasiTerima(String idPembayaran) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      await _supabase
          .from('pembayaran')
          .update({
            'status': 'LUNAS',
            'penerima': user?.email ?? 'Admin TU',
            'tanggal_bayar': DateTime.now().toIso8601String(),
          })
          .eq('id', idPembayaran);

      await _fetchDataAwal();
      if (mounted) {
        _showSnackBar('Pembayaran DITERIMA & LUNAS!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal memverifikasi pembayaran: $e', Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifikasiTolak(String idPembayaran) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.from('pembayaran').delete().eq('id', idPembayaran);
      await _fetchDataAwal();
      if (mounted) {
        _showSnackBar('Pembayaran DITOLAK / Dihapus.', Colors.orange);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal menolak pembayaran: $e', Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String pesan, Color warna) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna));
  }

  @override
  Widget build(BuildContext context) {
    final filteredSiswa = _listSiswa.where((u) {
      if (_searchQuery.isEmpty) return true;
      final nama = (u['full_name'] ?? '').toString().toLowerCase();
      final kelas = (u['kelas'] ?? '').toString().toLowerCase();
      return nama.contains(_searchQuery) || kelas.contains(_searchQuery);
    }).toList();

    final Map<String, List<Map<String, dynamic>>> groupedByKelas = {};
    for (var s in filteredSiswa) {
      final k = (s['kelas'] ?? 'Tanpa Kelas').toString();
      groupedByKelas.putIfAbsent(k, () => []).add(s);
    }
    final sortedKelas = groupedByKelas.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Keuangan Tata Usaha',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade900,
          indicatorColor: Colors.blue.shade900,
          tabs: [
            const Tab(text: 'Data Kasir Siswa'),
            Tab(text: 'Verifikasi Online (${_listVerifikasi.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _fetchDataAwal,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Cari Nama / Kelas...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          onChanged: (v) => setState(
                            () => _searchQuery = v.trim().toLowerCase(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: sortedKelas.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tidak ada data siswa.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: sortedKelas.length,
                                itemBuilder: (context, index) {
                                  final kelas = sortedKelas[index];
                                  final listSiswaKelas =
                                      groupedByKelas[kelas] ?? [];
                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: ExpansionTile(
                                      leading: const Icon(
                                        Icons.folder_shared_rounded,
                                        color: Colors.amber,
                                        size: 36,
                                      ),
                                      title: Text(
                                        'Kelas $kelas',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      children: listSiswaKelas.map((siswa) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.shade200,
                                              ),
                                            ),
                                          ),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 4,
                                                ),
                                            leading: const CircleAvatar(
                                              backgroundColor: Color(
                                                0xFFE6FFFA,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.teal,
                                              ),
                                            ),
                                            title: Text(
                                              (siswa['full_name'] ??
                                                      'Tanpa Nama')
                                                  .toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            trailing: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.blue.shade900,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () {
                                                if (siswa['id'] == null) {
                                                  _showSnackBar(
                                                    'Data siswa tidak valid.',
                                                    Colors.red,
                                                  );
                                                  return;
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        DetailKasirScreen(
                                                          siswaData: siswa,
                                                        ),
                                                  ),
                                                ).then((_) => _fetchDataAwal());
                                              },
                                              child: const Text('Buka Kasir'),
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
                ),
                RefreshIndicator(
                  onRefresh: _fetchDataAwal,
                  child: _listVerifikasi.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Text(
                                'Tidak ada pembayaran tertunda.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _listVerifikasi.length,
                          itemBuilder: (context, index) {
                            final bayar = _listVerifikasi[index];
                            final formatter = NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            );

                            final dataSiswa = _listSiswa.firstWhere(
                              (s) => s['id'] == bayar['siswa_id'],
                              orElse: () => {
                                'full_name': 'Siswa Tidak Ditemukan',
                                'kelas': '-',
                              },
                            );

                            final fotoBukti = bayar['foto_bukti'];
                            final nominal = bayar['nominal'] ?? 0;
                            final jenisPembayaran =
                                (bayar['jenis_pembayaran'] ?? '-').toString();
                            final bulanTagihan = (bayar['bulan_tagihan'] ?? '-')
                                .toString();
                            final idBayar = bayar['id']?.toString();

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (dataSiswa['full_name'] ?? '-')
                                                .toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'MENUNGGU ACC',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Kelas ${(dataSiswa['kelas'] ?? '-').toString()}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Divider(),
                                    Text(
                                      '$jenisPembayaran${bulanTagihan != '-' ? ' ($bulanTagihan)' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      formatter.format(nominal),
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (fotoBukti != null &&
                                        fotoBukti.toString().isNotEmpty)
                                      Container(
                                        height: 180,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.grey.shade100,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            fotoBukti.toString(),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Center(
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                            loadingBuilder:
                                                (context, child, progress) {
                                                  if (progress == null)
                                                    return child;
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            onPressed: idBayar == null
                                                ? null
                                                : () =>
                                                      _verifikasiTolak(idBayar),
                                            child: const Text('TOLAK'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                            onPressed: idBayar == null
                                                ? null
                                                : () => _verifikasiTerima(
                                                    idBayar,
                                                  ),
                                            child: const Text(
                                              'TERIMA (LUNAS)',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
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

// =========================================================================
// HALAMAN KASIR TU & CETAK KWITANSI PDF
// =========================================================================
class DetailKasirScreen extends StatefulWidget {
  final Map<String, dynamic> siswaData;
  const DetailKasirScreen({super.key, required this.siswaData});

  @override
  State<DetailKasirScreen> createState() => _DetailKasirScreenState();
}

class _DetailKasirScreenState extends State<DetailKasirScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _riwayatBayar = [];

  final List<String> _kategoriFolder = [
    'SPP Bulanan',
    'Semester (PTS/PAS)',
    'LKS',
    'Seragam',
    'Kegiatan PKL',
    'Daftar Ulang',
    'Lainnya',
  ];

  // Sumber tunggal harga default per jenis tagihan -> dipakai untuk autofill nominal
  final Map<String, int> _hargaTagihan = {
    'SPP Bulanan': 250000,
    'Semester (PTS/PAS)': 200000,
    'LKS': 300000,
    'Seragam': 850000,
    'Kegiatan PKL': 400000,
    'Daftar Ulang': 1500000,
    'Lainnya': 0,
  };

  final List<String> _listBulan = [
    '-',
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

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final siswaId = widget.siswaData['id'];
      if (siswaId == null) throw 'ID siswa tidak valid.';

      final res = await _supabase
          .from('pembayaran')
          .select('*')
          .eq('siswa_id', siswaId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _riwayatBayar = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error _fetchRiwayat: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal memuat riwayat pembayaran.', Colors.red);
      }
    }
  }

  void _showSnackBar(String pesan, Color warna) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna));
  }

  // ==============================================================
  // DIALOG INPUT TERIMA UANG (KASIR MANUAL)
  // Autofill nominal saat jenis tagihan dipilih + bulan tersambung ke DB
  // ==============================================================
  void _bukaDialogInputBayar() {
    String selectedJenis = 'SPP Bulanan';
    String selectedBulan = '-';
    final nominalCtrl = TextEditingController(
      text: (_hargaTagihan['SPP Bulanan'] ?? 0).toString(),
    );
    final keteranganCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final bool isSPP = selectedJenis.contains('SPP');
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Input Terima Uang / Kasir',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Dropdown Jenis Tagihan: memicu autofill nominal --
                    DropdownButtonFormField<String>(
                      value: selectedJenis,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Tagihan',
                        border: OutlineInputBorder(),
                      ),
                      items: _hargaTagihan.keys
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setStateDialog(() {
                          selectedJenis = val;
                          // AUTOFILL NOMINAL sesuai katalog harga
                          nominalCtrl.text = (_hargaTagihan[val] ?? 0)
                              .toString();
                          if (!val.contains('SPP')) selectedBulan = '-';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // -- Dropdown Bulan hanya untuk SPP, tersambung ke keterangan yang disimpan ke DB --
                    if (isSPP) ...[
                      DropdownButtonFormField<String>(
                        value: selectedBulan,
                        decoration: const InputDecoration(
                          labelText: 'Pembayaran Bulan',
                          border: OutlineInputBorder(),
                        ),
                        items: _listBulan
                            .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setStateDialog(() => selectedBulan = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nominalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keteranganCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan Opsional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                  ),
                  onPressed: () {
                    final nominalBersih = nominalCtrl.text.replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );
                    if (nominalBersih.isEmpty ||
                        int.tryParse(nominalBersih) == null) {
                      _showSnackBar('Nominal tidak valid.', Colors.red);
                      return;
                    }
                    if (isSPP && selectedBulan == '-') {
                      _showSnackBar(
                        'Pilih bulan pembayaran SPP terlebih dahulu.',
                        Colors.orange,
                      );
                      return;
                    }

                    String tagihanFinal = selectedBulan != '-'
                        ? 'Bulan $selectedBulan'
                        : '';
                    if (keteranganCtrl.text.trim().isNotEmpty) {
                      tagihanFinal += tagihanFinal.isNotEmpty
                          ? ' - ${keteranganCtrl.text.trim()}'
                          : keteranganCtrl.text.trim();
                    }
                    if (tagihanFinal.isEmpty) tagihanFinal = '-';

                    Navigator.pop(context);
                    _prosesSimpanPembayaran(
                      selectedJenis,
                      nominalCtrl.text,
                      tagihanFinal,
                    );
                  },
                  child: const Text(
                    'Simpan LUNAS',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _prosesSimpanPembayaran(
    String jenis,
    String nominalStr,
    String keterangan,
  ) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final siswaId = widget.siswaData['id'];
      if (siswaId == null) throw 'ID siswa tidak valid.';

      final nominalBersih = nominalStr.replaceAll(RegExp(r'[^0-9]'), '');
      final nominal = int.tryParse(nominalBersih);
      if (nominal == null) throw 'Format nominal tidak valid.';

      final user = _supabase.auth.currentUser;

      await _supabase.from('pembayaran').insert({
        'siswa_id': siswaId,
        'jenis_pembayaran': jenis,
        'bulan_tagihan':
            keterangan, // -> otomatis tersimpan ke DB dari dropdown bulan
        'nominal': nominal,
        'status': 'LUNAS',
        'tanggal_bayar': DateTime.now().toIso8601String(),
        'penerima': user?.email ?? 'Admin TU',
      });

      await _fetchRiwayat();
      if (mounted)
        _showSnackBar('Uang diterima & tercatat LUNAS!', Colors.green);
    } catch (e) {
      debugPrint('Error _prosesSimpanPembayaran: $e');
      if (mounted) {
        _showSnackBar('Gagal menyimpan pembayaran: $e', Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  // ==============================================================
  // CETAK KWITANSI PDF
  // ==============================================================
  Future<void> _cetakKwitansiPDF(Map<String, dynamic> dataBayar) async {
    try {
      final pdf = pw.Document();
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      final rawDate =
          (dataBayar['tanggal_bayar'] ?? dataBayar['created_at'] ?? '')
              .toString();
      String tglCetak = rawDate;
      try {
        if (rawDate.isNotEmpty) {
          tglCetak = DateFormat(
            'dd MMMM yyyy, HH:mm',
          ).format(DateTime.parse(rawDate).toLocal());
        } else {
          tglCetak = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());
        }
      } catch (_) {
        tglCetak = DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now());
      }

      final namaSiswa = (widget.siswaData['full_name'] ?? '-').toString();
      final kelasSiswa = (widget.siswaData['kelas'] ?? '-').toString();
      final nisnSiswa = (widget.siswaData['nisn'] ?? '-').toString();
      final nominal = dataBayar['nominal'] ?? 0;
      final jenisPembayaran = (dataBayar['jenis_pembayaran'] ?? '-').toString();
      final bulanTagihan = (dataBayar['bulan_tagihan'] ?? '-').toString();
      final penerima = (dataBayar['penerima'] ?? 'Admin Tata Usaha').toString();

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
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
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
                      pw.Container(
                        width: 120,
                        child: pw.Text('Telah Terima Dari'),
                      ),
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
                    children: [
                      pw.Container(
                        width: 120,
                        child: pw.Text('Untuk Pembayaran'),
                      ),
                      pw.Text(
                        ': $jenisPembayaran${bulanTagihan != '-' ? ' ($bulanTagihan)' : ''}',
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(border: pw.Border.all()),
                        child: pw.Text(
                          'STATUS: LUNAS',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Tangerang, $tglCetak',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.SizedBox(height: 40),
                          pw.Text(
                            penerima,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.Text(
                            'Penerima / Staf Keuangan',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
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
      _showSnackBar('Gagal mencetak kwitansi: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedRiwayat = {};
    for (var bayar in _riwayatBayar) {
      final jenis = (bayar['jenis_pembayaran'] ?? 'Lainnya').toString();
      groupedRiwayat.putIfAbsent(jenis, () => []).add(bayar);
    }

    final namaSiswa = (widget.siswaData['full_name'] ?? '-').toString();
    final nisnSiswa = (widget.siswaData['nisn'] ?? '-').toString();
    final kelasSiswa = (widget.siswaData['kelas'] ?? '-').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Kasir Keuangan',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade900,
        icon: const Icon(Icons.add_card, color: Colors.white),
        label: const Text(
          'Input Terima Uang',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _bukaDialogInputBayar,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRiwayat,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFFE6FFFA),
                          child: Icon(
                            Icons.person,
                            color: Colors.teal,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                namaSiswa,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'NISN: $nisnSiswa | Kelas: $kelasSiswa',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _kategoriFolder.length,
                      itemBuilder: (context, index) {
                        final namaKategori = _kategoriFolder[index];
                        final listBayarKategori =
                            groupedRiwayat[namaKategori] ?? [];
                        final formatter = NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        );
                        double totalMasuk = 0;
                        for (var b in listBayarKategori) {
                          if ((b['status'] ?? '') == 'LUNAS') {
                            totalMasuk += (b['nominal'] is num)
                                ? (b['nominal'] as num).toDouble()
                                : 0;
                          }
                        }

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: ExpansionTile(
                            leading: const Icon(
                              Icons.folder,
                              color: Colors.amber,
                              size: 36,
                            ),
                            title: Text(
                              namaKategori,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '${listBayarKategori.length} Transaksi | Lunas: ${formatter.format(totalMasuk)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            children: listBayarKategori.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'Belum ada riwayat pembayaran.',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ]
                                : listBayarKategori.map((bayar) {
                                    final isLunas =
                                        (bayar['status'] ?? '') == 'LUNAS';
                                    final nominal = bayar['nominal'] ?? 0;
                                    final bulanTagihan =
                                        (bayar['bulan_tagihan'] ?? '-')
                                            .toString();
                                    final penerima = (bayar['penerima'] ?? '-')
                                        .toString();
                                    final statusTampil =
                                        (bayar['status'] ?? '-')
                                            .toString()
                                            .toUpperCase();

                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isLunas
                                                        ? Colors.green.shade50
                                                        : Colors.orange.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    statusTampil,
                                                    style: TextStyle(
                                                      color: isLunas
                                                          ? Colors.green
                                                          : Colors.orange,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  formatter.format(nominal),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Colors.blue.shade900,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '$bulanTagihan | Oleh: $penerima',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isLunas)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.print,
                                                color: Colors.red,
                                              ),
                                              tooltip: 'Cetak Kwitansi PDF',
                                              onPressed: () =>
                                                  _cetakKwitansiPDF(bayar),
                                            ),
                                        ],
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
            ),
    );
  }
}
