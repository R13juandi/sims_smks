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

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedOut) {
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
      Map<String, dynamic>? profileData;
      int retries = 0;

      while (profileData == null && retries < 5) {
        profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle(); 

        if (profileData == null) {
          await Future.delayed(const Duration(seconds: 1));
          retries++;
        }
      }

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

      // 🔥 LOGIKA ROUTING OTOMATIS (KEBAL TYPO)
      final role = profileData['role']?.toString().toLowerCase().trim() ?? 'siswa';
      Widget nextWidget;

      if (role.contains('admin') || role.contains('tata') || role.contains('kepsek')) {
        nextWidget = const AdminDashboard();
      } else if (role.contains('guru')) {
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
      debugPrint('Error Auth: $e');
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
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    return _homeWidget;
  }
}