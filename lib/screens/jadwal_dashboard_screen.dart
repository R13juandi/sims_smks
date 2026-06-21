import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_screen.dart'; // Sesuaikan path jika letaknya berbeda

class JadwalDashboardScreen extends StatefulWidget {
  const JadwalDashboardScreen({super.key});

  @override
  State<JadwalDashboardScreen> createState() => _JadwalDashboardScreenState();
}

class _JadwalDashboardScreenState extends State<JadwalDashboardScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _userRole = '';
  String _userKelas = '';
  String _namaGuru = '';
  List<Map<String, dynamic>> _jadwalList = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('profiles')
            .select('role, kelas, full_name')
            .eq('id', user.id)
            .maybeSingle(); // Menggunakan maybeSingle() agar tidak error jika data kosong

        if (response == null) {
          // Jika data profil belum ada di database, lakukan logout paksa
          await _supabase.auth.signOut();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Profil pengguna tidak ditemukan di database. Silakan hubungi Admin.',
              ),
            ),
          );
          return;
        }

        setState(() {
          _userRole = response['role'] ?? '';
          _userKelas = response['kelas'] ?? '';
          _namaGuru = response['full_name'] ?? '';
        });

        await _fetchJadwal();
      } else {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error memuat data: $e')));
    }
  }

  Future<void> _fetchJadwal() async {
    try {
      final response = await _supabase
          .from('jadwal_pelajaran')
          .select()
          .order('hari', ascending: true);

      setState(() {
        _jadwalList = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              // 1. Lakukan sign out dari Supabase
              await _supabase.auth.signOut();

              // 2. Bersihkan rute dan kembali ke halaman Login
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat datang, $_namaGuru!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role: $_userRole | Kelas: $_userKelas',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 30, thickness: 1.5),
                  const Text(
                    'Daftar Jadwal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _jadwalList.isEmpty
                        ? const Center(
                            child: Text('Belum ada jadwal yang tersedia.'),
                          )
                        : ListView.builder(
                            itemCount: _jadwalList.length,
                            itemBuilder: (context, index) {
                              final j = _jadwalList[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(
                                    j['kegiatan'] ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Kelas: ${j['kelas'] ?? '-'} • Hari: ${j['hari'] ?? '-'}',
                                  ),
                                  trailing: Text(
                                    j['sesi'] ?? '-',
                                    style: const TextStyle(fontSize: 12),
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
