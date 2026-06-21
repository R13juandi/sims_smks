import 'package:flutter/material.dart';
import 'package:sims_smks/screens/manajemen_jadwal_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import 'rekap_nilai_admin_screen.dart';
import 'tambah_user_screen.dart';
import 'manajemen_user_screen.dart';
import 'seeder_database_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _currentIndex = 0;

  // State Data Analitik Eksekutif
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
      final usersRes = await _supabase.from('profiles').select('*');
      _allUsers = List<Map<String, dynamic>>.from(usersRes);

      _totalSiswa = _allUsers.where((u) => u['role'] == 'siswa').length;
      _totalGuru = _allUsers.where((u) => u['role'] == 'guru').length;

      final formatTanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // 🔥 Pastikan mengambil nisn juga untuk data lengkap
      final absenRes = await _supabase
          .from('absensi')
          .select('*, profiles(full_name, role, kelas, nisn)')
          .eq('tanggal', formatTanggal);

      _absensiHariIni = List<Map<String, dynamic>>.from(absenRes);

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
      debugPrint('Error load admin data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 FUNGSI UNTUK MENAMPILKAN DETAIL FOTO JIKA DI-KLIK (BISA DI-ZOOM)
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

    final List<Widget> childrenPage = [
      _buildBerandaKanalTab(),
      _buildManajemenAkunTab(),
      _buildRekapSistemTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'SIMS CONTROL PANEL',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.8,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
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
              onPressed: () async {
                await _supabase.auth.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts_rounded),
            label: 'Akun',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Rekap Sekolah',
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: MONITOR REAL-TIME (FOLDER KELAS) ====================
  Widget _buildBerandaKanalTab() {
    // 🔥 LOGIKA GROUPING DATA BERDASARKAN KELAS
    Map<String, List<Map<String, dynamic>>> groupedAbsen = {};
    for (var a in _absensiHariIni) {
      final k = a['profiles']?['kelas'] ?? 'Tanpa Kelas';
      if (!groupedAbsen.containsKey(k)) {
        groupedAbsen[k] = [];
      }
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

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Log Presensi Berdasarkan Kelas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
              Icon(Icons.folder_shared_rounded, size: 18, color: Colors.blue),
            ],
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
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.class_rounded,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        title: Text(
                          'Kelas $namaKelas',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${dataKelas.length} Siswa Absen',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        children: dataKelas.map((data) {
                          final nama = data['profiles']?['full_name'] ?? 'User';
                          final status = data['status'] ?? '-';
                          final fotoUrl = data['foto_url'];
                          final keterangan = data['keterangan'] ?? '';

                          Color warnaStatus = Colors.green;
                          if (status == 'I')
                            warnaStatus = Colors.orange;
                          else if (status == 'A')
                            warnaStatus = Colors.red;
                          else if (status == 'T')
                            warnaStatus = Colors.amber.shade700;

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
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: warnaStatus.withOpacity(
                                    0.15,
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: warnaStatus,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                      Text(
                                        'Keterangan: $keterangan',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // FOTO SELFIE ATAU IKON IZIN DI DALAM FOLDER KELAS
                                if (status == 'I')
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

  // ==================== TAB 2: MANAJEMEN AKUN (TAMBAH & KELOLA) ====================
  Widget _buildManajemenAkunTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Pusat Kontrol Akses Akun',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),

        _buildMenuButton(
          Icons.rocket_launch_rounded,
          'Mode Developer (Seeder)',
          'Isi database otomatis untuk kebutuhan demo presentasi',
          Colors.purple,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DatabaseSeederScreen(),
            ),
          ),
        ),

        _buildMenuButton(
          Icons.person_add_alt_1_rounded,
          'Registrasi Pengguna Baru',
          'Tambah data akun Siswa, Wali Murid, atau Guru baru',
          Colors.blue[800]!,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TambahUserScreen()),
          ),
        ),
        const SizedBox(height: 12),

        _buildMenuButton(
          Icons.supervised_user_circle_rounded,
          'Manajemen Database Pengguna',
          'Lihat, edit, atau hapus berkas profil pengguna terdaftar',
          const Color(0xFF0F172A),
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManajemenUserScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildMenuButton(
          Icons.calendar_month_rounded,
          'Manajemen Jadwal Pelajaran',
          'Atur dan susun jadwal pelajaran harian siswa & guru',
          Colors.indigo,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManajemenJadwalScreen(),
            ),
          ),
        ),
        const SizedBox(
          height: 12,
        ), // <--- Tanda koma ini yang tadi membuat error
        // 🔥 TOMBOL MENU BARU UNTUK SUPER REKAP NILAI ADMIN
        _buildMenuButton(
          Icons.grade_rounded,
          'Super Manajemen Nilai',
          'Pantau, edit paksa, atau hapus input nilai dari seluruh guru',
          Colors.orange.shade700,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RekapNilaiAdminScreen(),
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

  // ==================== TAB 3: REKAP GRAFIK & STATISTIK ADMIN ====================
  Widget _buildRekapSistemTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Statistik Kehadiran Sekolah Hari Ini',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),

        _buildProgressBarEksekutif(
          'Hadir / Tepat Waktu',
          _jumlahHadir,
          Colors.green,
        ),
        _buildProgressBarEksekutif(
          'Izin Keterangan',
          _jumlahIzin,
          Colors.orange,
        ),
        _buildProgressBarEksekutif('Sakit Berkas', _jumlahSakit, Colors.blue),
        _buildProgressBarEksekutif(
          'Alpa / Tanpa Keterangan',
          _jumlahAlpa,
          Colors.red,
        ),

        const SizedBox(height: 20),

        // 🔥 TOMBOL SUPER REKAP ADMIN MENUJU HALAMAN DETAIL SEMUA SISWA
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RekapAbsensiAdminScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          icon: const Icon(Icons.analytics_rounded),
          label: const Text(
            'LIHAT DETAIL REKAP SELURUH SEKOLAH',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF1E40AF),
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Data rekapitulasi di atas dihitung secara otomatis berdasarkan log masuk harian absensi GPS & Kamera Wajah biometrik seluruh siswa.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E40AF),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBarEksekutif(String label, int count, Color color) {
    double persentase = _absensiHariIni.isEmpty
        ? 0.0
        : count / _absensiHariIni.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
                '$count Jiwa (${(persentase * 100).toStringAsFixed(0)}%)',
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
}

// ====================================================================================
// 🔥 HALAMAN SUPER REKAP KHUSUS ADMIN (MENAMPILKAN SEMUA SISWA & SEMUA GURU & FOTO)
// ====================================================================================
class RekapAbsensiAdminScreen extends StatefulWidget {
  const RekapAbsensiAdminScreen({super.key});

  @override
  State<RekapAbsensiAdminScreen> createState() =>
      _RekapAbsensiAdminScreenState();
}

class _RekapAbsensiAdminScreenState extends State<RekapAbsensiAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _dataAbsen = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchRekapSeluruhSekolah();
  }

  Future<void> _fetchRekapSeluruhSekolah() async {
    setState(() => _isLoading = true);
    try {
      final tanggalFilter = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Mengambil SEMUA data absensi tanpa filter guru
      final res = await _supabase
          .from('absensi')
          .select('*, profiles!inner(full_name, nisn)')
          .eq('tanggal', tanggalFilter)
          .order('kelas', ascending: true); // Urutkan berdasarkan kelas

      if (mounted) {
        setState(() {
          _dataAbsen = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error rekap admin: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchRekapSeluruhSekolah();
    }
  }

  // Fungsi Zoom Foto untuk Admin
  void _tampilkanDetailFotoAdmin(
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Rekap Keseluruhan Sekolah',
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
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pilihTanggal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Ganti'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dataAbsen.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada data absensi di tanggal ini.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _dataAbsen.length,
                    itemBuilder: (context, index) {
                      final a = _dataAbsen[index];
                      final p = a['profiles'] ?? {};
                      final String? fotoUrl = a['foto_url'];
                      final String namaMurid =
                          p['full_name'] ?? 'Nama Tidak Dikenal';

                      String statusText = 'Hadir';
                      Color warnaStatus = Colors.green;
                      String kodeTampil = a['status'] ?? 'H';

                      if (a['status'] == 'I') {
                        statusText = 'Izin';
                        warnaStatus = Colors.orange;
                      } else if (a['status'] == 'A') {
                        statusText = 'Alfa';
                        warnaStatus = Colors.red;
                      } else if (a['status'] == 'T') {
                        statusText = 'Terlambat';
                        warnaStatus = Colors.amber.shade700;
                      }

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: warnaStatus.withOpacity(0.15),
                                child: Text(
                                  kodeTampil,
                                  style: TextStyle(
                                    color: warnaStatus,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                namaMurid,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                'NISN: ${p['nisn'] ?? '-'}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        if (a['status'] == 'I')
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.edit_document,
                                              color: Colors.orange,
                                            ),
                                          )
                                        else if (fotoUrl != null &&
                                            fotoUrl.isNotEmpty)
                                          GestureDetector(
                                            onTap: () =>
                                                _tampilkanDetailFotoAdmin(
                                                  context,
                                                  fotoUrl,
                                                  namaMurid,
                                                ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.blue.shade200,
                                                    width: 1.5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Image.network(
                                                  fotoUrl,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Container(
                                                        width: 50,
                                                        height: 50,
                                                        color:
                                                            Colors.red.shade50,
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.red,
                                                          size: 20,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    Text(
                                      '🏫 Kelas : ${a['kelas'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.indigo,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '👨‍🏫 Guru : ${a['guru_pengampu'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📚 Mapel: ${a['mapel'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '📌 Status: $statusText\n📝 Keterangan: ${a['keterangan']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
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
