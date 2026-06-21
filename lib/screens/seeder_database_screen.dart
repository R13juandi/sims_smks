import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../login_screen.dart'; // Sesuaikan jika path file login kamu berbeda

class DatabaseSeederScreen extends StatefulWidget {
  const DatabaseSeederScreen({super.key});

  @override
  State<DatabaseSeederScreen> createState() => _DatabaseSeederScreenState();
}

class _DatabaseSeederScreenState extends State<DatabaseSeederScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  double _progress = 0;
  String _status = "Siap untuk menyuntikkan data ke Supabase...";

  // ================= DATA ASLI DARI EXCEL =================
  final List<Map<String, dynamic>> _siswaList = [
    {
      'nama': 'Adam Ghifari',
      'email': 'siswa10@sekolah.com',
      'kelas': 'X TKJ',
      'nisn': '0096379729',
      'nik': '3671040111090003',
      'jk': 'L',
    },
    {
      'nama': 'AIDAH NUR FAUZIAH',
      'email': 'siswa10_2@sekolah.com',
      'kelas': 'X TKJ',
      'nisn': '0098520817',
      'nik': '3671015608090006',
      'jk': 'P',
    },
    {
      'nama': 'AISYAH HANA DAINI',
      'email': 'siswa10_3@sekolah.com',
      'kelas': 'X TKJ',
      'nisn': '0095347351',
      'nik': '3671015006090001',
      'jk': 'P',
    },
    {
      'nama': 'ANGGI SEPTI RAHMADIANI',
      'email': 'siswa11@sekolah.com',
      'kelas': 'XI TKJ',
      'nisn': '03085078265',
      'nik': '3173064609080009',
      'jk': 'P',
    },
    {
      'nama': 'DIANITA CAHYANI',
      'email': 'siswa11_2@sekolah.com',
      'kelas': 'XI TKJ',
      'nisn': '081855384',
      'nik': '3303085707080005',
      'jk': 'P',
    },
    {
      'nama': 'FERA WATI',
      'email': 'siswa11_3@sekolah.com',
      'kelas': 'XI TKJ',
      'nisn': '085963211',
      'nik': '3671045511080003',
      'jk': 'P',
    },
    {
      'nama': 'Amelia Nurcahyani',
      'email': 'siswa12@sekolah.com',
      'kelas': 'XII TKJ',
      'nisn': '087425627',
      'nik': '3671036901080003',
      'jk': 'P',
    },
    {
      'nama': 'AMELIA PUTRI',
      'email': 'siswa12_2@sekolah.com',
      'kelas': 'XII TKJ',
      'nisn': '03094970691',
      'nik': '3671045701080005',
      'jk': 'P',
    },
    {
      'nama': 'ANJANI DWI RAHMADANI',
      'email': 'siswa12_3@sekolah.com',
      'kelas': 'XII TKJ',
      'nisn': '071407868',
      'nik': '3671034910070002',
      'jk': 'P',
    },
  ];

  final List<Map<String, dynamic>> _guruList = [
    {
      'nama': 'AGUS RAHMADANI, SE',
      'email': 'guru0@sekolah.com',
      'mapel': 'PROJECT IPAS',
    },
    {
      'nama': 'Drs. TOLHATTA',
      'email': 'guru5@sekolah.com',
      'mapel': 'PAI dan Budi Pekerti',
    },
    {
      'nama': 'H.HELMI ROSYADI,SH',
      'email': 'guru6@sekolah.com',
      'mapel': 'PPKN',
    },
    {
      'nama': 'ROSYADAH,S.PdI',
      'email': 'guru7@sekolah.com',
      'mapel': 'BAHASA INDONESIA',
    },
    {
      'nama': 'ISMATULLAH, S.Ag',
      'email': 'guru8@sekolah.com',
      'mapel': 'BAHASA INGGRIS',
    },
    {
      'nama': 'MUHAMMAD RIZQI DJUWANDI',
      'email': 'guru9@sekolah.com',
      'mapel': 'MATEMATIKA',
    },
  ];

  final List<Map<String, dynamic>> _jadwalList = [
    {
      'hari': 'Senin',
      'kelas': 'X TKJ',
      'mata_pelajaran': 'PROJECT IPAS',
      'jam_mulai': '07:30',
      'jam_selesai': '09:00',
      'guru_pengampu': 'AGUS RAHMADANI, SE',
      'sesi': '1',
    },
    {
      'hari': 'Senin',
      'kelas': 'XI TKJ',
      'mata_pelajaran': 'PAI dan Budi Pekerti',
      'jam_mulai': '07:30',
      'jam_selesai': '09:00',
      'guru_pengampu': 'Drs. TOLHATTA',
      'sesi': '1',
    },
    {
      'hari': 'Senin',
      'kelas': 'XII TKJ',
      'mata_pelajaran': 'PPKN',
      'jam_mulai': '07:30',
      'jam_selesai': '09:00',
      'guru_pengampu': 'H.HELMI ROSYADI,SH',
      'sesi': '1',
    },
    {
      'hari': 'Selasa',
      'kelas': 'X TKJ',
      'mata_pelajaran': 'BAHASA INDONESIA',
      'jam_mulai': '08:00',
      'jam_selesai': '09:30',
      'guru_pengampu': 'ROSYADAH,S.PdI',
      'sesi': '2',
    },
    {
      'hari': 'Selasa',
      'kelas': 'XI TKJ',
      'mata_pelajaran': 'BAHASA INGGRIS',
      'jam_mulai': '08:00',
      'jam_selesai': '09:30',
      'guru_pengampu': 'ISMATULLAH, S.Ag',
      'sesi': '2',
    },
    {
      'hari': 'Rabu',
      'kelas': 'XII TKJ',
      'mata_pelajaran': 'PROJECT IPAS',
      'jam_mulai': '09:30',
      'jam_selesai': '11:00',
      'guru_pengampu': 'AGUS RAHMADANI, SE',
      'sesi': '3',
    },
  ];

  Future<void> _jalankanSeeder() async {
    setState(() {
      _isLoading = true;
      _progress = 0.1;
      _status = "Sedang mendaftarkan Akun Guru...";
    });

    try {
      // 1. DAFTARKAN GURU
      for (var g in _guruList) {
        try {
          final res = await _supabase.auth.signUp(
            email: g['email']!,
            password: '12345678',
          );
          if (res.user != null) {
            await _supabase.from('profiles').upsert({
              'id': res.user!.id,
              'full_name': g['nama'],
              'email': g['email'],
              'role': 'guru',
              'kelas_mengajar': ['X TKJ', 'XI TKJ', 'XII TKJ'],
              'mapel': [g['mapel']],
              'jenis_kelamin': 'L',
              'agama': 'Islam',
            });
          }
        } catch (_) {} // Lewati jika guru sudah pernah didaftarkan
      }

      setState(() {
        _progress = 0.4;
        _status = "Sedang mendaftarkan Akun Siswa & Nilai...";
      });

      // 2. DAFTARKAN SISWA & NILAI RAPOR
      for (var s in _siswaList) {
        try {
          final res = await _supabase.auth.signUp(
            email: s['email']!,
            password: '12345678',
          );
          if (res.user != null) {
            await _supabase.from('profiles').upsert({
              'id': res.user!.id,
              'full_name': s['nama'],
              'email': s['email'],
              'role': 'siswa',
              'kelas': s['kelas'],
              'nisn': s['nisn'],
              'nik': s['nik'],
              'jenis_kelamin': s['jk'],
              'agama': 'Islam',
              'nomor_hp': '081234567890',
              'alamat': 'Jl. Raya Rajeg, Banten',
            });

            // Suntikkan Nilai Rapor Acak Otomatis (80-99)
            await _supabase.from('nilai').insert([
              {
                'siswa_id': res.user!.id,
                'kelas': s['kelas'],
                'mapel': 'PROJECT IPAS',
                'semester': 'Semester 1 (Ganjil)',
                'kategori': 'Ujian Harian',
                'nilai': 80 + Random().nextInt(20),
                'guru_pengampu': 'AGUS RAHMADANI, SE',
                'tahun_ajaran': '2025/2026',
              },
              {
                'siswa_id': res.user!.id,
                'kelas': s['kelas'],
                'mapel': 'PPKN',
                'semester': 'Semester 1 (Ganjil)',
                'kategori': 'UTS',
                'nilai': 78 + Random().nextInt(22),
                'guru_pengampu': 'MUHAMMAD RIZQI DJUWANDI',
                'tahun_ajaran': '2025/2026',
              },
            ]);
          }
        } catch (_) {}
      }

      setState(() {
        _progress = 0.8;
        _status = "Menyusun Jadwal Pelajaran Otomatis...";
      });

      // 3. DAFTARKAN JADWAL
      try {
        await _supabase.from('jadwal').insert(_jadwalList);
      } catch (_) {}

      setState(() {
        _progress = 1.0;
        _status = "Selesai!";
      });

      _tampilkanDialogSukses();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _tampilkanDialogSukses() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
            SizedBox(height: 12),
            Text(
              'Seeding Berhasil!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'Semua data Siswa, Guru, Jadwal, dan Nilai telah dimasukkan ke Database.\n\n'
          'PENTING: Karena sistem baru saja meregistrasi puluhan akun secara massal, sesi Admin Anda ikut terganti. '
          'Silakan menekan tombol di bawah untuk Logout dan Login kembali.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
              ),
              onPressed: () async {
                await _supabase.auth.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Logout & Kembali ke Login',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Database Seeder (Mode Dev)',
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.rocket_launch_rounded,
                    size: 80,
                    color: Color(0xFF1E40AF),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Suntik Data Otomatis',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tombol ini akan memasukkan data Kelas X-XII, Jadwal Mengajar, Nilai, Guru, beserta kata sandi secara massal ke Database Anda untuk kebutuhan presentasi sidang.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading) ...[
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF1E40AF),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.electric_bolt_rounded),
                        label: const Text(
                          'JALANKAN SEEDER SEKARANG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        onPressed: _jalankanSeeder,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
