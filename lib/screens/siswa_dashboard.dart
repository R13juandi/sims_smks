import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import 'absensi_siswa_screen.dart'; // Pastikan file ini sudah ada
import 'rekap_absensi_siswa_screen.dart'; // Pastikan file ini sudah ada
import 'nilai_rapor_screen.dart'; // Pastikan file ini sudah ada

class SiswaDashboard extends StatefulWidget {
  const SiswaDashboard({super.key});

  @override
  State<SiswaDashboard> createState() => _SiswaDashboardState();
}

class _SiswaDashboardState extends State<SiswaDashboard>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  Map<String, dynamic> _biodataSiswa = {};
  List<Map<String, dynamic>> _allJadwal = [];
  List<Map<String, dynamic>> _jadwalHariIni = [];

  @override
  void initState() {
    super.initState();
    _loadSiswaData();
  }

  String _getNamaHariIni() {
    final now = DateTime.now();
    switch (now.weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      default:
        return 'Minggu';
    }
  }

  Future<void> _loadSiswaData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Ambil Biodata Siswa
      final profileRes = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (profileRes != null) {
        _biodataSiswa = profileRes;
      }

      // 2. Ambil Jadwal dari tabel 'jadwal'
      final jadwalRes = await _supabase
          .from('jadwal')
          .select('*')
          .order('jam_mulai', ascending: true);

      final listJadwal = List<Map<String, dynamic>>.from(jadwalRes);

      String kelasSiswa = (_biodataSiswa['kelas'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      // 3. Filter Jadwal Hanya Untuk Kelas Siswa Ini
      _allJadwal = listJadwal.where((j) {
        String kelasJadwal = (j['kelas'] ?? '').toString().toLowerCase().trim();

        if (kelasJadwal == kelasSiswa) return true;

        if (kelasSiswa.contains('10') || kelasSiswa.contains('x ')) {
          return kelasJadwal.contains('10') || kelasJadwal.contains('x');
        } else if (kelasSiswa.contains('11') || kelasSiswa.contains('xi')) {
          return kelasJadwal.contains('11') || kelasJadwal.contains('xi');
        } else if (kelasSiswa.contains('12') || kelasSiswa.contains('xii')) {
          return kelasJadwal.contains('12') || kelasJadwal.contains('xii');
        }
        return false;
      }).toList();

      // 4. Saring jadwal spesifik untuk HARI INI
      final hariIni = _getNamaHariIni();
      _jadwalHariIni = _allJadwal.where((j) => j['hari'] == hariIni).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading data: $e');
    }
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

    final hariIni = _getNamaHariIni();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'SIMS SMK TI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: false,
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
                Icons.logout_rounded,
                color: Colors.red[600],
                size: 20,
              ),
              tooltip: 'Keluar Aplikasi',
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
      // 🔥 BODY UTAMA DIBUAT MENJADI SATU LISTVIEW (TANPA BOTTOM NAV)
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ====================================================================
          // 1. KOTAK BIRU HEADER (KLIK UNTUK KE DETAIL PROFIL)
          // ====================================================================
          Card(
            elevation: 8,
            shadowColor: const Color(0xFF1E3A8A).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                // Berpindah ke Halaman Detail Profil Siswa
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DetailProfilSiswaScreen(biodata: _biodataSiswa),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selamat Datang Kembali,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _biodataSiswa['full_name'] ?? 'Siswa',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'Kelas ${_biodataSiswa['kelas'] ?? '-'}  •  NISN ${_biodataSiswa['nisn'] ?? '-'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ====================================================================
          // 2. GRID MENU AKADEMIK (TERMASUK JADWAL DAN RAPOR)
          // ====================================================================
          const Text(
            'Menu Akademik',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.15,
            children: [
              _buildMenuCard(
                icon: Icons.camera_front_rounded,
                color: const Color(0xFFEF4444), // Merah
                title: 'Presensi\n& Scan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AbsensiSiswaScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                icon: Icons.folder_shared_rounded,
                color: const Color(0xFF10B981), // Hijau
                title: 'Rekap\nAbsensi',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RekapAbsensiSiswaScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                icon: Icons.calendar_month_rounded,
                color: Colors.orange.shade600, // Oranye
                title: 'Jadwal\nPelajaran',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        JadwalSemingguSiswaScreen(allJadwal: _allJadwal),
                  ),
                ),
              ),
              _buildMenuCard(
                icon: Icons.analytics_rounded,
                color: const Color(0xFF3B82F6), // Biru
                title: 'Rapor\nSemester',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NilaiRaporScreen(
                      siswaId: _supabase.auth.currentUser?.id ?? '',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ====================================================================
          // 3. JADWAL HARI INI
          // ====================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Jadwal Hari Ini ($hariIni)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _jadwalHariIni.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Tidak ada jadwal pelajaran aktif hari ini.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _jadwalHariIni.length,
                  itemBuilder: (context, index) {
                    final j = _jadwalHariIni[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.import_contacts_rounded,
                              color: Color(0xFF3B82F6),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  j['mata_pelajaran'] ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sesi: ${j['sesi'] ?? '-'}  •  ${j['guru_pengampu'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Komponen Pembuat Grid Menu Akademik
  Widget _buildMenuCard({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black.withOpacity(0.02),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================================
// 🔥 HALAMAN BARU: JADWAL PELAJARAN SEMINGGU (DIPINDAH DARI TAB BAWAH)
// ====================================================================================
class JadwalSemingguSiswaScreen extends StatelessWidget {
  final List<Map<String, dynamic>> allJadwal;

  const JadwalSemingguSiswaScreen({super.key, required this.allJadwal});

  String _getNamaHariIni() {
    final now = DateTime.now();
    switch (now.weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      default:
        return 'Minggu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> listHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'];
    final hariIni = _getNamaHariIni();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Jadwal Pelajaran Mingguan',
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
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: listHari.length,
        itemBuilder: (context, index) {
          final hari = listHari[index];
          final jadwals = allJadwal.where((j) => j['hari'] == hari).toList();
          final bool isHariIni = hari == hariIni;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isHariIni
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFF1F5F9),
                width: isHariIni ? 1.5 : 1,
              ),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isHariIni,
                leading: Icon(
                  Icons.circle,
                  size: 10,
                  color: isHariIni
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFCBD5E1),
                ),
                title: Text(
                  hari,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isHariIni
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF1E293B),
                  ),
                ),
                children: [
                  if (jadwals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Tidak ada jadwal pelajaran',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ...jadwals.map((j) {
                      return Container(
                        margin: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 12,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    j['mata_pelajaran'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sesi: ${j['sesi'] ?? '-'}  •  ${j['guru_pengampu'] ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ====================================================================================
// 🔥 HALAMAN BARU: DETAIL PROFIL LENGKAP SISWA (KLIK DARI HEADER)
// ====================================================================================
class DetailProfilSiswaScreen extends StatelessWidget {
  final Map<String, dynamic> biodata;
  const DetailProfilSiswaScreen({super.key, required this.biodata});

  @override
  Widget build(BuildContext context) {
    // Formatting Tanggal Lahir jika diperlukan
    String tglLahirFormatted = '-';
    if (biodata['tanggal_lahir'] != null) {
      try {
        DateTime tgl = DateTime.parse(biodata['tanggal_lahir']);
        tglLahirFormatted = DateFormat('dd MMMM yyyy').format(tgl);
      } catch (_) {}
    }

    // Pemetaan data biodata dengan fallback aman jika null ('-')
    final String nama = biodata['full_name'] ?? 'Siswa';
    final String kelas = biodata['kelas'] ?? '-';
    final String nisn = biodata['nisn'] ?? '-';
    final String nipd = biodata['nipd'] ?? '-';
    final String nik = biodata['nik'] ?? '-';
    final String noKk = biodata['no_kk'] ?? '-';
    final String jk = biodata['jk'] ?? biodata['jenis_kelamin'] ?? '-';
    final String agama = biodata['agama'] ?? '-';
    final String noHp = biodata['no_hp'] ?? biodata['nomor_hp'] ?? '-';
    final String domisili =
        biodata['alamat'] ?? biodata['alamat_domisili'] ?? '-';
    final String tempatLahir = biodata['tempat_lahir'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Profil Data Diri Siswa',
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ================= FOTO & NAMA UTAMA =================
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 45,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nama,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: Siswa Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ================= BLOK 1: INFORMASI DATA AKADEMIK =================
          const Text(
            'INFORMASI DATA AKADEMIK',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E40AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemProfil(Icons.school_rounded, 'Kelas Aktif', kelas),
                const Divider(height: 24),
                _itemProfil(
                  Icons.badge_rounded,
                  'NIPD (Nomor Induk Peserta Didik)',
                  nipd,
                ),
                const Divider(height: 24),
                _itemProfil(
                  Icons.fingerprint_rounded,
                  'NISN (Nomor Induk Siswa Nasional)',
                  nisn,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ================= BLOK 2: BIODATA DIRI LENGKAP =================
          const Text(
            'BIODATA DIRI LENGKAP',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E40AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemProfil(
                  Icons.credit_card_rounded,
                  'NIK (Nomor Induk Kependudukan)',
                  nik,
                ),
                const Divider(height: 24),

                if (tempatLahir.trim().isNotEmpty) ...[
                  _itemProfil(
                    Icons.cake_rounded,
                    'Tempat, Tanggal Lahir',
                    '$tempatLahir, $tglLahirFormatted',
                  ),
                  const Divider(height: 24),
                ],

                _itemProfil(Icons.wc_rounded, 'Jenis Kelamin', jk),
                const Divider(height: 24),
                _itemProfil(Icons.mosque_rounded, 'Agama', agama),
                const Divider(height: 24),
                _itemProfil(
                  Icons.phone_android_rounded,
                  'Nomor Handphone Aktif',
                  noHp,
                ),
                const Divider(height: 24),
                _itemProfil(
                  Icons.home_rounded,
                  'Alamat Domisili / Tempat Tinggal',
                  domisili,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Desain baris item profil yang konsisten
  Widget _itemProfil(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value ?? '-',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
