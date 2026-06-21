import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/guru_dashboard.dart';
import 'screens/siswa_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Widget _homeWidget = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _checkAuth();

    // Memantau perubahan status Login/Logout secara real-time
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut) {
        _checkAuth();
      }
    });
  }

  Future<void> _checkAuth() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;

      // Jika tidak ada yang login, arahkan ke Login Screen
      if (session == null) {
        if (mounted) {
          setState(() {
            _homeWidget = const LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      final user = session.user;

      // =======================================================
      // PERBAIKAN: Mencegah Race Condition (Blank Putih)
      // Kita suruh sistem menunggu (retry) sampai data profile masuk
      // =======================================================
      Map<String, dynamic>? profileData;
      int retries = 0;

      while (profileData == null && retries < 5) {
        profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle(); // Menggunakan maybeSingle agar tidak crash jika data masih kosong

        if (profileData == null) {
          // Tunggu 1 detik sebelum mencoba mengecek lagi
          await Future.delayed(const Duration(seconds: 1));
          retries++;
        }
      }

      // Jika setelah 5 detik data tetap tidak ada, amankan aplikasi (Paksa Logout)
      if (profileData == null) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          setState(() {
            _homeWidget = const LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      // Membaca peran pengguna dan mengarahkannya ke Dashboard yang tepat
      final role = profileData['role']?.toString().toLowerCase();
      Widget nextWidget;

      if (role == 'admin') {
        nextWidget = const AdminDashboard();
      } else if (role == 'guru') {
        nextWidget = const GuruDashboard();
      } else {
        nextWidget = const SiswaDashboard();
      }

      if (mounted) {
        setState(() {
          _homeWidget = nextWidget;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Jika terjadi error sistem, kembalikan secara aman ke halaman Login
      print('Error Auth: $e');
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        setState(() {
          _homeWidget = const LoginScreen();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan Loading saat sedang mengecek akun
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              SizedBox(height: 16),
              Text(
                'Menyiapkan sesi Anda...',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _homeWidget;
  }
}
