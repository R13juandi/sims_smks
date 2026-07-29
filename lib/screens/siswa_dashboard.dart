import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/popup_service.dart';
import '../login_screen.dart';
import 'absensi_siswa_screen.dart';
import 'nilai_rapor_screen.dart';
import 'siswa_administrasi_screen.dart';

class SiswaDashboard extends StatefulWidget {
  const SiswaDashboard({super.key});

  @override
  State<SiswaDashboard> createState() => _SiswaDashboardState();
}

class _SiswaDashboardState extends State<SiswaDashboard>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;

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
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return hari[now.weekday - 1];
  }

  bool _kelasCocok(String kelasJadwal, String kelasSiswa) {
    final kj = kelasJadwal.toLowerCase().trim();
    final ks = kelasSiswa.toLowerCase().trim();
    if (kj.isEmpty || ks.isEmpty) return false;
    if (kj == ks) return true;

    bool cekTingkat(String s, List<String> keys) =>
        keys.any((k) => s.contains(k));

    if (cekTingkat(ks, ['10', 'x '])) return cekTingkat(kj, ['10', 'x ']);
    if (cekTingkat(ks, ['11', 'xi'])) return cekTingkat(kj, ['11', 'xi']);
    if (cekTingkat(ks, ['12', 'xii'])) return cekTingkat(kj, ['12', 'xii']);
    return false;
  }

  Future<void> _loadSiswaData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi login tidak ditemukan.';
        });
        return;
      }

      final profileRes = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      _biodataSiswa = profileRes ?? {};

      final jadwalRes = await _supabase
          .from('jadwal')
          .select('*')
          .order('jam_mulai', ascending: true);

      final listJadwal = List<Map<String, dynamic>>.from(jadwalRes as List);
      final kelasSiswa = (_biodataSiswa['kelas'] ?? '').toString();

      _allJadwal = listJadwal.where((j) {
        final kelasJadwal = (j['kelas'] ?? '').toString();
        return _kelasCocok(kelasJadwal, kelasSiswa);
      }).toList();

      final hariIni = _getNamaHariIni();
      _jadwalHariIni = _allJadwal
          .where((j) => (j['hari'] ?? '') == hariIni)
          .toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error _loadSiswaData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data. Periksa koneksi internet Anda.';
        });
        PopupService.show(
          context,
          'Gagal memuat data dashboard: $e',
          isSuccess: false,
          judul: 'Koneksi Bermasalah',
        );
      }
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

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadSiswaData,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hariIni = _getNamaHariIni();
    final namaLengkap = (_biodataSiswa['full_name'] ?? 'Siswa').toString();
    final kelas = (_biodataSiswa['kelas'] ?? '-').toString();
    final nisn = (_biodataSiswa['nisn'] ?? '-').toString();

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
              onPressed: () {
                PopupService.showConfirm(
                  context,
                  'Apakah Anda yakin ingin keluar dari akun Siswa ini?',
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
      body: RefreshIndicator(
        onRefresh: _loadSiswaData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Card(
              elevation: 8,
              shadowColor: const Color(0xFF1E3A8A).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DetailProfilSiswaScreen(biodata: _biodataSiswa),
                  ),
                ),
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
                              namaLengkap,
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
                                'Kelas $kelas  •  NISN $nisn',
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
                  color: const Color(0xFFEF4444),
                  title: 'Presensi\n& Rekap',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AbsensiSiswaScreen(),
                    ),
                  ),
                ),
                _buildMenuCard(
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFF3B82F6),
                  title: 'Rapor\nSemester',
                  onTap: () {
                    final uid = _supabase.auth.currentUser?.id;
                    if (uid == null) {
                      PopupService.show(
                        context,
                        'Sesi login tidak ditemukan.',
                        isSuccess: false,
                        judul: 'Akses Gagal',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NilaiRaporScreen(siswaId: uid),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.teal.shade600,
                  title: 'Tagihan\n& SPP',
                  onTap: () {
                    final uid = _supabase.auth.currentUser?.id;
                    if (uid == null) {
                      PopupService.show(
                        context,
                        'Sesi login tidak ditemukan.',
                        isSuccess: false,
                        judul: 'Akses Gagal',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SiswaAdministrasiScreen(siswaId: uid),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  icon: Icons.calendar_month_rounded,
                  color: Colors.orange.shade600,
                  title: 'Jadwal\nPelajaran',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          JadwalSemingguSiswaScreen(allJadwal: _allJadwal),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Jadwal Hari Ini ($hariIni)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
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
                      final jamMulaiRaw =
                          (j['jam_mulai'] ?? '00:00').toString();
                      final jamSelesaiRaw =
                          (j['jam_selesai'] ?? '00:00').toString();
                      final jamMulai = jamMulaiRaw.length >= 5
                          ? jamMulaiRaw.substring(0, 5)
                          : jamMulaiRaw;
                      final jamSelesai = jamSelesaiRaw.length >= 5
                          ? jamSelesaiRaw.substring(0, 5)
                          : jamSelesaiRaw;
                      final guru =
                          (j['guru_pengampu'] ?? j['guru'] ?? '-').toString();

                      final mapel =
                          (j['mata_pelajaran'] ?? j['mapel'] ?? '-')
                              .toString()
                              .toUpperCase();
                      final ruang =
                          (j['ruang_kelas'] ?? 'Lt. 2 - R. 05').toString();

                      final isIstirahat =
                          mapel.contains('ISTIRAHAT') ||
                          mapel.contains('ISHOMA');

                      if (isIstirahat) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.fastfood,
                                  color: Colors.orange.shade800,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mapel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Waktu Istirahat: $jamMulai - $jamSelesai WIB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                    mapel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          guru,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.room_outlined,
                                        size: 14,
                                        color: Colors.teal.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ruang: $ruang',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.teal.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '⏰ Waktu: $jamMulai - $jamSelesai WIB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

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

// =========================================================================
// 🔥 REVISI PAK HALIM: JADWAL SEMINGGU DENGAN 3-TIER SUPER FALLBACK QUERY
// =========================================================================
class JadwalSemingguSiswaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allJadwal;
  const JadwalSemingguSiswaScreen({super.key, required this.allJadwal});

  @override
  State<JadwalSemingguSiswaScreen> createState() =>
      _JadwalSemingguSiswaScreenState();
}

class _JadwalSemingguSiswaScreenState
    extends State<JadwalSemingguSiswaScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic> _biodataSiswa = {};
  List<Map<String, dynamic>> _jadwalTerpilih = [];

  String _selectedPeriode = 'Aktif';
  List<Map<String, String>> _daftarPeriodeHistori = [];
  final List<String> _listHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  @override
  void initState() {
    super.initState();
    _initDataJadwalSiswa();
  }

  Future<void> _initDataJadwalSiswa() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'Sesi login habis.';

      final prof = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();
      _biodataSiswa = prof;

      String kelasSekarang = (prof['kelas'] ?? 'X TKJ').toString();
      _generateDaftarPeriode(kelasSekarang);

      await _fetchJadwalByPeriode(_daftarPeriodeHistori.first);
    } catch (e) {
      debugPrint('Error init jadwal siswa: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(
          context,
          'Gagal memuat jadwal pelajaran: $e',
          isSuccess: false,
          judul: 'Terjadi Kesalahan',
        );
      }
    }
  }

  void _generateDaftarPeriode(String kelasAktif) {
    List<Map<String, String>> periode = [];
    String jurusan =
        kelasAktif.replaceAll(RegExp(r'^(X|XI|XII|10|11|12)\s*'), '').trim();
    if (jurusan.isEmpty) jurusan = 'TKJ';

    if (kelasAktif.startsWith('XII') || kelasAktif.startsWith('12')) {
      periode = [
        {
          'label': 'XII $jurusan - Sem. Ganjil (Aktif)',
          'kelas': 'XII $jurusan',
          'semester': 'Ganjil',
          'is_aktif': 'true',
        },
        {
          'label': 'XI $jurusan - Sem. Genap (Histori)',
          'kelas': 'XI $jurusan',
          'semester': 'Genap',
          'is_aktif': 'false',
        },
        {
          'label': 'XI $jurusan - Sem. Ganjil (Histori)',
          'kelas': 'XI $jurusan',
          'semester': 'Ganjil',
          'is_aktif': 'false',
        },
        {
          'label': 'X $jurusan - Sem. Genap (Histori)',
          'kelas': 'X $jurusan',
          'semester': 'Genap',
          'is_aktif': 'false',
        },
        {
          'label': 'X $jurusan - Sem. Ganjil (Histori)',
          'kelas': 'X $jurusan',
          'semester': 'Ganjil',
          'is_aktif': 'false',
        },
      ];
    } else if (kelasAktif.startsWith('XI') || kelasAktif.startsWith('11')) {
      periode = [
        {
          'label': 'XI $jurusan - Sem. Ganjil (Aktif)',
          'kelas': 'XI $jurusan',
          'semester': 'Ganjil',
          'is_aktif': 'true',
        },
        {
          'label': 'X $jurusan - Sem. Genap (Histori)',
          'kelas': 'X $jurusan',
          'semester': 'Genap',
          'is_aktif': 'false',
        },
        {
          'label': 'X $jurusan - Sem. Ganjil (Histori)',
          'kelas': 'X $jurusan',
          'semester': 'Ganjil',
          'is_aktif': 'false',
        },
      ];
    } else {
      periode = [
        {
          'label': 'X $jurusan - Sem. Ganjil (Aktif)',
          'kelas': 'X $jurusan',
          'semester': 'Ganjil',
          'is_aktif': 'true',
        },
      ];
    }

    setState(() {
      _daftarPeriodeHistori = periode;
      _selectedPeriode = periode.first['label']!;
    });
  }

  // 🔥 3-TIER SUPER FALLBACK QUERY
  Future<void> _fetchJadwalByPeriode(Map<String, String> targetPeriode) async {
    setState(() => _isLoading = true);
    try {
      String targetKelas = targetPeriode['kelas']!;
      String targetSemester = targetPeriode['semester']!;
      bool isAktif = targetPeriode['is_aktif'] == 'true';

      if (isAktif && widget.allJadwal.isNotEmpty) {
        setState(() {
          _jadwalTerpilih = widget.allJadwal;
          _isLoading = false;
        });
        return;
      }

      final resTier1 = await _supabase
          .from('jadwal')
          .select('*')
          .ilike('kelas', '%$targetKelas%')
          .ilike('semester', '%$targetSemester%')
          .order('jam_mulai', ascending: true);

      List<Map<String, dynamic>> hasil =
          List<Map<String, dynamic>>.from(resTier1 as List);

      if (hasil.isEmpty) {
        final resTier2 = await _supabase
            .from('jadwal')
            .select('*')
            .ilike('kelas', '%$targetKelas%')
            .order('jam_mulai', ascending: true);
        hasil = List<Map<String, dynamic>>.from(resTier2 as List);
      }

      if (hasil.isEmpty) {
        String levelPrefix = targetKelas.split(' ').first;
        final resTier3 = await _supabase
            .from('jadwal')
            .select('*')
            .ilike('kelas', '$levelPrefix%')
            .order('jam_mulai', ascending: true);
        hasil = List<Map<String, dynamic>>.from(resTier3 as List);
      }

      if (mounted) {
        setState(() {
          _jadwalTerpilih = hasil;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch histori jadwal: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getNamaHariIni() {
    final now = DateTime.now();
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return hari[now.weekday - 1];
  }

  void _showDialogHistoriJadwal() {
    String kelasSiswa = (_biodataSiswa['kelas'] ?? '').toString();
    bool isKelas10 = kelasSiswa.startsWith('X ') || kelasSiswa.startsWith('10');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.history_edu_rounded,
                color: Color(0xFF1E40AF),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Pilih Periode Jadwal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: isKelas10
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade800,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada histori jadwal pelajaran karena Anda saat ini masih berada di Kelas 10 Semester 1.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _daftarPeriodeHistori.length,
                    itemBuilder: (context, index) {
                      final item = _daftarPeriodeHistori[index];
                      final bool isSelected = _selectedPeriode == item['label'];
                      final bool isAktif = item['is_aktif'] == 'true';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF1E40AF)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        color: isSelected ? Colors.blue.shade50 : Colors.white,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isAktif
                                ? Icons.calendar_month_rounded
                                : Icons.history_rounded,
                            color: isSelected
                                ? const Color(0xFF1E40AF)
                                : Colors.grey,
                          ),
                          title: Text(
                            item['label']!,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 13,
                              color: isSelected
                                  ? const Color(0xFF1E40AF)
                                  : Colors.black87,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF1E40AF),
                                  size: 20,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            if (!isSelected) {
                              setState(() => _selectedPeriode = item['label']!);
                              _fetchJadwalByPeriode(item);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Tutup',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hariIni = _getNamaHariIni();
    bool isHistoriView = !_selectedPeriode.contains('(Aktif)');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jadwal Pelajaran Mingguan',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _selectedPeriode,
              style: TextStyle(
                fontSize: 11,
                color: isHistoriView
                    ? Colors.orange.shade800
                    : Colors.blue.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ActionChip(
              onPressed: _showDialogHistoriJadwal,
              avatar: Icon(
                isHistoriView
                    ? Icons.history_rounded
                    : Icons.filter_list_rounded,
                size: 16,
                color: const Color(0xFF1E40AF),
              ),
              label: const Text(
                'Histori',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
                ),
              ),
              backgroundColor: Colors.blue.shade50,
              side: BorderSide(color: Colors.blue.shade200),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
            )
          : _jadwalTerpilih.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Data jadwal pelajaran untuk periode\n"$_selectedPeriode"\nbelum diinputkan oleh Admin / Tata Usaha ke dalam database.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _listHari.length,
                  itemBuilder: (context, index) {
                    final hari = _listHari[index];
                    final jadwals = _jadwalTerpilih
                        .where((j) => (j['hari'] ?? '') == hari)
                        .toList();
                    final bool isHariIni = hari == hariIni && !isHistoriView;

                    if (jadwals.isEmpty && !isHariIni) {
                      return const SizedBox.shrink();
                    }

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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: isHariIni || jadwals.isNotEmpty,
                          leading: Icon(
                            Icons.circle,
                            size: 12,
                            color: isHariIni
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFCBD5E1),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hari,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isHariIni
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              if (isHariIni)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'HARI INI',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                            ],
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
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ...jadwals.map((j) {
                                final jamMulaiRaw =
                                    (j['jam_mulai'] ?? '00:00').toString();
                                final jamSelesaiRaw =
                                    (j['jam_selesai'] ?? '00:00').toString();
                                final jamMulai = jamMulaiRaw.length >= 5
                                    ? jamMulaiRaw.substring(0, 5)
                                    : jamMulaiRaw;
                                final jamSelesai = jamSelesaiRaw.length >= 5
                                    ? jamSelesaiRaw.substring(0, 5)
                                    : jamSelesaiRaw;
                                final guru =
                                    (j['guru_pengampu'] ?? j['guru'] ?? '-')
                                        .toString();

                                final mapel =
                                    (j['mata_pelajaran'] ?? j['mapel'] ?? '-')
                                        .toString()
                                        .toUpperCase();
                                final ruang =
                                    (j['ruang_kelas'] ?? 'Lt. 2 - R. 05')
                                        .toString();

                                final isIstirahat =
                                    mapel.contains('ISTIRAHAT') ||
                                    mapel.contains('ISHOMA');

                                return Container(
                                  margin: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isIstirahat
                                        ? Colors.orange.shade50
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isIstirahat
                                          ? Colors.orange.shade200
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isIstirahat
                                              ? Colors.orange.shade100
                                              : const Color(0xFFDBEAFE),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isIstirahat
                                              ? Icons.fastfood
                                              : Icons.menu_book_rounded,
                                          color: isIstirahat
                                              ? Colors.orange.shade800
                                              : const Color(0xFF1E40AF),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              mapel,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isIstirahat
                                                    ? Colors.orange.shade900
                                                    : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            if (!isIstirahat) ...[
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.person_outline_rounded,
                                                    size: 14,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      guru,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Color(0xFF64748B),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.room_outlined,
                                                    size: 14,
                                                    color: Colors.teal.shade700,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Ruang: $ruang',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.teal.shade800,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                            Text(
                                              '⏰ Waktu: $jamMulai - $jamSelesai WIB',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isIstirahat
                                                    ? Colors.orange.shade800
                                                    : Colors.blue.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class DetailProfilSiswaScreen extends StatelessWidget {
  final Map<String, dynamic> biodata;
  const DetailProfilSiswaScreen({super.key, required this.biodata});

  @override
  Widget build(BuildContext context) {
    String tglLahirFormatted = '-';
    final rawTgl = biodata['tanggal_lahir'];
    if (rawTgl != null && rawTgl.toString().isNotEmpty) {
      try {
        final tgl = DateTime.parse(rawTgl.toString());
        const bulan = [
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
        tglLahirFormatted = '${tgl.day} ${bulan[tgl.month - 1]} ${tgl.year}';
      } catch (_) {
        tglLahirFormatted = '-';
      }
    }

    final nama = (biodata['full_name'] ?? 'Siswa').toString();
    final kelas = (biodata['kelas'] ?? '-').toString();
    final nisn = (biodata['nisn'] ?? '-').toString();
    final nipd = (biodata['nipd'] ?? '-').toString();
    final nik = (biodata['nik'] ?? '-').toString();
    final jk = (biodata['jk'] ?? biodata['jenis_kelamin'] ?? '-').toString();
    final agama = (biodata['agama'] ?? '-').toString();
    final noHp = (biodata['no_hp'] ?? biodata['nomor_hp'] ?? '-').toString();
    final domisili =
        (biodata['alamat'] ?? biodata['alamat_domisili'] ?? '-').toString();
    final tempatLahir = (biodata['tempat_lahir'] ?? '').toString();

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
                (value == null || value.isEmpty) ? '-' : value,
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