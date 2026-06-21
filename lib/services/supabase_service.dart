import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Fungsi untuk mendapatkan data profil user yang sedang login
  Future<Map<String, dynamic>> getMyProfile() async {
    final userId = _client.auth.currentUser!.id;
    return await _client.from('profiles').select().eq('id', userId).single();
  }

  // Fungsi untuk tambah absensi
  Future<void> submitAbsensi(String status, String keterangan) async {
    await _client.from('absensi').insert({
      'siswa_id': _client.auth.currentUser!.id,
      'status': status,
      'keterangan': keterangan,
    });
  }
}