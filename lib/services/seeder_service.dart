import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeederService {
  static final _supabase = Supabase.instance.client;

  /// Fungsi Utama untuk Membaca Excel dan Membuat Akun Siswa Secara Massal
  static Future<void> jalankanSeederSiswaMassal(
    BuildContext context,
    String filePath,
  ) async {
    try {
      // 1. Membaca berkas file Excel baku sekolah
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      // Ambil sheet pertama (Daftar Peserta Didik)
      String sheetName = excel.tables.keys.first;
      var table = excel.tables[sheetName];

      if (table == null) {
        debugPrint("Error: Sheet tidak ditemukan!");
        return;
      }

      int akunBerhasil = 0;
      int akunGagal = 0;

      // 2. Lakukan perulangan mulai dari baris ke-6 (karena baris 0-5 adalah judul & header)
      for (int i = 6; i < table.maxRows; i++) {
        var row = table.rows[i];

        // Cek jika baris kosong atau kolom nama kosong, maka lewati
        if (row.isEmpty || row[1] == null) continue;

        // Ekstraksi data kolom secara presisi sesuai file Excel Anda
        String nama = row[1]?.value?.toString().trim() ?? '';
        String rombelRaw =
            row[2]?.value?.toString().trim() ?? ''; // Contoh: X. TKJ, XI.TKJ
        String nipd = row[3]?.value?.toString().trim() ?? '-';
        String jk = row[4]?.value?.toString().trim() ?? '-';
        String nisn = row[5]?.value?.toString().trim() ?? '-';
        String tempatLahir = row[6]?.value?.toString().trim() ?? '-';
        String tanggalLahirRaw =
            row[7]?.value?.toString().trim() ?? ''; // Format YYYY-MM-DD
        String nik = row[8]?.value?.toString().trim() ?? '-';
        String agama = row[9]?.value?.toString().trim() ?? 'Islam';
        String alamat = row[10]?.value?.toString().trim() ?? '-';
        String kelurahan = row[11]?.value?.toString().trim() ?? '';
        String hp = row[12]?.value?.toString().trim() ?? '-';

        if (nama.isEmpty) continue;

        // Normalisasi format nama kelas/rombel agar rapi di UI aplikasi
        String kelasFix = rombelRaw.replaceAll('.', ' '); // "X. TKJ" -> "X TKJ"
        String alamatLengkap = kelurahan.isNotEmpty
            ? "$alamat, Kel. $kelurahan"
            : alamat;

        // Generasi EMAIL OTOMATIS unik untuk login berdasarkan NISN siswa
        // Misal: 0096379729@smkstiyia.sch.id
        String emailSiswa = "${nisn.toLowerCase()}@smkstiyia.sch.id";

        // PENGATURAN PASSWORD DEFAULT SERAGAM UNTUK SEMUA SISWA
        String passwordDefault = "siswa12345";

        try {
          // 3. Daftarkan Akun Baru ke Supabase Authentication Server
          final AuthResponse authRes = await _supabase.auth.signUp(
            email: emailSiswa,
            password: passwordDefault,
          );

          final String? newUserId = authRes.user?.id;

          if (newUserId != null) {
            // 4. Masukkan Biodata Lengkap Hasil Ekstraksi Excel ke Tabel 'profiles'
            await _supabase.from('profiles').insert({
              'id': newUserId,
              'full_name': nama,
              'role': 'siswa',
              'kelas': kelasFix,
              'nipd': nipd,
              'jenis_kelamin': jk == 'L' ? 'Laki-laki' : 'Perempuan',
              'nisn': nisn,
              'nik': nik,
              'tempat_lahir': tempatLahir,
              'tanggal_lahir': tanggalLahirRaw.isNotEmpty
                  ? tanggalLahirRaw
                  : null,
              'agama': agama,
              'alamat': alamatLengkap,
              'nomor_hp': hp,
            });

            akunBerhasil++;
            debugPrint("SUKSES: Akun lahir atas nama $nama ($emailSiswa)");
          }
        } catch (err) {
          akunGagal++;
          debugPrint("GAGAL mendaftarkan siswa baris ke-$i ($nama): $err");
        }
      }

      // Tampilkan notifikasi ringkasan eksekusi di layar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚡ Seeder Selesai! Berhasil: $akunBerhasil Akun, Gagal: $akunGagal',
            ),
            backgroundColor: Colors.indigo,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fatal pada engine seeder: $e");
    }
  }
}
