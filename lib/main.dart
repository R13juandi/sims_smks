import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_wrapper.dart'; // 🔥 KITA IMPORT AUTH WRAPPER YANG BENAR DI SINI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mnabwkswugarnigqzmgm.supabase.co',
    anonKey: 'sb_publishable_GSTLu5swfHOAOJPo7Yoo3A_oKIjCEYB',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIMS SMKS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, 
        useMaterial3: true,
      ),
      home: const AuthWrapper(), // 🔥 SEKARANG INI AKAN MEMANGGIL FILE lib/auth_wrapper.dart
    );
  }
}

