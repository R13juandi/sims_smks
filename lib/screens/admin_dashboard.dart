import 'package:flutter/material.dart';
import 'package:sims_smks/screens/manajemen_jadwal_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import 'rekap_nilai_admin_screen.dart';
import 'tambah_user_screen.dart';
import 'manajemen_user_screen.dart';
import 'seeder_database_screen.dart';
import 'admin_administrasi_screen.dart'; 

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _currentIndex = 0;
  
  String _currentUserRole = 'admin'; 

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _absensiHariIni = [];

  int _totalSiswa = 0;
  int _totalGuru = 0;
  int _jumlahHadir = 0;
  int _jumlahIzin = 0;
  int _jumlahSakit = 0;
  int _jumlahAlpa = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminAnalyticData();
  }

  Future<void> _loadAdminAnalyticData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userAuth = _supabase.auth.currentUser;
      if (userAuth != null) {
        final profileRes = await _supabase.from('profiles').select('role').eq('id', userAuth.id).single();
        _currentUserRole = profileRes['role']?.toString().toLowerCase().trim() ?? 'admin';
      }

      final usersRes = await _supabase.from('profiles').select('*');
      _allUsers = List<Map<String, dynamic>>.from(usersRes);

      _totalSiswa = _allUsers.where((u) => u['role'] == 'siswa').length;
      _totalGuru = _allUsers.where((u) => u['role'] == 'guru').length;

      final formatTanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final absenRes = await _supabase.from('absensi').select('*, profiles(full_name, role, kelas, nisn)').eq('tanggal', formatTanggal);
      _absensiHariIni = List<Map<String, dynamic>>.from(absenRes);

      _jumlahHadir = _absensiHariIni.where((a) => a['status'].toString().toUpperCase().contains('TEPAT') || a['status'].toString().toUpperCase().contains('HADIR') || a['status'].toString().toUpperCase() == 'T' || a['status'].toString().toUpperCase() == 'H').length;
      _jumlahIzin = _absensiHariIni.where((a) => a['status'].toString().toUpperCase() == 'IZIN' || a['status'].toString().toUpperCase() == 'I').length;
      _jumlahSakit = _absensiHariIni.where((a) => a['status'].toString().toUpperCase() == 'SAKIT' || a['status'].toString().toUpperCase() == 'S').length;
      _jumlahAlpa = _absensiHariIni.where((a) => a['status'].toString().toUpperCase() == 'ALPA' || a['status'].toString().toUpperCase() == 'A').length;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
              backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))],
            ),
            InteractiveViewer(
              panEnabled: true, minScale: 0.5, maxScale: 4.0,
              child: Image.network(url, fit: BoxFit.contain, loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
              }, errorBuilder: (context, error, stackTrace) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red)))),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))));
    }

    final List<Widget> childrenPage = [_buildBerandaKanalTab(), _buildManajemenAkunTab(), _buildRekapSistemTab()];

    String judulDashboard = 'DASHBOARD ADMIN';
    if (_currentUserRole.contains('kepsek')) {
      judulDashboard = 'DASHBOARD KEPALA SEKOLAH';
    } else if (_currentUserRole.contains('tata')) {
      judulDashboard = 'DASHBOARD TATA USAHA';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(judulDashboard, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.power_settings_new_rounded, color: Colors.red[600], size: 18),
              tooltip: 'Keluar Sistem',
              onPressed: () async {
                await _supabase.auth.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
              },
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: childrenPage[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, backgroundColor: Colors.white, selectedItemColor: const Color(0xFF0F172A), unselectedItemColor: const Color(0xFF94A3B8), selectedFontSize: 12, unselectedFontSize: 12, selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold), type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Monitor'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_rounded), label: 'Akun'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Rekap Sekolah'),
        ],
      ),
    );
  }

  // =========================================================================
  // 🔥 TAB 1: MONITOR ABSENSI (FOLDER KELAS & JAM SCAN DETAIL)
  // =========================================================================
  Widget _buildBerandaKanalTab() {
    Map<String, List<Map<String, dynamic>>> groupedAbsen = {};
    for (var a in _absensiHariIni) {
      final k = a['profiles']?['kelas'] ?? 'Tanpa Kelas';
      if (!groupedAbsen.containsKey(k)) groupedAbsen[k] = [];
      groupedAbsen[k]!.add(a);
    }

    return RefreshIndicator(
      onRefresh: _loadAdminAnalyticData, color: const Color(0xFF1E3A8A),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _cardMoni('Siswa Terdaftar', '$_totalSiswa', Icons.face_rounded, Colors.indigo)),
              const SizedBox(width: 12),
              Expanded(child: _cardMoni('Guru Aktif', '$_totalGuru', Icons.supervisor_account_rounded, Colors.teal)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Folder Pantauan Kedisiplinan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          const Text('Batas toleransi kehadiran otomatis: 07:45 WIB', style: TextStyle(fontSize: 12, color: Colors.red)),
          const SizedBox(height: 12),

          groupedAbsen.isEmpty
              ? Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Belum ada aktivitas presensi masuk hari ini.', style: TextStyle(color: Colors.grey, fontSize: 13))))
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: groupedAbsen.keys.length,
                  itemBuilder: (context, index) {
                    String namaKelas = groupedAbsen.keys.elementAt(index);
                    List<Map<String, dynamic>> dataKelas = groupedAbsen[namaKelas]!;

                    return Card(
                      elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                      child: ExpansionTile(
                        shape: const Border(),
                        leading: const Icon(Icons.folder_open_rounded, color: Colors.orange, size: 36),
                        title: Text('Kelas $namaKelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text('${dataKelas.length} Siswa Terverifikasi', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        children: dataKelas.map((data) {
                          final nama = data['profiles']?['full_name'] ?? 'User';
                          final statusOri = data['status'] ?? '-';
                          final fotoUrl = data['foto_url'];
                          
                          final waktuScanStr = data['waktu_absen'] ?? '00:00';
                          int hour = 0; int minute = 0;
                          try {
                            if (waktuScanStr.contains(':')) {
                              hour = int.parse(waktuScanStr.split(':')[0]);
                              minute = int.parse(waktuScanStr.split(':')[1]);
                            }
                          } catch(e){}

                          bool isTelat = false;
                          String labelStatus = 'Tepat Waktu';
                          Color warnaStatus = Colors.green;

                          if (hour > 7 || (hour == 7 && minute > 45)) {
                            isTelat = true; labelStatus = 'Terlambat / Alfa'; warnaStatus = Colors.red;
                          }
                          
                          if (statusOri == 'I') { labelStatus = 'Izin Resmi'; warnaStatus = Colors.orange; isTelat = false; } 
                          else if (statusOri == 'S') { labelStatus = 'Sakit'; warnaStatus = Colors.blue; isTelat = false; }

                          return Container(
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(color: warnaStatus.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: warnaStatus.withOpacity(0.5))),
                                  child: Text(waktuScanStr, style: TextStyle(fontWeight: FontWeight.bold, color: warnaStatus, fontSize: 14)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
                                  const SizedBox(height: 2),
                                  Text(labelStatus, style: TextStyle(fontSize: 11, color: warnaStatus, fontWeight: FontWeight.bold))
                                ])),
                                const SizedBox(width: 8),
                                
                                if (statusOri == 'I' || statusOri == 'S') 
                                  Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_document, color: Colors.orange, size: 20))
                                else if (fotoUrl != null && fotoUrl.isNotEmpty) 
                                  GestureDetector(onTap: () => _tampilkanDetailFoto(context, fotoUrl, nama), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 40, height: 40, color: Colors.red.shade50, child: const Icon(Icons.broken_image, color: Colors.red, size: 16)))))
                                else 
                                  Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, color: Colors.grey, size: 20)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _cardMoni(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)]),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11), overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)))]))
        ],
      ),
    );
  }

  // ==================== TAB 2: MANAJEMEN AKUN ====================
  Widget _buildManajemenAkunTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Pusat Kontrol Akses Akun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
        const SizedBox(height: 14),

        _buildMenuButton(Icons.supervised_user_circle_rounded, 'Manajemen Database Pengguna', 'Tambah, Edit profil, Hapus, & Reset Sandi', const Color(0xFF0F172A), () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManajemenUserScreen(currentUserRole: _currentUserRole)))),
        const SizedBox(height: 12),

        if (!_currentUserRole.contains('kepsek')) ...[
          _buildMenuButton(Icons.calendar_month_rounded, 'Manajemen Jadwal Pelajaran', 'Atur jadwal pelajaran', Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManajemenJadwalScreen()))),
          const SizedBox(height: 12),
          _buildMenuButton(Icons.account_balance_wallet_rounded, 'Administrasi Keuangan & SPP', 'Input pembayaran & Riwayat SPP', Colors.teal.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAdministrasiScreen()))),
          const SizedBox(height: 12),
        ],
        
        _buildMenuButton(Icons.grade_rounded, 'Super Manajemen Nilai', 'Pantau nilai & Cetak e-Rapor Kurikulum', Colors.orange.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RekapNilaiAdminScreen()))),
      ],
    );
  }

  Widget _buildMenuButton(IconData icon, String title, String sub, Color color, VoidCallback action) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: action, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))), const SizedBox(height: 3), Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRekapSistemTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Statistik Kehadiran Sekolah Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))), const SizedBox(height: 16),
        _buildProgressBarEksekutif('Hadir / Tepat Waktu', _jumlahHadir, Colors.green),
        _buildProgressBarEksekutif('Izin Keterangan', _jumlahIzin, Colors.orange),
        _buildProgressBarEksekutif('Sakit Berkas', _jumlahSakit, Colors.blue),
        _buildProgressBarEksekutif('Alpa / Tanpa Keterangan', _jumlahAlpa, Colors.red),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const RekapAbsensiAdminScreen())); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
          icon: const Icon(Icons.analytics_rounded), label: const Text('BUKA REKAP AKUMULASI BULANAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
      ],
    );
  }

  Widget _buildProgressBarEksekutif(String label, int count, Color color) {
    double persentase = _absensiHariIni.isEmpty ? 0.0 : count / _absensiHariIni.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))), Text('$count Jiwa (${(persentase * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _absensiHariIni.isEmpty ? 0.0 : persentase, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8)),
        ],
      ),
    );
  }
}

// ====================================================================================
// 🔥 HALAMAN: LAPORAN AKUMULASI (DENGAN FOLDER KELAS & DETAIL LOG)
// ====================================================================================
class RekapAbsensiAdminScreen extends StatefulWidget {
  const RekapAbsensiAdminScreen({super.key});
  @override
  State<RekapAbsensiAdminScreen> createState() => _RekapAbsensiAdminScreenState();
}

class _RekapAbsensiAdminScreenState extends State<RekapAbsensiAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rekapData = [];
  
  String _selectedBulan = DateFormat('MM').format(DateTime.now());
  String _selectedTahun = DateFormat('yyyy').format(DateTime.now());

  final List<Map<String, String>> _listBulan = [
    {'id': '01', 'nama': 'Januari'}, {'id': '02', 'nama': 'Februari'}, {'id': '03', 'nama': 'Maret'}, {'id': '04', 'nama': 'April'}, {'id': '05', 'nama': 'Mei'}, {'id': '06', 'nama': 'Juni'}, {'id': '07', 'nama': 'Juli'}, {'id': '08', 'nama': 'Agustus'}, {'id': '09', 'nama': 'September'}, {'id': '10', 'nama': 'Oktober'}, {'id': '11', 'nama': 'November'}, {'id': '12', 'nama': 'Desember'},
  ];
  final List<String> _listTahun = ['2024', '2025', '2026', '2027', '2028'];

  @override
  void initState() { super.initState(); _fetchRekapBulanan(); }

  Future<void> _fetchRekapBulanan() async {
    setState(() => _isLoading = true);
    try {
      final siswaRes = await _supabase.from('profiles').select('id, full_name, nisn, kelas').eq('role', 'siswa');
      List<Map<String, dynamic>> allSiswa = List<Map<String, dynamic>>.from(siswaRes);

      Map<String, Map<String, dynamic>> akumulasi = {};
      for (var s in allSiswa) {
        akumulasi[s['id']] = {
          'id': s['id'], 'nama': s['full_name'] ?? 'Tanpa Nama', 'nisn': s['nisn'] ?? '-', 'kelas': s['kelas'] ?? '-',
          'H': 0, 'I': 0, 'S': 0, 'A': 0, 'T': 0,
        };
      }

      int year = int.parse(_selectedTahun); int month = int.parse(_selectedBulan);
      String startDate = '$_selectedTahun-$_selectedBulan-01';
      int lastDay = DateTime(year, month + 1, 0).day; 
      String endDate = '$_selectedTahun-$_selectedBulan-${lastDay.toString().padLeft(2, '0')}';

      final absenRes = await _supabase.from('absensi').select('siswa_id, status').gte('tanggal', startDate).lte('tanggal', endDate);

      for (var a in absenRes) {
        final idSiswa = a['siswa_id'];
        if (idSiswa != null && akumulasi.containsKey(idSiswa)) {
          final status = a['status'].toString().toUpperCase();
          if (status.contains('H') || status.contains('TEPAT')) akumulasi[idSiswa]!['H'] = (akumulasi[idSiswa]!['H'] as int) + 1;
          else if (status == 'I' || status == 'IZIN') akumulasi[idSiswa]!['I'] = (akumulasi[idSiswa]!['I'] as int) + 1;
          else if (status == 'S' || status == 'SAKIT') akumulasi[idSiswa]!['S'] = (akumulasi[idSiswa]!['S'] as int) + 1;
          else if (status == 'A' || status == 'ALPA') akumulasi[idSiswa]!['A'] = (akumulasi[idSiswa]!['A'] as int) + 1;
          else if (status == 'T' || status == 'TERLAMBAT') akumulasi[idSiswa]!['T'] = (akumulasi[idSiswa]!['T'] as int) + 1;
        }
      }

      final List<Map<String, dynamic>> finalData = akumulasi.values.toList();
      if (mounted) setState(() { _rekapData = finalData; _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedByKelas = {};
    for (var s in _rekapData) {
      final kelas = s['kelas'];
      if (!groupedByKelas.containsKey(kelas)) groupedByKelas[kelas] = [];
      groupedByKelas[kelas]!.add(s);
    }
    final sortedKelas = groupedByKelas.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Laporan Akumulasi Bulanan', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                Expanded(flex: 2, child: DropdownButtonFormField<String>(value: _selectedBulan, decoration: InputDecoration(labelText: 'Bulan', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _listBulan.map((b) => DropdownMenuItem(value: b['id'], child: Text(b['nama']!))).toList(), onChanged: (val) { if (val != null) { setState(() => _selectedBulan = val); _fetchRekapBulanan(); } })),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: DropdownButtonFormField<String>(value: _selectedTahun, decoration: InputDecoration(labelText: 'Tahun', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _listTahun.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (val) { if (val != null) { setState(() => _selectedTahun = val); _fetchRekapBulanan(); } })),
              ],
            ),
          ),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
                : sortedKelas.isEmpty ? const Center(child: Text('Data kosong.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: sortedKelas.length,
                        itemBuilder: (context, index) {
                          final kelas = sortedKelas[index];
                          final siswaList = groupedByKelas[kelas]!;
                          siswaList.sort((a, b) => a['nama'].toString().compareTo(b['nama'].toString()));

                          return Card(
                            elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                            child: ExpansionTile(
                              leading: const Icon(Icons.folder_shared_rounded, color: Colors.amber, size: 36),
                              title: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Text('${siswaList.length} Siswa', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              children: siswaList.map((data) {
                                return InkWell(
                                  onTap: () => _lihatDetailLogSiswa(context, data['id'], data['nama'], _selectedBulan, _selectedTahun),
                                  child: Container(
                                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))), padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildStatusBadge('Hadir', data['H'], Colors.green), _buildStatusBadge('Izin', data['I'], Colors.orange),
                                            _buildStatusBadge('Sakit', data['S'], Colors.blue), _buildStatusBadge('Alpa', data['A'], Colors.red),
                                            if (data['T'] > 0) _buildStatusBadge('Telat', data['T'], Colors.amber.shade700),
                                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
                                          ],
                                        ),
                                      ],
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

  Widget _buildStatusBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))), child: Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color))),
      ],
    );
  }

 // BUKA MODAL DETAIL LOG HARIAN (WAKTU, LOKASI, FOTO)
  void _lihatDetailLogSiswa(BuildContext context, String idSiswa, String nama, String bulan, String tahun) async {
    // 🔥 PERBAIKAN: Gunakan perhitungan rentang tanggal (kebal tipe data Date)
    int year = int.parse(tahun);
    int month = int.parse(bulan);
    String startDate = '$tahun-$bulan-01';
    int lastDay = DateTime(year, month + 1, 0).day; 
    String endDate = '$tahun-$bulan-${lastDay.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), 
                child: Row(children: [const Icon(Icons.history_rounded, color: Color(0xFF1E40AF)), const SizedBox(width: 8), Expanded(child: Text('Riwayat Absen: $nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))])
              ),
              Expanded(
                child: FutureBuilder(
                  // 🔥 PERBAIKAN: Ganti .like menjadi .gte dan .lte di sini
                  future: _supabase
                      .from('absensi')
                      .select('*')
                      .eq('siswa_id', idSiswa)
                      .gte('tanggal', startDate)
                      .lte('tanggal', endDate)
                      .order('tanggal', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || (snapshot.data as List).isEmpty) return const Center(child: Text('Tidak ada riwayat absen di bulan ini.'));
                    final logs = snapshot.data as List;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16), itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final foto = log['foto_url'];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                          child: ListTile(
                            leading: foto != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(foto, width: 50, height: 50, fit: BoxFit.cover)) : const Icon(Icons.location_on, color: Colors.red),
                            title: Text(log['tanggal'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Scan Masuk: ${log['waktu_absen'] ?? '-'}\nStatus: ${log['status']}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}