import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/admin_dashboard.dart';
import 'screens/guru_dashboard.dart';
import 'screens/siswa_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<String> _getRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("User belum login");

    final data = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

    return data['role'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        final role = snapshot.data;

        // Logika pengalihan halaman berdasarkan role
        if (role == 'admin' || role == 'kepsek') {
          return const AdminDashboard();
        } else if (role == 'guru') {
          return const GuruDashboard();
        } else {
          return const SiswaDashboard();
        }
      },
    );
  }
}
