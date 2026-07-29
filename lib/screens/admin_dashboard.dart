import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/popup_service.dart';
import '../login_screen.dart';
import 'rekap_nilai_admin_screen.dart';
import 'tambah_user_screen.dart';
import 'manajemen_user_screen.dart';
import 'seeder_database_screen.dart';
import 'manajemen_jadwal_screen.dart';

// =========================================================================
// 1. DASHBOARD ADMIN / KEPSEK / TATA USAHA (HANYA 2 TAB)
// =========================================================================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // 🔥 INDEX HANYA 0 & 1 SEKARANG (2 TAB)
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
        final profileRes = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', userAuth.id)
            .maybeSingle();
        _currentUserRole =
            profileRes?['role']?.toString().toLowerCase().trim() ?? 'admin';
      }

      final usersRes = await _supabase.from('profiles').select('*');
      _allUsers = List<Map<String, dynamic>>.from(usersRes as List);

      _totalSiswa = _allUsers.where((u) => u['role'] == 'siswa').length;
      _totalGuru = _allUsers.where((u) => u['role'] == 'guru').length;

      final formatTanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final absenRes = await _supabase
          .from('absensi')
          .select('*, profiles(full_name, role, kelas, nisn)')
          .eq('tanggal', formatTanggal);
      _absensiHariIni = List<Map<String, dynamic>>.from(absenRes as List);

      _jumlahHadir = _absensiHariIni
          .where(
            (a) =>
                a['status'].toString().toUpperCase().contains('TEPAT') ||
                a['status'].toString().toUpperCase().contains('HADIR') ||
                a['status'].toString().toUpperCase() == 'T' ||
                a['status'].toString().toUpperCase() == 'H',
          )
          .length;
      _jumlahIzin = _absensiHariIni
          .where(
            (a) =>
                a['status'].toString().toUpperCase() == 'IZIN' ||
                a['status'].toString().toUpperCase() == 'I',
          )
          .length;
      _jumlahSakit = _absensiHariIni
          .where(
            (a) =>
                a['status'].toString().toUpperCase() == 'SAKIT' ||
                a['status'].toString().toUpperCase() == 'S',
          )
          .length;
      _jumlahAlpa = _absensiHariIni
          .where(
            (a) =>
                a['status'].toString().toUpperCase() == 'ALPA' ||
                a['status'].toString().toUpperCase() == 'A',
          )
          .length;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(
          context,
          'Gagal memuat data analitik: $e',
          isSuccess: false,
          judul: 'Terjadi Kesalahan',
        );
      }
    }
  }

  void _tampilkanDetailFoto(
    BuildContext context,
    String url,
    String namaSiswa,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                'Bukti Presensi: $namaSiswa',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 50,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
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
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
        ),
      );
    }

    // 🔥 HANYA 2 HALAMAN (MONITOR & MENU UTAMA). Tidak ada tab ke-3.
    final List<Widget> childrenPage = [
      _buildBerandaKanalTab(),
      _buildManajemenAkunTab(),
    ];

    bool isKepsek = _currentUserRole.contains('kepsek');
    bool isTU = _currentUserRole.contains('tata') || _currentUserRole.contains('tu');

    String judulDashboard = 'DASHBOARD ADMIN';
    if (isKepsek) {
      judulDashboard = 'PANTAUAN KEPALA SEKOLAH';
    } else if (isTU) {
      judulDashboard = 'DASHBOARD TATA USAHA';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judulDashboard,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.8,
                color: Color(0xFF0F172A),
              ),
            ),
            if (isKepsek)
              const Text(
                'Mode Eksekutif (Hanya Lihat / Read-Only)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.power_settings_new_rounded,
                color: Colors.red[600],
                size: 18,
              ),
              tooltip: 'Keluar Sistem',
              onPressed: () {
                PopupService.showConfirm(
                  context,
                  'Apakah Anda yakin ingin keluar dari sistem?',
                  judul: 'Konfirmasi Keluar',
                  onConfirm: () async {
                    await _supabase.auth.signOut();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: childrenPage[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0F172A),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        // 🔥 ITEM BOTTOM NAV HANYA SISA 2
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Menu Utama',
          ),
        ],
      ),
    );
  }

  Widget _buildBerandaKanalTab() {
    Map<String, List<Map<String, dynamic>>> groupedAbsen = {};
    for (var a in _absensiHariIni) {
      final k = a['profiles']?['kelas'] ?? 'Tanpa Kelas';
      if (!groupedAbsen.containsKey(k)) groupedAbsen[k] = [];
      groupedAbsen[k]!.add(a);
    }

    return RefreshIndicator(
      onRefresh: _loadAdminAnalyticData,
      color: const Color(0xFF1E3A8A),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _cardMoni(
                  'Siswa Terdaftar',
                  '$_totalSiswa',
                  Icons.face_rounded,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _cardMoni(
                  'Guru Aktif',
                  '$_totalGuru',
                  Icons.supervisor_account_rounded,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 🔥 GRAFIK PROGRESS BAR SEKARANG ADA DI SINI
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistik Kehadiran Hari Ini',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildProgressBarEksekutif('Hadir / Tepat', _jumlahHadir, Colors.green),
                _buildProgressBarEksekutif('Izin Keterangan', _jumlahIzin, Colors.orange),
                _buildProgressBarEksekutif('Sakit Berkas', _jumlahSakit, Colors.blue),
                _buildProgressBarEksekutif('Alpa / Bolos', _jumlahAlpa, Colors.red),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Folder Pantauan Kedisiplinan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
          ),
          const Text(
            'Batas toleransi kehadiran otomatis: 07:45 WIB',
            style: TextStyle(fontSize: 12, color: Colors.red),
          ),
          const SizedBox(height: 12),

          groupedAbsen.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada aktivitas presensi masuk hari ini.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: groupedAbsen.keys.length,
                  itemBuilder: (context, index) {
                    String namaKelas = groupedAbsen.keys.elementAt(index);
                    List<Map<String, dynamic>> dataKelas =
                        groupedAbsen[namaKelas]!;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ExpansionTile(
                        shape: const Border(),
                        leading: const Icon(
                          Icons.folder_open_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                        title: Text(
                          'Kelas $namaKelas',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${dataKelas.length} Siswa Terverifikasi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        children: dataKelas.map((data) {
                          final nama = data['profiles']?['full_name'] ?? 'User';
                          final statusOri = data['status'] ?? '-';
                          final fotoUrl = data['foto_url'];

                          final waktuScanStr = data['waktu_absen'] ?? '00:00';
                          int hour = 0;
                          int minute = 0;
                          try {
                            if (waktuScanStr.contains(':')) {
                              hour = int.parse(waktuScanStr.split(':')[0]);
                              minute = int.parse(waktuScanStr.split(':')[1]);
                            }
                          } catch (e) {}

                          String labelStatus = 'Tepat Waktu';
                          Color warnaStatus = Colors.green;

                          if (hour > 7 || (hour == 7 && minute > 45)) {
                            labelStatus = 'Terlambat / Alfa';
                            warnaStatus = Colors.red;
                          }

                          if (statusOri == 'I') {
                            labelStatus = 'Izin Resmi';
                            warnaStatus = Colors.orange;
                          } else if (statusOri == 'S') {
                            labelStatus = 'Sakit';
                            warnaStatus = Colors.blue;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: warnaStatus.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: warnaStatus.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    waktuScanStr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: warnaStatus,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        labelStatus,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: warnaStatus,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                if (statusOri == 'I' || statusOri == 'S')
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit_document,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  )
                                else if (fotoUrl != null && fotoUrl.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => _tampilkanDetailFoto(
                                      context,
                                      fotoUrl,
                                      nama,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        fotoUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.red.shade50,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ),
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

  Widget _buildProgressBarEksekutif(String label, int count, Color color) {
    double persentase = _absensiHariIni.isEmpty
        ? 0.0
        : count / _absensiHariIni.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
              Text(
                '$count Orang (${(persentase * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _absensiHariIni.isEmpty ? 0.0 : persentase,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMoni(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManajemenAkunTab() {
    bool isKepsek = _currentUserRole.contains('kepsek');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          isKepsek ? 'Portal Navigasi Eksekutif' : 'Pusat Kontrol Akses Akun & Fitur',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),

        // 1. MANAJEMEN USER
        _buildMenuButton(
          Icons.supervised_user_circle_rounded,
          'Manajemen Database Pengguna',
          isKepsek
              ? 'Pantau data seluruh Siswa & Guru'
              : 'Tambah, Edit profil, Hapus, & Reset Sandi',
          const Color(0xFF0F172A),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManajemenUserScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. JADWAL PELAJARAN
        _buildMenuButton(
          Icons.calendar_month_rounded,
          'Manajemen Jadwal Pelajaran',
          isKepsek
              ? 'Lihat struktur jadwal pelajaran sekolah'
              : 'Atur & susun jadwal pelajaran',
          Colors.indigo,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManajemenJadwalScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. KEUANGAN & SPP
        _buildMenuButton(
          Icons.account_balance_wallet_rounded,
          'Administrasi Keuangan & SPP',
          isKepsek
              ? 'Pantau laporan keuangan & arus kas SPP'
              : 'Input pembayaran & Verifikasi SPP',
          Colors.teal.shade700,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminAdministrasiScreen(
                userRole: _currentUserRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. SUPER MANAJEMEN NILAI
        _buildMenuButton(
          Icons.grade_rounded,
          'Super Manajemen Nilai & Rapor',
          'Pantau rekap nilai & Cetak e-Rapor Kurikulum',
          Colors.orange.shade700,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RekapNilaiAdminScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // 5. REKAP ABSENSI BULANAN (TOMBOL PINDAHAN)
        _buildMenuButton(
          Icons.analytics_rounded,
          'Laporan Akumulasi Absensi',
          'Lihat dan cetak rekap kehadiran siswa per bulan',
          Colors.blue.shade700,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RekapAbsensiAdminScreen(
                userRole: _currentUserRole,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton(
    IconData icon,
    String title,
    String sub,
    Color color,
    VoidCallback action,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 2. REKAP AKUMULASI BULANAN (WITH KEPSEK READ-ONLY PROTECTOR)
// =========================================================================
class RekapAbsensiAdminScreen extends StatefulWidget {
  final String userRole;
  const RekapAbsensiAdminScreen({super.key, this.userRole = 'admin'});

  @override
  State<RekapAbsensiAdminScreen> createState() =>
      _RekapAbsensiAdminScreenState();
}

class _RekapAbsensiAdminScreenState extends State<RekapAbsensiAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rekapData = [];

  String _selectedBulan = DateFormat('MM').format(DateTime.now());
  String _selectedTahun = DateFormat('yyyy').format(DateTime.now());

  final List<Map<String, String>> _listBulan = [
    {'id': '01', 'nama': 'Januari'},
    {'id': '02', 'nama': 'Februari'},
    {'id': '03', 'nama': 'Maret'},
    {'id': '04', 'nama': 'April'},
    {'id': '05', 'nama': 'Mei'},
    {'id': '06', 'nama': 'Juni'},
    {'id': '07', 'nama': 'Juli'},
    {'id': '08', 'nama': 'Agustus'},
    {'id': '09', 'nama': 'September'},
    {'id': '10', 'nama': 'Oktober'},
    {'id': '11', 'nama': 'November'},
    {'id': '12', 'nama': 'Desember'},
  ];
  final List<String> _listTahun = ['2024', '2025', '2026', '2027', '2028'];

  @override
  void initState() {
    super.initState();
    _fetchRekapBulanan();
  }

  Future<void> _fetchRekapBulanan() async {
    setState(() => _isLoading = true);
    try {
      int year = int.parse(_selectedTahun);
      int month = int.parse(_selectedBulan);
      String startDate = '$_selectedTahun-$_selectedBulan-01';
      int lastDay = DateTime(year, month + 1, 0).day;
      String endDate =
          '$_selectedTahun-$_selectedBulan-${lastDay.toString().padLeft(2, '0')}';

      final response = await _supabase.rpc(
        'get_rekap_bulanan_siswa',
        params: {'p_start_date': startDate, 'p_end_date': endDate},
      );

      final List<Map<String, dynamic>> finalData = (response as List)
          .map(
            (item) => {
              'id': item['id'],
              'nama': item['nama'],
              'nisn': item['nisn'],
              'kelas': item['kelas'],
              'H': item['hadir'] ?? 0,
              'I': item['izin'] ?? 0,
              'S': item['sakit'] ?? 0,
              'A': item['alpa'] ?? 0,
              'T': item['telat'] ?? 0,
            },
          )
          .toList();

      if (mounted) {
        setState(() {
          _rekapData = finalData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(
          context,
          'Gagal memuat rekap bulanan dari server RPC: $e',
          isSuccess: false,
          judul: 'Terjadi Kesalahan',
        );
      }
    }
  }

  Future<void> _updateStatusAbsenAdmin(dynamic idAbsen, String statusBaru, String verifikasi) async {
    if (widget.userRole.contains('kepsek')) return;
    try {
      await _supabase.from('absensi').update({
        'status': statusBaru,
        'status_verifikasi': verifikasi,
      }).eq('id', idAbsen);
      
      if (!mounted) return;
      PopupService.show(context, 'Status berhasil diubah menjadi $verifikasi ($statusBaru)!', isSuccess: true);
      _fetchRekapBulanan(); 
      Navigator.pop(context); 
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal mengupdate: $e', isSuccess: false);
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
    Map<String, List<Map<String, dynamic>>> groupedByKelas = {};
    for (var s in _rekapData) {
      final kelas = s['kelas'];
      if (!groupedByKelas.containsKey(kelas)) groupedByKelas[kelas] = [];
      groupedByKelas[kelas]!.add(s);
    }
    final sortedKelas = groupedByKelas.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Laporan Akumulasi Bulanan',
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
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedBulan,
                    decoration: InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _listBulan
                        .map(
                          (b) => DropdownMenuItem(
                            value: b['id'],
                            child: Text(b['nama']!),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBulan = val);
                        _fetchRekapBulanan();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedTahun,
                    decoration: InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _listTahun
                        .map(
                          (t) => DropdownMenuItem(value: t, child: Text(t)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedTahun = val);
                        _fetchRekapBulanan();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
                  )
                : sortedKelas.isEmpty
                ? const Center(
                    child: Text(
                      'Data kosong.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedKelas.length,
                    itemBuilder: (context, index) {
                      final kelas = sortedKelas[index];
                      final siswaList = groupedByKelas[kelas]!;
                      siswaList.sort(
                        (a, b) => a['nama'].toString().compareTo(
                          b['nama'].toString(),
                        ),
                      );

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
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
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${siswaList.length} Siswa',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          children: siswaList.map((data) {
                            return InkWell(
                              onTap: () => _lihatDetailLogSiswa(
                                context,
                                data['id'],
                                data['nama'],
                                _selectedBulan,
                                _selectedTahun,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['nama'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatusBadge(
                                          'Hadir',
                                          data['H'],
                                          Colors.green,
                                        ),
                                        _buildStatusBadge(
                                          'Izin',
                                          data['I'],
                                          Colors.orange,
                                        ),
                                        _buildStatusBadge(
                                          'Sakit',
                                          data['S'],
                                          Colors.blue,
                                        ),
                                        _buildStatusBadge(
                                          'Alfa',
                                          data['A'],
                                          Colors.red,
                                        ),
                                        if (data['T'] > 0)
                                          _buildStatusBadge(
                                            'Telat',
                                            data['T'],
                                            Colors.amber.shade700,
                                          ),
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _lihatDetailLogSiswa(
    BuildContext context,
    String idSiswa,
    String nama,
    String bulan,
    String tahun,
  ) async {
    int year = int.parse(tahun);
    int month = int.parse(bulan);
    String startDate = '$tahun-$bulan-01';
    int lastDay = DateTime(year, month + 1, 0).day;
    String endDate = '$tahun-$bulan-${lastDay.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Color(0xFF1E40AF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Riwayat Absen: $nama',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _supabase
                      .from('absensi')
                      .select('*')
                      .eq('siswa_id', idSiswa)
                      .gte('tanggal', startDate)
                      .lte('tanggal', endDate)
                      .order('tanggal', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                      return const Center(
                        child: Text('Tidak ada riwayat absen di bulan ini.'),
                      );
                    }
                    final logs = snapshot.data as List;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final String? foto = log['foto_url'];
                        final String verifikasi = log['status_verifikasi'] ?? 'Pending';
                        final String jamAbsen = log['waktu_absen'] ?? '-';
                        final String keterangan = log['keterangan'] ?? '-';
                        final double? lat = log['lat'] as double?;
                        final double? lng = log['lng'] as double?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: verifikasi == 'Pending' ? Colors.orange : Colors.grey.shade300,
                              width: verifikasi == 'Pending' ? 1.5 : 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (foto != null && foto.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => _tampilkanDetailFoto(context, foto, nama),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(foto, width: 45, height: 45, fit: BoxFit.cover),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.location_on, color: Colors.blue),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(log['tanggal'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              Text('Status: ${log['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: log['status'] == 'A' ? Colors.red : Colors.green)),
                                            ],
                                          ),
                                          Text('⏰ Scan: $jamAbsen WIB | Mapel: ${log['mapel'] ?? "-"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Text('📍 Keterangan: $keterangan\n📌 Verifikasi: $verifikasi ${lat != null ? "(GPS: $lat, $lng)" : ""}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87, height: 1.3)),
                                ),
                                
                                // HANYA BISA DIUBAH JIKA BUKAN KEPSEK & STATUS MASIH PENDING
                                if (!widget.userRole.contains('kepsek') && verifikasi == 'Pending') ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                                        onPressed: () => _updateStatusAbsenAdmin(log['id'], 'A', 'Ditolak'),
                                        child: const Text('Tolak (Alfa)', style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                                        onPressed: () => _updateStatusAbsenAdmin(log['id'], log['status'], 'Disetujui'),
                                        child: const Text('ACC SAH (Override)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ]
                              ],
                            ),
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
      },
    );
  }
}

// =========================================================================
// 3. ADMINISTRASI KEUANGAN (WITH KEPSEK READ-ONLY PROTECTOR)
// =========================================================================
class AdminAdministrasiScreen extends StatefulWidget {
  final String userRole;
  const AdminAdministrasiScreen({super.key, this.userRole = 'admin'});

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
    if (widget.userRole.contains('kepsek')) return; // Guard Kepsek
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
    if (widget.userRole.contains('kepsek')) return; // Guard Kepsek
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
    final bool isSuccess = (warna == Colors.green || warna == Colors.blue);
    PopupService.show(
      context,
      pesan,
      isSuccess: isSuccess,
      judul: isSuccess ? 'Berhasil' : 'Pemberitahuan',
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isKepsek = widget.userRole.contains('kepsek');

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
        title: Text(
          isKepsek ? 'Laporan Keuangan & SPP (Eksekutif)' : 'Keuangan Tata Usaha',
          style: const TextStyle(
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
                                                      userRole: widget.userRole,
                                                    ),
                                                  ),
                                                ).then((_) => _fetchDataAwal());
                                              },
                                              child: Text(
                                                isKepsek ? 'Lihat Laporan' : 'Buka Kasir',
                                              ),
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
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    
                                    // BILA KEPSEK -> HANYA TAMPILKAN STATUS TANPA TOMBOL AKSI
                                    if (isKepsek)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                        child: const Text(
                                          'Status: Menunggu eksekusi verifikasi oleh Staf Tata Usaha.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                                        ),
                                      )
                                    else
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
// 4. DETAIL KASIR DENGAN DUKUNGAN READ-ONLY UNTUK KEPSEK
// =========================================================================
class DetailKasirScreen extends StatefulWidget {
  final Map<String, dynamic> siswaData;
  final String userRole;

  const DetailKasirScreen({
    super.key,
    required this.siswaData,
    this.userRole = 'admin',
  });

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
    final bool isSuccess = (warna == Colors.green || warna == Colors.blue);
    PopupService.show(
      context,
      pesan,
      isSuccess: isSuccess,
      judul: isSuccess ? 'Berhasil' : 'Pemberitahuan',
    );
  }

  void _bukaDialogInputBayar() {
    if (widget.userRole.contains('kepsek')) return; // Guard Kepsek

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
                          nominalCtrl.text = (_hargaTagihan[val] ?? 0)
                              .toString();
                          if (!val.contains('SPP')) selectedBulan = '-';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
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
    if (widget.userRole.contains('kepsek')) return; // Guard Kepsek
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
        'bulan_tagihan': keterangan,
        'nominal': nominal,
        'status': 'LUNAS',
        'tanggal_bayar': DateTime.now().toIso8601String(),
        'penerima': user?.email ?? 'Admin TU',
      });

      await _fetchRiwayat();
      if (mounted) {
        _showSnackBar('Uang diterima & tercatat LUNAS!', Colors.green);
      }
    } catch (e) {
      debugPrint('Error _prosesSimpanPembayaran: $e');
      if (mounted) {
        _showSnackBar('Gagal menyimpan pembayaran: $e', Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  void _bukaDialogHistoriTagihan(String kategori, List<Map<String, dynamic>> listBayar, int totalMasuk, int kewajiban) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final int sisaKurang = (kewajiban - totalMasuk) > 0 ? (kewajiban - totalMasuk) : 0;
    final bool isLunas = sisaKurang == 0 && totalMasuk > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isLunas ? Icons.check_circle : Icons.warning_amber_rounded, color: isLunas ? Colors.green : Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text('Riwayat: $kategori', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isLunas ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isLunas ? Colors.green.shade200 : Colors.orange.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Kewajiban: ${formatter.format(kewajiban)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Sudah Dibayar: ${formatter.format(totalMasuk)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade800)),
                    Text('Sisa Kekurangan: ${formatter.format(sisaKurang)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isLunas ? Colors.green.shade900 : Colors.red.shade700)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Daftar Tanggal & Jam Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Divider(),
              if (listBayar.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Belum ada transaksi untuk tagihan ini.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listBayar.length,
                  itemBuilder: (context, i) {
                    final b = listBayar[i];
                    final rawDate = (b['tanggal_bayar'] ?? b['created_at'] ?? '').toString();
                    String tglTampil = rawDate;
                    try {
                      if (rawDate.isNotEmpty) tglTampil = DateFormat('dd MMMM yyyy - HH:mm WIB').format(DateTime.parse(rawDate).toLocal());
                    } catch (_) {}
                    final nom = b['nominal'] ?? 0;
                    final ket = (b['bulan_tagihan'] ?? '-').toString();
                    final penerima = (b['penerima'] ?? 'Admin TU').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatter.format(nom), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 14)),
                              IconButton(
                                icon: const Icon(Icons.print, color: Colors.red, size: 18), 
                                tooltip: 'Cetak Kwitansi', 
                                padding: EdgeInsets.zero, 
                                constraints: const BoxConstraints(), 
                                onPressed: () => _cetakKwitansiPDF(b),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Waktu: $tglTampil', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
                          Text('Keterangan: $ket | Kasir: $penerima', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

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
    bool isKepsek = widget.userRole.contains('kepsek');

    final Map<String, List<Map<String, dynamic>>> groupedRiwayat = {};
    for (var bayar in _riwayatBayar) {
      final jenis = (bayar['jenis_pembayaran'] ?? 'Lainnya').toString();
      groupedRiwayat.putIfAbsent(jenis, () => []).add(bayar);
    }

    final namaSiswa = (widget.siswaData['full_name'] ?? '-').toString();
    final nisnSiswa = (widget.siswaData['nisn'] ?? '-').toString();
    final kelasSiswa = (widget.siswaData['kelas'] ?? '-').toString();
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isKepsek ? 'Laporan Kasir Siswa' : 'Detail Kasir Keuangan',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      // SEMBUNYIKAN FAB "INPUT TERIMA UANG" JIKA LOGIN SEBAGAI KEPSEK
      floatingActionButton: isKepsek
          ? null
          : FloatingActionButton.extended(
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Daftar Kewajiban & Status Lunas (Master-Detail)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _kategoriFolder.length,
                      itemBuilder: (context, index) {
                        final namaKategori = _kategoriFolder[index];
                        final listBayarKategori = groupedRiwayat[namaKategori] ?? [];
                        
                        double totalMasuk = 0;
                        for (var b in listBayarKategori) {
                          if ((b['status'] ?? '') == 'LUNAS') {
                            totalMasuk += (b['nominal'] is num) ? (b['nominal'] as num).toDouble() : 0;
                          }
                        }

                        final int kewajiban = _hargaTagihan[namaKategori] ?? 0;
                        final int sisa = (kewajiban - totalMasuk.toInt()) > 0 ? (kewajiban - totalMasuk.toInt()) : 0;
                        final bool isLunas = sisa == 0 && totalMasuk > 0;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isLunas ? Colors.green.shade400 : Colors.grey.shade300,
                              width: isLunas ? 1.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _bukaDialogHistoriTagihan(
                              namaKategori,
                              listBayarKategori,
                              totalMasuk.toInt(),
                              kewajiban,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isLunas ? Colors.green.shade100 : Colors.orange.shade100,
                                    child: Icon(
                                      isLunas ? Icons.check_circle : Icons.warning_amber_rounded,
                                      color: isLunas ? Colors.green.shade800 : Colors.orange.shade800,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          namaKategori,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isLunas
                                              ? 'LUNAS SEPENUHNYA'
                                              : (totalMasuk > 0
                                                  ? 'BELUM LUNAS (Sisa: ${formatter.format(sisa)})'
                                                  : 'BELUM ADA PEMBAYARAN'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isLunas ? Colors.green.shade700 : Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
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