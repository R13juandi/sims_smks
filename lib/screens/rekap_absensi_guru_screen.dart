import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/popup_service.dart'; // 🔥 IMPOR POPUP TENGAH LAYAR

class RekapAbsensiGuruScreen extends StatefulWidget {
  const RekapAbsensiGuruScreen({super.key});

  @override
  State<RekapAbsensiGuruScreen> createState() => _RekapAbsensiGuruScreenState();
}

class _RekapAbsensiGuruScreenState extends State<RekapAbsensiGuruScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Data untuk Tab 1: Aksi Cepat / Verifikasi Harian
  List<Map<String, dynamic>> _dataAbsen = [];
  DateTime _selectedDate = DateTime.now();
  String _namaGuruLogin = '';

  // Data untuk Tab 2: Rekap Akumulasi
  List<Map<String, dynamic>> _listRekapSiswa = [];
  String _selectedKelasFilter = 'Semua Kelas';
  List<String> _daftarKelas = ['Semua Kelas'];

  @override
  void initState() {
    super.initState();
    _fetchGuruDanRekap();
  }

  // =========================================================================
  // 🔥 MENGAMBIL DATA UNTUK KEDUA TAB SEKALIGUS
  // =========================================================================
  Future<void> _fetchGuruDanRekap() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final profile = await _supabase.from('profiles').select('full_name').eq('id', user.id).single();
      _namaGuruLogin = profile['full_name'].toString().trim();
      final tanggalFilter = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // 1. Tarik data Absensi Harian (Untuk Tab 1 - Aksi Cepat & Verifikasi)
      final res = await _supabase.from('absensi')
          .select('*, profiles!inner(full_name, nisn, kelas)')
          .eq('tanggal', tanggalFilter)
          .or('guru_pengampu.ilike.%$_namaGuruLogin%,mapel.eq.Pulang Sekolah')
          .order('waktu_absen', ascending: false);

      // 2. Tarik daftar Siswa & Rekap Keseluruhan (Untuk Tab 2 - Rekap Akumulasi)
      final resSiswa = await _supabase
          .from('profiles')
          .select('id, full_name, kelas, nisn')
          .eq('role', 'siswa')
          .order('full_name', ascending: true);

      final resSemuaAbsen = await _supabase
          .from('absensi')
          .select('siswa_id, status');

      // Bangun daftar kelas unik untuk dropdown filter
      Set<String> setKelas = {'Semua Kelas'};
      for (var s in resSiswa) {
        if (s['kelas'] != null && s['kelas'].toString().trim().isNotEmpty) {
          setKelas.add(s['kelas'].toString());
        }
      }

      // Agregasi persentase rekap per siswa
      List<Map<String, dynamic>> rekapList = [];
      for (var s in resSiswa) {
        String sId = s['id'].toString();
        int hadir = 0;
        int izin = 0;
        int sakit = 0;
        int alfa = 0;

        for (var a in resSemuaAbsen) {
          if (a['siswa_id'].toString() == sId) {
            String st = (a['status'] ?? '').toString().toUpperCase();
            if (st == 'H' || st == 'HADIR') hadir++;
            else if (st == 'I' || st == 'IZIN') izin++;
            else if (st == 'S' || st == 'SAKIT') sakit++;
            else alfa++;
          }
        }

        int total = hadir + izin + sakit + alfa;
        double persentase = total > 0 ? (hadir / total) * 100 : 0.0;

        rekapList.add({
          'id': sId,
          'full_name': s['full_name'] ?? '-',
          'kelas': s['kelas'] ?? '-',
          'nisn': s['nisn'] ?? '-',
          'hadir': hadir,
          'izin': izin,
          'sakit': sakit,
          'alfa': alfa,
          'persentase': persentase,
        });
      }

      if (mounted) {
        setState(() { 
          _dataAbsen = List<Map<String, dynamic>>.from(res); 
          _listRekapSiswa = rekapList;
          _daftarKelas = setKelas.toList();
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(context, 'Gagal memuat rekap: $e', isSuccess: false, judul: 'Error');
      }
    }
  }

  // Fungsi untuk update status oleh Guru
  Future<void> _updateStatusAbsen(dynamic id, String statusBaru, String verifikasi) async {
    try {
      await _supabase.from('absensi').update({
        'status': statusBaru, 
        'status_verifikasi': verifikasi
      }).eq('id', id);
      
      _fetchGuruDanRekap();
      if (!mounted) return;
      PopupService.show(context, 'Status absensi berhasil diperbarui menjadi "$verifikasi"!', isSuccess: true, judul: 'Berhasil');
    } catch (e) {
      PopupService.show(context, 'Gagal memperbarui: $e', isSuccess: false, judul: 'Gagal');
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime(2024), 
      lastDate: DateTime.now()
    );
    if (picked != null) { 
      setState(() => _selectedDate = picked); 
      _fetchGuruDanRekap(); 
    }
  }

  void _tampilkanDetailFoto(BuildContext context, String url, String namaSiswa) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Bukti Presensi: $namaSiswa', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)), 
              backgroundColor: Colors.white, 
              elevation: 0, 
              automaticallyImplyLeading: false, 
              actions: [IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))]
            ),
            InteractiveViewer(
              panEnabled: true, minScale: 0.5, maxScale: 4.0, 
              child: Image.network(url, fit: BoxFit.contain, loadingBuilder: (context, child, loadingProgress) { 
                if (loadingProgress == null) return child; 
                return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())); 
              }, errorBuilder: (context, error, stackTrace) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red))))
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 🔥 DIALOG VERIFIKASI GURU (MAKER-CHECKER WORKFLOW + LOKASI GPS)
  // =========================================================================
  void _bukaDialogVerifikasiGuru(Map<String, dynamic> a) {
    final p = a['profiles'] ?? {};
    final String namaMurid = p['full_name'] ?? 'Siswa';
    final String nisn = p['nisn'] ?? '-';
    final String kelas = p['kelas'] ?? '-';
    final String verifikasi = a['status_verifikasi'] ?? 'Pending';
    final String fotoUrl = a['foto_url'] ?? '';
    final String keterangan = a['keterangan'] ?? '-';
    final String jamAbsen = a['waktu_absen'] ?? '-';
    final double? lat = a['lat'] as double?;
    final double? lng = a['lng'] as double?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              verifikasi == 'Pending' ? Icons.pending_actions_rounded : Icons.verified_user_rounded,
              color: verifikasi == 'Pending' ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Verifikasi: $namaMurid',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fotoUrl.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _tampilkanDetailFoto(context, fotoUrl, namaMurid),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Image.network(
                          fotoUrl,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150, color: Colors.grey.shade200,
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.zoom_in, color: Colors.white, size: 14), SizedBox(width: 4), Text('Perbesar', style: TextStyle(color: Colors.white, fontSize: 10))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📚 Kelas: $kelas | NISN: $nisn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900)),
                    const Divider(),
                    Text('⏰ Jam Scan: $jamAbsen WIB', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 6),
                    const Text('📍 Keterangan & Lokasi GPS:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(keterangan, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.3)),
                    
                    if (lat != null && lng != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade100)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed, size: 12, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text('Lat: $lat | Lng: $lng', style: const TextStyle(fontSize: 10, color: Colors.black87, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Status Otorisasi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: verifikasi == 'Pending' ? Colors.orange.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      verifikasi.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: verifikasi == 'Pending' ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Tutup', style: TextStyle(color: Colors.grey))
          ),
          if (a['status'] != 'A')
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateStatusAbsen(a['id'], 'A', 'Ditolak');
              },
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Tolak (Alfa)'),
            ),
          if (verifikasi == 'Pending')
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateStatusAbsen(a['id'], a['status'], 'Disetujui');
              },
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('SETUJUI (SAH)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter untuk Tab 2 (Rekap Akumulasi)
    final filteredRekap = _selectedKelasFilter == 'Semua Kelas'
        ? _listRekapSiswa
        : _listRekapSiswa.where((item) => item['kelas'] == _selectedKelasFilter).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Presensi & Rekap Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          backgroundColor: const Color(0xFF1E40AF),
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.white),
          // 🔥 REVISI PAK HALIM: KONSOLIDASI MENJADI 2 TAB TERPADU
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.fact_check_rounded), text: 'Aksi Cepat & Verifikasi'),
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Rekap Akumulasi'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
            : TabBarView(
                children: [
                  _buildTabAksiCepatHarian(),
                  _buildTabRekapAkumulasi(filteredRekap),
                ],
              ),
      ),
    );
  }

  // =========================================================================
  // WIDGET TAB 1: AKSI CEPAT & VERIFIKASI HARIAN
  // =========================================================================
  Widget _buildTabAksiCepatHarian() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Text(
                    'Tanggal: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  side: const BorderSide(color: Color(0xFF1E40AF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pilihTanggal,
                icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF1E40AF)),
                label: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _dataAbsen.isEmpty
              ? const Center(child: Text('Tidak ada data absensi mengajar Anda di tanggal ini.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16), itemCount: _dataAbsen.length,
                  itemBuilder: (context, index) {
                    final a = _dataAbsen[index];
                    final p = a['profiles'] ?? {};
                    final String? fotoUrl = a['foto_url'];
                    final String namaMurid = p['full_name'] ?? 'Nama Tidak Dikenal';
                    final String verifikasi = a['status_verifikasi'] ?? 'Pending';
                    final String jamAbsen = a['waktu_absen'] ?? '-'; 
                    final double? lat = a['lat'] as double?;
                    final double? lng = a['lng'] as double?;
                    
                    String statusText = 'Hadir'; Color warnaStatus = Colors.green; String kodeTampil = a['status'] ?? 'H';
                    if (a['status'] == 'I') { statusText = 'Izin / Sakit'; warnaStatus = Colors.orange; } else if (a['status'] == 'A') { statusText = 'Alfa'; warnaStatus = Colors.red; } else if (a['status'] == 'T') { statusText = 'Terlambat'; warnaStatus = Colors.amber.shade700; }

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16), 
                        side: BorderSide(color: verifikasi == 'Pending' ? Colors.orange : Colors.grey.shade300, width: verifikasi == 'Pending' ? 1.5 : 1.0)
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _bukaDialogVerifikasiGuru(a),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(radius: 22, backgroundColor: warnaStatus.withOpacity(0.15), child: Text(kodeTampil, style: TextStyle(color: warnaStatus, fontWeight: FontWeight.bold, fontSize: 18))),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(namaMurid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text('NISN: ${p['nisn'] ?? '-'} | Kelas: ${p['kelas'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.grey))])),
                                            const SizedBox(width: 8),
                                            if (a['status'] == 'I') Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_document, color: Colors.orange))
                                            else if (fotoUrl != null && fotoUrl.isNotEmpty) GestureDetector(onTap: () => _tampilkanDetailFoto(context, fotoUrl, namaMurid), child: MouseRegion(cursor: SystemMouseCursors.click, child: Tooltip(message: 'Klik untuk perbesar', child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200, width: 1.5), borderRadius: BorderRadius.circular(8)), child: Image.network(fotoUrl, width: 50, height: 50, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) { if (loadingProgress == null) return child; return const SizedBox(width: 50, height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2))); }, errorBuilder: (context, error, stackTrace) => Container(width: 50, height: 50, color: Colors.red.shade50, child: const Icon(Icons.broken_image, color: Colors.red, size: 20))))))))
                                            else Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text('📚 Mapel: ${a['mapel'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text('⏰ Jam Absen: $jamAbsen', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                            const Spacer(),
                                            if (lat != null && lng != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                                child: const Row(
                                                  children: [Icon(Icons.location_on, size: 10, color: Colors.blue), SizedBox(width: 2), Text('GPS Valid', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold))],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity, padding: const EdgeInsets.all(10), 
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), 
                                          child: Text('📌 Verifikasi: $verifikasi\n📝 Keterangan: ${a['keterangan']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87, height: 1.4))
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (verifikasi == 'Pending') 
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 12)), 
                                      onPressed: () => _updateStatusAbsen(a['id'], a['status'], 'Disetujui'), 
                                      icon: const Icon(Icons.check_circle, size: 16), 
                                      label: Text(a['status'] == 'I' ? 'ACC IZIN' : 'ACC SAH')
                                    ),
                                  if (a['status'] != 'A') 
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 12)), 
                                      onPressed: () => _updateStatusAbsen(a['id'], 'A', 'Ditolak'), 
                                      icon: const Icon(Icons.cancel, size: 16), 
                                      label: const Text('TOLAK / ALFA')
                                    ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade800, side: BorderSide(color: Colors.blue.shade800), textStyle: const TextStyle(fontSize: 12)),
                                    onPressed: () => _bukaDialogVerifikasiGuru(a),
                                    icon: const Icon(Icons.manage_search_rounded, size: 16),
                                    label: const Text('Periksa Detail'),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // WIDGET TAB 2: REKAP AKUMULASI KESELURUHAN
  // =========================================================================
  Widget _buildTabRekapAkumulasi(List<Map<String, dynamic>> filteredRekap) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF1E40AF)),
              const SizedBox(width: 10),
              const Text('Filter Kelas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedKelasFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: _daftarKelas.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedKelasFilter = val);
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredRekap.isEmpty
              ? const Center(child: Text('Tidak ada siswa pada kelas terpilih.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRekap.length,
                  itemBuilder: (context, index) {
                    final item = filteredRekap[index];
                    double persentase = item['persentase'] ?? 0.0;
                    bool isRajin = persentase >= 80.0;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(item['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: isRajin ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '${persentase.toStringAsFixed(1)}%',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isRajin ? Colors.green.shade700 : Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Kelas: ${item['kelas']} | NISN: ${item['nisn']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _itemStat('Hadir', item['hadir'].toString(), Colors.green.shade700),
                                _itemStat('Izin', item['izin'].toString(), Colors.orange.shade700),
                                _itemStat('Sakit', item['sakit'].toString(), Colors.blue.shade700),
                                _itemStat('Alfa', item['alfa'].toString(), Colors.red.shade700),
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
    );
  }

  Widget _itemStat(String label, String count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(count, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}