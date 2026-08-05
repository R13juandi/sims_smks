import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/popup_service.dart';
import '../login_screen.dart';
import 'rekap_nilai_admin_screen.dart';
import 'tambah_user_screen.dart';
import 'manajemen_user_screen.dart';
import 'seeder_database_screen.dart';
import 'manajemen_jadwal_screen.dart';
import 'nilai_rapor_screen.dart';
// 🔥 IMPOR FILE BARU (PENAMBAHAN)
import 'admin_guru_pengganti_screen.dart';

// =========================================================================
// 1. DASHBOARD ADMIN / KEPSEK / TATA USAHA
// =========================================================================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _currentIndex = 0;

  String _currentUserRole = 'admin';

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _absensiHariIni = [];

  int _totalSiswa = 0;
  int _totalGuru = 0;
  int _jumlahHadir = 0;
  int _jumlahIzin = 0;
  int _jumlahSakit = 0;
  int _jumlahAlpa = 0;

  @override
  void initState() {
    super.initState();
    _loadAdminAnalyticData();
  }

  Future<void> _loadAdminAnalyticData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userAuth = _supabase.auth.currentUser;
      if (userAuth != null) {
        final profileRes = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', userAuth.id)
            .maybeSingle();
        _currentUserRole =
            profileRes?['role']?.toString().toLowerCase().trim() ?? 'admin';
      }

      final usersRes = await _supabase.from('profiles').select('*');
      _allUsers = List<Map<String, dynamic>>.from(usersRes as List);

      // Hanya hitung siswa aktif, bukan alumni
      _totalSiswa = _allUsers.where((u) => u['role'] == 'siswa' && (u['status'] == null || u['status'] == 'Aktif')).length;
      _totalGuru = _allUsers.where((u) => u['role'] == 'guru').length;

      final formatTanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final absenRes = await _supabase
          .from('absensi')
          .select('*, profiles(full_name, role, kelas, nisn)')
          .eq('tanggal', formatTanggal);
          
      // 🔥 PERBAIKAN: Filter agar HANYA SISWA yang masuk ke grafik Beranda
      _absensiHariIni = List<Map<String, dynamic>>.from(absenRes as List)
          .where((a) => a['profiles']?['role']?.toString().toLowerCase() == 'siswa')
          .toList();

      _jumlahHadir = _absensiHariIni.where((a) => a['status'].toString().toUpperCase().contains('TEPAT') || a['status'].toString().toUpperCase().contains('HADIR') || a['status'].toString().toUpperCase() == 'T' || a['status'].toString().toUpperCase() == 'H').length;
      _jumlahIzin = _absensiHariIni.where((a) => a['status'].toString().toUpperCase() == 'IZIN' || a['status'].toString().toUpperCase() == 'I').length;
      _jumlahSakit = _absensiHariIni.where((a) => a['status'].toString().toUpperCase() == 'SAKIT' || a['status'].toString().toUpperCase() == 'S').length;
      _jumlahAlpa = _absensiHariIni.where((a) => a['status'].toString().toUpperCase() == 'ALPA' || a['status'].toString().toUpperCase() == 'A').length;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(context, 'Gagal memuat data analitik: $e', isSuccess: false, judul: 'Terjadi Kesalahan');
      }
    }
  }

  void _tampilkanDetailFoto(BuildContext context, String url, String namaSiswa) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Bukti Presensi: $namaSiswa', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
              backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))],
            ),
            InteractiveViewer(
              panEnabled: true, minScale: 0.5, maxScale: 4.0,
              child: Image.network(
                url, fit: BoxFit.contain, 
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
                }, 
                errorBuilder: (context, error, stackTrace) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red)))
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 🔥 POP-UP KTP DIGITAL VIP (SANGAT DETAIL & KOMPLEKS)
  void _showDetailUser(BuildContext context, Map<String, dynamic> userData) {
    bool isKepsek = _currentUserRole.contains('kepsek');
    String role = (userData['role'] ?? '').toString().toUpperCase();
    String nama = userData['full_name'] ?? '-';
    
    String kelas = '-';
    if (userData['kelas'] != null) {
      if (userData['kelas'] is List) {
        kelas = (userData['kelas'] as List).join(', ');
      } else {
        kelas = userData['kelas'].toString();
      }
    }

    String mapel = (userData['mapel'] as List?)?.join(', ') ?? userData['mata_pelajaran'] ?? '-';
    String noHp = userData['no_hp'] ?? userData['nomor_hp'] ?? '-';
    String alamat = userData['alamat'] ?? userData['alamat_domisili'] ?? '-';
    String jk = userData['jk'] ?? userData['jenis_kelamin'] ?? '-';
    String agama = userData['agama'] ?? '-';
    String status = userData['status'] ?? 'Aktif';
    String tempatLahir = userData['tempat_lahir'] ?? '-';
    
    String tglLahir = '-';
    if (userData['tanggal_lahir'] != null && userData['tanggal_lahir'].toString().isNotEmpty) {
      try {
        final tgl = DateTime.parse(userData['tanggal_lahir'].toString());
        tglLahir = DateFormat('dd MMMM yyyy', 'id_ID').format(tgl);
      } catch (_) { tglLahir = userData['tanggal_lahir'].toString(); }
    }

    String nisnNik = role == 'SISWA' ? (userData['nisn'] ?? '-') : (userData['nik'] ?? '-');
    String labelNisnNik = role == 'SISWA' ? 'NISN / NIPD' : 'NIK / NUPTK';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(color: role == 'SISWA' ? Colors.indigo.shade600 : Colors.teal.shade700, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.person, size: 50, color: role == 'SISWA' ? Colors.indigo : Colors.teal)),
                    const SizedBox(height: 12),
                    Text(nama, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30)), child: Text('STATUS: ${status.toUpperCase()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1))),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INFORMASI AKADEMIK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.badge_rounded, labelNisnNik, nisnNik),
                      
                      if (role == 'SISWA') _buildInfoRow(Icons.school_rounded, 'Kelas', kelas),
                      if (role == 'GURU') ...[
                        FutureBuilder(
                          future: _supabase.from('jadwal').select('kelas').eq('guru_pengampu', nama),
                          builder: (context, snapshot) {
                            String klsAjar = 'Sedang mencari kelas...';
                            if (snapshot.connectionState == ConnectionState.done) {
                              if (snapshot.hasData && (snapshot.data as List).isNotEmpty) {
                                final setKelas = (snapshot.data as List).map((e) => e['kelas'].toString()).toSet().toList();
                                setKelas.sort();
                                klsAjar = setKelas.join(', ');
                              } else {
                                klsAjar = userData['kelas'] != null ? (userData['kelas'] is List ? (userData['kelas'] as List).join(', ') : userData['kelas'].toString()) : 'Belum mengajar di kelas manapun';
                              }
                            }
                            return _buildInfoRow(Icons.class_rounded, 'Kelas Ajar', klsAjar);
                          },
                        ),
                        _buildInfoRow(Icons.menu_book_rounded, 'Mapel', mapel),
                      ],
                      
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                      
                      const Text('DATA PRIBADI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.cake_rounded, 'TTL', '$tempatLahir, $tglLahir'),
                      _buildInfoRow(Icons.wc_rounded, 'Jenis Kelamin', jk),
                      _buildInfoRow(Icons.mosque_rounded, 'Agama', agama),
                      _buildInfoRow(Icons.phone_android_rounded, 'No. Handphone', noHp),
                      _buildInfoRow(Icons.home_rounded, 'Alamat', alamat),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                    if (!isKepsek) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManajemenUserScreen()));
                          },
                          icon: const Icon(Icons.edit_document, size: 16),
                          label: const Text('Edit Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)))])),
        ],
      ),
    );
  }

  void _showDialogSiswa() {
    final siswaList = _allUsers.where((u) => u['role'] == 'siswa' && (u['status'] == null || u['status'] == 'Aktif')).toList();
    Map<String, List<Map<String, dynamic>>> groupedByKelas = {};
    for (var s in siswaList) {
      final k = (s['kelas'] ?? 'Tanpa Kelas').toString();
      groupedByKelas.putIfAbsent(k, () => []).add(s);
    }
    final sortedKelas = groupedByKelas.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [const Icon(Icons.face_rounded, color: Colors.indigo), const SizedBox(width: 8), Text('Siswa Aktif (${siswaList.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        content: SizedBox(
          width: double.maxFinite, height: MediaQuery.of(context).size.height * 0.6,
          child: ListView.builder(
            shrinkWrap: true, itemCount: sortedKelas.length,
            itemBuilder: (context, index) {
              final kelas = sortedKelas[index]; final list = groupedByKelas[kelas]!;
              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: ExpansionTile(
                  leading: CircleAvatar(backgroundColor: Colors.indigo.shade50, child: Text(list.length.toString(), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12))),
                  title: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: list.map((s) => Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.grey), title: Text(s['full_name'] ?? '-'), subtitle: Text('NISN: ${s['nisn'] ?? '-'}'), trailing: const Icon(Icons.remove_red_eye, size: 18, color: Colors.indigo),
                      onTap: () { Navigator.pop(ctx); _showDetailUser(context, s); },
                    ),
                  )).toList(),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)))],
      ),
    );
  }

  void _showDialogGuru() {
    final guruList = _allUsers.where((u) => u['role'] == 'guru').toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [const Icon(Icons.supervisor_account_rounded, color: Colors.teal), const SizedBox(width: 8), Text('Guru Aktif (${guruList.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        content: SizedBox(
          width: double.maxFinite, height: MediaQuery.of(context).size.height * 0.6,
          child: ListView.builder(
            shrinkWrap: true, itemCount: guruList.length,
            itemBuilder: (context, index) {
              final g = guruList[index]; final mapel = (g['mapel'] as List?)?.join(', ') ?? 'Belum ada mapel';
              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: const Icon(Icons.person, color: Colors.teal)),
                  title: Text(g['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Mapel: $mapel', style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.remove_red_eye, size: 18, color: Colors.teal),
                  onTap: () { Navigator.pop(ctx); _showDetailUser(context, g); },
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))));
    final List<Widget> childrenPage = [_buildBerandaKanalTab(), _buildManajemenAkunTab()];
    bool isKepsek = _currentUserRole.contains('kepsek');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isKepsek ? 'PANTAUAN KEPALA SEKOLAH' : 'DASHBOARD ADMIN / TU', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8, color: Color(0xFF0F172A))),
            if (isKepsek) const Text('Mode Eksekutif (Read-Only)', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white, elevation: 0.5,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.power_settings_new_rounded, color: Colors.red[600], size: 18), tooltip: 'Keluar Sistem',
              onPressed: () => PopupService.showConfirm(context, 'Keluar dari sistem?', judul: 'Konfirmasi', onConfirm: () async { await _supabase.auth.signOut(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false); }),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: childrenPage[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, backgroundColor: Colors.white, selectedItemColor: const Color(0xFF0F172A), unselectedItemColor: const Color(0xFF94A3B8), selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Monitor'), BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Menu Utama')],
      ),
    );
  }

  Widget _buildBerandaKanalTab() {
    Map<String, List<Map<String, dynamic>>> groupedAbsen = {};
    for (var a in _absensiHariIni) {
      final k = a['profiles']?['kelas'] ?? 'Tanpa Kelas';
      if (!groupedAbsen.containsKey(k)) groupedAbsen[k] = [];
      groupedAbsen[k]!.add(a);
    }

    return RefreshIndicator(
      onRefresh: _loadAdminAnalyticData, color: const Color(0xFF1E3A8A),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _cardMoni('Siswa Aktif', '$_totalSiswa', Icons.face_rounded, Colors.indigo, onTap: _showDialogSiswa)),
              const SizedBox(width: 12),
              Expanded(child: _cardMoni('Guru Aktif', '$_totalGuru', Icons.supervisor_account_rounded, Colors.teal, onTap: _showDialogGuru)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Statistik Kehadiran Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))), const SizedBox(height: 16),
                _buildProgressBarEksekutif('Hadir / Tepat', _jumlahHadir, Colors.green), _buildProgressBarEksekutif('Izin Keterangan', _jumlahIzin, Colors.orange), _buildProgressBarEksekutif('Sakit Berkas', _jumlahSakit, Colors.blue), _buildProgressBarEksekutif('Alpa / Bolos', _jumlahAlpa, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Pantauan Kedisiplinan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          
          groupedAbsen.isEmpty
              ? Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Belum ada aktivitas presensi masuk hari ini.', style: TextStyle(color: Colors.grey, fontSize: 13))))
              : ListView.builder(
                  physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: groupedAbsen.keys.length,
                  itemBuilder: (context, index) {
                    String namaKelas = groupedAbsen.keys.elementAt(index); List<Map<String, dynamic>> dataKelas = groupedAbsen[namaKelas]!;
                    return Card(
                      elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                      child: ExpansionTile(
                        shape: const Border(), leading: const Icon(Icons.folder_open_rounded, color: Colors.amber, size: 36), title: Text('Kelas $namaKelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text('${dataKelas.length} Siswa Terverifikasi', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        children: dataKelas.map((data) {
                          final nama = data['profiles']?['full_name'] ?? 'User'; final statusOri = data['status'] ?? '-'; final fotoUrl = data['foto_url']; final waktuScanStr = data['waktu_absen'] ?? '00:00';
                          int hour = 0; int minute = 0;
                          try { if (waktuScanStr.contains(':')) { hour = int.parse(waktuScanStr.split(':')[0]); minute = int.parse(waktuScanStr.split(':')[1]); } } catch (e) {}
                          String labelStatus = 'Tepat Waktu'; Color warnaStatus = Colors.green;
                          if (hour > 7 || (hour == 7 && minute > 45)) { labelStatus = 'Terlambat / Alfa'; warnaStatus = Colors.red; }
                          if (statusOri == 'I') { labelStatus = 'Izin Resmi'; warnaStatus = Colors.orange; } else if (statusOri == 'S') { labelStatus = 'Sakit'; warnaStatus = Colors.blue; }
                          return Container(
                            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: warnaStatus.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: warnaStatus.withOpacity(0.5))), child: Text(waktuScanStr, style: TextStyle(fontWeight: FontWeight.bold, color: warnaStatus, fontSize: 14))), const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 2), Text(labelStatus, style: TextStyle(fontSize: 11, color: warnaStatus, fontWeight: FontWeight.bold))])), const SizedBox(width: 8),
                                if (statusOri == 'I' || statusOri == 'S') Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_document, color: Colors.orange, size: 20)) else if (fotoUrl != null && fotoUrl.isNotEmpty) GestureDetector(onTap: () => _tampilkanDetailFoto(context, fotoUrl, nama), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 40, height: 40, color: Colors.red.shade50, child: const Icon(Icons.broken_image, color: Colors.red, size: 16))))) else Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, color: Colors.grey, size: 20)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildProgressBarEksekutif(String label, int count, Color color) {
    double persentase = _absensiHariIni.isEmpty ? 0.0 : count / _absensiHariIni.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))), Text('$count Orang (${(persentase * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))]), const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _absensiHariIni.isEmpty ? 0.0 : persentase, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8)),
        ],
      ),
    );
  }

  Widget _cardMoni(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)]),
          child: Row(children: [CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11), overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)))]))]),
        ),
      ),
    );
  }

  Widget _buildManajemenAkunTab() {
    bool isKepsek = _currentUserRole.contains('kepsek');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(isKepsek ? 'Portal Navigasi Eksekutif' : 'Pusat Kontrol Akses Akun & Fitur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))), const SizedBox(height: 14),
        
        _buildMenuButton(Icons.supervised_user_circle_rounded, 'Manajemen Database Pengguna', isKepsek ? 'Pantau data seluruh Siswa & Guru' : 'Tambah, Edit profil, Hapus, & Reset Sandi', const Color(0xFF0F172A), () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManajemenUserScreen()))), const SizedBox(height: 12),
        
        _buildMenuButton(Icons.workspace_premium_rounded, 'Buku Induk Alumni (Lulusan)', 'Lihat histori data dan cetak rapor siswa lulus', Colors.amber.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => ArsipAlumniScreen(allUsers: _allUsers, userRole: _currentUserRole)))), const SizedBox(height: 12),

        // 🔥 MENU KEHADIRAN & IZIN GURU (BISA DILIHAT KEPSEK, TAPI READ-ONLY)
        _buildMenuButton(
          Icons.co_present_rounded, 
          'Kehadiran & Izin Guru', 
          isKepsek ? 'Pantau daftar kehadiran dan izin guru' : 'Input absen dan izin guru secara manual', 
          Colors.pink.shade700, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => KehadiranGuruScreen(userRole: _currentUserRole)))
        ), const SizedBox(height: 12),

        if (!isKepsek) ...[
          // 🔥 MENU BARU: MANAJEMEN GURU PENGGANTI DITAMBAHKAN DI SINI
          _buildMenuButton(Icons.transfer_within_a_station_rounded, 'Manajemen Guru Pengganti (Infal)', 'Tetapkan guru pengganti jika guru master berhalangan hadir', Colors.cyan.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminGuruPenggantiScreen()))), const SizedBox(height: 12),

          _buildMenuButton(Icons.how_to_reg_rounded, 'Absensi Manual (Guru Inval)', 'Input absen kelas jika guru utama berhalangan hadir', Colors.purple.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AbsensiManualInvalScreen()))), const SizedBox(height: 12),
        ],

        _buildMenuButton(Icons.calendar_month_rounded, 'Manajemen Jadwal Pelajaran', isKepsek ? 'Lihat struktur jadwal pelajaran sekolah' : 'Atur & susun jadwal pelajaran', Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManajemenJadwalScreen()))), const SizedBox(height: 12),
        _buildMenuButton(Icons.account_balance_wallet_rounded, 'Administrasi Keuangan & SPP', isKepsek ? 'Pantau laporan keuangan & arus kas SPP' : 'Input pembayaran & Verifikasi SPP', Colors.teal.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminAdministrasiScreen(userRole: _currentUserRole)))), const SizedBox(height: 12),
        _buildMenuButton(Icons.grade_rounded, 'Super Manajemen Nilai & Rapor', 'Pantau rekap nilai & Cetak e-Rapor Kurikulum', Colors.orange.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RekapNilaiAdminScreen()))), const SizedBox(height: 12),
        _buildMenuButton(Icons.analytics_rounded, 'Laporan Akumulasi Absensi', 'Lihat dan cetak rekap kehadiran siswa per bulan', Colors.blue.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (context) => RekapAbsensiAdminScreen(userRole: _currentUserRole)))),
      ],
    );
  }

  Widget _buildMenuButton(IconData icon, String title, String sub, Color color, VoidCallback action) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: action, borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)), const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))), const SizedBox(height: 3), Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))])), const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 🔥 HALAMAN BARU: BUKU INDUK ALUMNI / SISWA LULUS
// =========================================================================
class ArsipAlumniScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final String userRole;
  const ArsipAlumniScreen({super.key, required this.allUsers, required this.userRole});

  @override
  State<ArsipAlumniScreen> createState() => _ArsipAlumniScreenState();
}

class _ArsipAlumniScreenState extends State<ArsipAlumniScreen> {
  String _searchQuery = '';

  void _showDetailAlumni(BuildContext context, Map<String, dynamic> userData) {
    String nama = userData['full_name'] ?? '-';
    String kelas = userData['kelas'] ?? 'Alumni';
    String noHp = userData['no_hp'] ?? userData['nomor_hp'] ?? '-';
    String alamat = userData['alamat'] ?? userData['alamat_domisili'] ?? '-';
    String jk = userData['jk'] ?? userData['jenis_kelamin'] ?? '-';
    String agama = userData['agama'] ?? '-';
    String status = userData['status'] ?? 'Lulus / Alumni';
    String tempatLahir = userData['tempat_lahir'] ?? '-';
    
    String tglLahir = '-';
    if (userData['tanggal_lahir'] != null && userData['tanggal_lahir'].toString().isNotEmpty) {
      try {
        final tgl = DateTime.parse(userData['tanggal_lahir'].toString());
        tglLahir = DateFormat('dd MMMM yyyy', 'id_ID').format(tgl);
      } catch (_) { tglLahir = userData['tanggal_lahir'].toString(); }
    }

    String nisnNik = userData['nisn'] ?? '-';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  children: [
                    const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.school, size: 40, color: Colors.amber)), const SizedBox(height: 12),
                    Text(nama, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30)), child: Text('STATUS: ${status.toUpperCase()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1))),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INFORMASI ALUMNI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 8),
                      _buildInfoRow(Icons.badge_rounded, 'NISN', nisnNik),
                      _buildInfoRow(Icons.school_rounded, 'Riwayat Kelas', kelas),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                      const Text('DATA PRIBADI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 8),
                      _buildInfoRow(Icons.cake_rounded, 'TTL', '$tempatLahir, $tglLahir'),
                      _buildInfoRow(Icons.wc_rounded, 'Jenis Kelamin', jk),
                      _buildInfoRow(Icons.mosque_rounded, 'Agama', agama),
                      _buildInfoRow(Icons.phone_android_rounded, 'No. Handphone', noHp),
                      _buildInfoRow(Icons.home_rounded, 'Alamat', alamat),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)))])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAlumni = widget.allUsers.where((u) {
      if (u['role'] != 'siswa' && u['role'] != 'alumni') return false;
      String st = (u['status'] ?? '').toString().toLowerCase();
      String kl = (u['kelas'] ?? '').toString().toLowerCase();
      bool isLulus = st.contains('lulus') || st.contains('alumni') || kl.contains('lulus') || kl.contains('alumni');
      
      if (!isLulus) return false;
      
      if (_searchQuery.isNotEmpty) {
        String nm = (u['full_name'] ?? '').toString().toLowerCase();
        String ni = (u['nisn'] ?? '').toString().toLowerCase();
        return nm.contains(_searchQuery) || ni.contains(_searchQuery);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Buku Induk Alumni', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: TextField(
              decoration: InputDecoration(hintText: 'Cari Nama / NISN Alumni...', prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: listAlumni.isEmpty 
              ? const Center(child: Text('Belum ada data alumni / lulusan.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16), itemCount: listAlumni.length,
                  itemBuilder: (context, index) {
                    final alumni = listAlumni[index];
                    return Card(
                      elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const CircleAvatar(backgroundColor: Color(0xFFFFFBEB), child: Icon(Icons.school, color: Colors.amber)),
                        title: Text(alumni['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('NISN: ${alumni['nisn'] ?? '-'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.badge, color: Colors.blue), tooltip: 'Lihat Profil', onPressed: () => _showDetailAlumni(context, alumni)),
                            IconButton(
                              icon: const Icon(Icons.analytics_rounded, color: Colors.green), tooltip: 'Cetak Rapor Histori', 
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NilaiRaporScreen(siswaId: alumni['id'].toString()))),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          )
        ],
      )
    );
  }
}

// =========================================================================
// 2. REKAP AKUMULASI BULANAN (WITH KEPSEK READ-ONLY PROTECTOR)
// =========================================================================
class RekapAbsensiAdminScreen extends StatefulWidget {
  final String userRole;
  const RekapAbsensiAdminScreen({super.key, this.userRole = 'admin'});

  @override
  State<RekapAbsensiAdminScreen> createState() => _RekapAbsensiAdminScreenState();
}

class _RekapAbsensiAdminScreenState extends State<RekapAbsensiAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rekapData = [];

  String _selectedBulan = DateFormat('MM').format(DateTime.now());
  String _selectedTahun = DateFormat('yyyy').format(DateTime.now());

  final List<Map<String, String>> _listBulan = [
    {'id': '01', 'nama': 'Januari'}, {'id': '02', 'nama': 'Februari'}, {'id': '03', 'nama': 'Maret'},
    {'id': '04', 'nama': 'April'}, {'id': '05', 'nama': 'Mei'}, {'id': '06', 'nama': 'Juni'},
    {'id': '07', 'nama': 'Juli'}, {'id': '08', 'nama': 'Agustus'}, {'id': '09', 'nama': 'September'},
    {'id': '10', 'nama': 'Oktober'}, {'id': '11', 'nama': 'November'}, {'id': '12', 'nama': 'Desember'},
  ];
  final List<String> _listTahun = ['2024', '2025', '2026', '2027', '2028'];

  @override
  void initState() {
    super.initState();
    _fetchRekapBulanan();
  }

  Future<void> _fetchRekapBulanan() async {
    setState(() => _isLoading = true);
    try {
      int year = int.parse(_selectedTahun);
      int month = int.parse(_selectedBulan);
      String startDate = '$_selectedTahun-$_selectedBulan-01';
      int lastDay = DateTime(year, month + 1, 0).day;
      String endDate = '$_selectedTahun-$_selectedBulan-${lastDay.toString().padLeft(2, '0')}';

      final response = await _supabase.rpc('get_rekap_bulanan_siswa', params: {'p_start_date': startDate, 'p_end_date': endDate});

      final List<Map<String, dynamic>> finalData = (response as List).map((item) => {
        'id': item['id'], 'nama': item['nama'], 'nisn': item['nisn'], 'kelas': item['kelas'],
        'H': item['hadir'] ?? 0, 'I': item['izin'] ?? 0, 'S': item['sakit'] ?? 0, 'A': item['alpa'] ?? 0, 'T': item['telat'] ?? 0,
      }).toList();

      if (mounted) setState(() { _rekapData = finalData; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); PopupService.show(context, 'Gagal memuat rekap: $e', isSuccess: false); }
    }
  }

  Future<void> _updateStatusAbsenAdmin(dynamic idAbsen, String statusBaru, String verifikasi) async {
    if (widget.userRole.contains('kepsek')) return;
    try {
      await _supabase.from('absensi').update({'status': statusBaru, 'status_verifikasi': verifikasi}).eq('id', idAbsen);
      if (!mounted) return;
      PopupService.show(context, 'Status berhasil diubah!', isSuccess: true);
      _fetchRekapBulanan(); Navigator.pop(context); 
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal mengupdate: $e', isSuccess: false);
    }
  }

  void _tampilkanDetailFoto(BuildContext context, String url, String namaSiswa) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: Text('Bukti Presensi: $namaSiswa', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)), backgroundColor: Colors.white, elevation: 0, automaticallyImplyLeading: false, actions: [IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))]),
            InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4.0, child: Image.network(url, fit: BoxFit.contain, loadingBuilder: (context, child, loadingProgress) { if (loadingProgress == null) return child; return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())); }, errorBuilder: (context, error, stackTrace) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red))))),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _lihatDetailLogSiswa(BuildContext context, String idSiswa, String nama, String bulan, String tahun) async {
    int year = int.parse(tahun); int month = int.parse(bulan);
    String startDate = '$tahun-$bulan-01';
    int lastDay = DateTime(year, month + 1, 0).day;
    String endDate = '$tahun-$bulan-${lastDay.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [const Icon(Icons.history_rounded, color: Color(0xFF1E40AF)), const SizedBox(width: 8), Expanded(child: Text('Riwayat Absen: $nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _supabase.from('absensi').select('*').eq('siswa_id', idSiswa).gte('tanggal', startDate).lte('tanggal', endDate).order('tanggal', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || (snapshot.data as List).isEmpty) return const Center(child: Text('Tidak ada riwayat absen di bulan ini.'));
                    final logs = snapshot.data as List;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16), itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final String? foto = log['foto_url']; final String verifikasi = log['status_verifikasi'] ?? 'Pending'; final String jamAbsen = log['waktu_absen'] ?? '-'; final String keterangan = log['keterangan'] ?? '-'; final double? lat = log['lat'] as double?; final double? lng = log['lng'] as double?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: verifikasi == 'Pending' ? Colors.orange : Colors.grey.shade300, width: verifikasi == 'Pending' ? 1.5 : 1.0)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (foto != null && foto.isNotEmpty) GestureDetector(onTap: () => _tampilkanDetailFoto(context, foto, nama), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(foto, width: 45, height: 45, fit: BoxFit.cover))) else Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.location_on, color: Colors.blue)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(log['tanggal'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text('Status: ${log['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: log['status'] == 'A' ? Colors.red : Colors.green))]), Text('⏰ Scan: $jamAbsen WIB | Mapel: ${log['mapel'] ?? "-"}', style: const TextStyle(fontSize: 11, color: Colors.grey))])),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)), child: Text('📍 Keterangan: $keterangan\n📌 Verifikasi: $verifikasi ${lat != null ? "(GPS: $lat, $lng)" : ""}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87, height: 1.3))),
                                if (!widget.userRole.contains('kepsek') && verifikasi == 'Pending') ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)), onPressed: () => _updateStatusAbsenAdmin(log['id'], 'A', 'Ditolak'), child: const Text('Tolak (Alfa)', style: TextStyle(fontSize: 11))), const SizedBox(width: 8),
                                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)), onPressed: () => _updateStatusAbsenAdmin(log['id'], log['status'], 'Disetujui'), child: const Text('ACC SAH (Override)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedByKelas = {};
    for (var s in _rekapData) {
      final kelas = s['kelas'];
      if (!groupedByKelas.containsKey(kelas)) groupedByKelas[kelas] = [];
      groupedByKelas[kelas]!.add(s);
    }
    final sortedKelas = groupedByKelas.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Laporan Akumulasi Bulanan', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                Expanded(flex: 2, child: DropdownButtonFormField<String>(value: _selectedBulan, decoration: InputDecoration(labelText: 'Bulan', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _listBulan.map((b) => DropdownMenuItem(value: b['id'], child: Text(b['nama']!))).toList(), onChanged: (val) { if (val != null) { setState(() => _selectedBulan = val); _fetchRekapBulanan(); } })),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: DropdownButtonFormField<String>(value: _selectedTahun, decoration: InputDecoration(labelText: 'Tahun', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _listTahun.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (val) { if (val != null) { setState(() => _selectedTahun = val); _fetchRekapBulanan(); } })),
              ],
            ),
          ),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF))) : sortedKelas.isEmpty ? const Center(child: Text('Data kosong.', style: TextStyle(color: Colors.grey))) : ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: sortedKelas.length,
              itemBuilder: (context, index) {
                final kelas = sortedKelas[index];
                final siswaList = groupedByKelas[kelas]!;
                siswaList.sort((a, b) => a['nama'].toString().compareTo(b['nama'].toString()));
                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  child: ExpansionTile(
                    leading: const Icon(Icons.folder_shared_rounded, color: Colors.amber, size: 36),
                    title: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('${siswaList.length} Siswa', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    children: siswaList.map((data) {
                      return InkWell(
                        onTap: () => _lihatDetailLogSiswa(context, data['id'], data['nama'], _selectedBulan, _selectedTahun),
                        child: Container(
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))), padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatusBadge('Hadir', data['H'], Colors.green), _buildStatusBadge('Izin', data['I'], Colors.orange), _buildStatusBadge('Sakit', data['S'], Colors.blue), _buildStatusBadge('Alfa', data['A'], Colors.red), if (data['T'] > 0) _buildStatusBadge('Telat', data['T'], Colors.amber.shade700), const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))), child: Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color))),
      ],
    );
  }
}

// =========================================================================
// 3. ADMINISTRASI KEUANGAN (WITH KEPSEK READ-ONLY PROTECTOR)
// =========================================================================
class AdminAdministrasiScreen extends StatefulWidget {
  final String userRole;
  const AdminAdministrasiScreen({super.key, this.userRole = 'admin'});

  @override
  State<AdminAdministrasiScreen> createState() => _AdminAdministrasiScreenState();
}

class _AdminAdministrasiScreenState extends State<AdminAdministrasiScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _listSiswa = [];
  List<Map<String, dynamic>> _listVerifikasi = [];
  String _searchQuery = '';
  late TabController _tabController;
  bool _isKepsek = false;

  @override
  void initState() {
    super.initState();
    _isKepsek = widget.userRole.contains('kepsek');
    _tabController = TabController(length: _isKepsek ? 1 : 2, vsync: this);
    _fetchDataAwal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDataAwal() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final resSiswa = await _supabase.from('profiles').select('*').eq('role', 'siswa').order('full_name', ascending: true);
      final resPending = await _supabase.from('pembayaran').select('*').eq('status', 'Pending').order('created_at', ascending: false);
      if (mounted) { setState(() { _listSiswa = List<Map<String, dynamic>>.from(resSiswa); _listVerifikasi = List<Map<String, dynamic>>.from(resPending); _isLoading = false; }); }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); PopupService.show(context, 'Gagal memuat data keuangan.', isSuccess: false); }
    }
  }

  Future<void> _verifikasiTerima(String idPembayaran) async {
    if (_isKepsek) return; 
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from('pembayaran').update({'status': 'LUNAS', 'penerima': user?.email ?? 'Admin TU', 'tanggal_bayar': DateTime.now().toIso8601String()}).eq('id', idPembayaran);
      await _fetchDataAwal();
      if (mounted) PopupService.show(context, 'Pembayaran DITERIMA & LUNAS!', isSuccess: true);
    } catch (e) {
      if (mounted) { PopupService.show(context, 'Gagal memverifikasi', isSuccess: false); setState(() => _isLoading = false); }
    }
  }

  Future<void> _verifikasiTolak(String idPembayaran) async {
    if (_isKepsek) return; 
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _supabase.from('pembayaran').delete().eq('id', idPembayaran);
      await _fetchDataAwal();
      if (mounted) PopupService.show(context, 'Pembayaran DITOLAK', isSuccess: true);
    } catch (e) {
      if (mounted) { PopupService.show(context, 'Gagal menolak', isSuccess: false); setState(() => _isLoading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSiswa = _listSiswa.where((u) {
      if (_searchQuery.isEmpty) return true;
      return (u['full_name'] ?? '').toString().toLowerCase().contains(_searchQuery) || (u['kelas'] ?? '').toString().toLowerCase().contains(_searchQuery);
    }).toList();

    final Map<String, List<Map<String, dynamic>>> groupedByKelas = {};
    for (var s in filteredSiswa) {
      final k = (s['kelas'] ?? 'Tanpa Kelas').toString();
      groupedByKelas.putIfAbsent(k, () => []).add(s);
    }
    final sortedKelas = groupedByKelas.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isKepsek ? 'Laporan Keuangan & SPP' : 'Keuangan Tata Usaha', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        bottom: _isKepsek ? null : TabBar(controller: _tabController, labelColor: Colors.blue.shade900, indicatorColor: Colors.blue.shade900, tabs: [const Tab(text: 'Data Kasir Siswa'), Tab(text: 'Verifikasi Online (${_listVerifikasi.length})')]),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _isKepsek ? _buildTabKasir(sortedKelas, groupedByKelas) : TabBarView(controller: _tabController, children: [_buildTabKasir(sortedKelas, groupedByKelas), _buildTabVerifikasi()]),
    );
  }

  Widget _buildTabKasir(List<String> sortedKelas, Map<String, List<Map<String, dynamic>>> groupedByKelas) {
    return RefreshIndicator(
      onRefresh: _fetchDataAwal,
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), color: Colors.white, child: TextField(decoration: InputDecoration(hintText: 'Cari Nama / Kelas...', prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0)), onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()))),
          Expanded(
            child: sortedKelas.isEmpty ? const Center(child: Text('Tidak ada data siswa.', style: TextStyle(color: Colors.grey))) : ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: sortedKelas.length,
              itemBuilder: (context, index) {
                final kelas = sortedKelas[index]; final listSiswaKelas = groupedByKelas[kelas] ?? [];
                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                  child: ExpansionTile(
                    leading: const Icon(Icons.folder_shared_rounded, color: Colors.amber, size: 36), title: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold)),
                    children: listSiswaKelas.map((siswa) {
                      return Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), leading: const CircleAvatar(backgroundColor: Color(0xFFE6FFFA), child: Icon(Icons.person, color: Colors.teal)), title: Text((siswa['full_name'] ?? 'Tanpa Nama').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: () {
                              if (siswa['id'] == null) { PopupService.show(context, 'Data tidak valid.', isSuccess: false); return; }
                              Navigator.push(context, MaterialPageRoute(builder: (context) => DetailKasirScreen(siswaData: siswa, userRole: widget.userRole))).then((_) => _fetchDataAwal());
                            },
                            child: Text(_isKepsek ? 'Lihat Laporan' : 'Buka Kasir'),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabVerifikasi() {
    return RefreshIndicator(
      onRefresh: _fetchDataAwal,
      child: _listVerifikasi.isEmpty ? ListView(children: const [SizedBox(height: 100), Center(child: Text('Tidak ada pembayaran tertunda.', style: TextStyle(color: Colors.grey)))]) : ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: _listVerifikasi.length,
        itemBuilder: (context, index) {
          final bayar = _listVerifikasi[index]; final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
          final dataSiswa = _listSiswa.firstWhere((s) => s['id'] == bayar['siswa_id'], orElse: () => {'full_name': 'Siswa Tidak Ditemukan', 'kelas': '-'});
          final fotoBukti = bayar['foto_bukti']; final nominal = bayar['nominal'] ?? 0; final jenisPembayaran = (bayar['jenis_pembayaran'] ?? '-').toString(); final bulanTagihan = (bayar['bulan_tagihan'] ?? '-').toString(); final idBayar = bayar['id']?.toString();

          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text((dataSiswa['full_name'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)), child: const Text('MENUNGGU ACC', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)))]),
                  Text('Kelas ${(dataSiswa['kelas'] ?? '-').toString()}', style: const TextStyle(fontSize: 12, color: Colors.grey)), const Divider(), Text('$jenisPembayaran${bulanTagihan != '-' ? ' ($bulanTagihan)' : ''}', style: const TextStyle(fontWeight: FontWeight.bold)), Text(formatter.format(nominal), style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12),
                  if (fotoBukti != null && fotoBukti.toString().isNotEmpty) Container(height: 180, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoBukti.toString(), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey))))),
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red), onPressed: idBayar == null ? null : () => _verifikasiTolak(idBayar), child: const Text('TOLAK'))), const SizedBox(width: 8), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: idBayar == null ? null : () => _verifikasiTerima(idBayar), child: const Text('TERIMA (LUNAS)', style: TextStyle(color: Colors.white))))]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// 4. DETAIL KASIR DENGAN DUKUNGAN READ-ONLY UNTUK KEPSEK
// =========================================================================
class DetailKasirScreen extends StatefulWidget {
  final Map<String, dynamic> siswaData;
  final String userRole;

  const DetailKasirScreen({super.key, required this.siswaData, this.userRole = 'admin'});

  @override
  State<DetailKasirScreen> createState() => _DetailKasirScreenState();
}

class _DetailKasirScreenState extends State<DetailKasirScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _riwayatBayar = [];

  final List<String> _kategoriFolder = ['SPP Bulanan', 'Semester (PTS/PAS)', 'LKS', 'Seragam', 'Kegiatan PKL', 'Daftar Ulang', 'Lainnya'];
  final Map<String, int> _hargaTagihan = {'SPP Bulanan': 250000, 'Semester (PTS/PAS)': 200000, 'LKS': 300000, 'Seragam': 850000, 'Kegiatan PKL': 400000, 'Daftar Ulang': 1500000, 'Lainnya': 0};
  final List<String> _listBulan = ['-', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  @override
  void initState() {
    super.initState();
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('pembayaran').select('*').eq('siswa_id', widget.siswaData['id']).order('created_at', ascending: false);
      if (mounted) { setState(() { _riwayatBayar = List<Map<String, dynamic>>.from(res); _isLoading = false; }); }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); PopupService.show(context, 'Gagal memuat riwayat.', isSuccess: false); }
    }
  }

  void _bukaDialogInputBayar() {
    if (widget.userRole.contains('kepsek')) return;
    String selectedJenis = 'SPP Bulanan'; String selectedBulan = '-';
    final nominalCtrl = TextEditingController(text: _hargaTagihan['SPP Bulanan'].toString());
    final keteranganCtrl = TextEditingController();

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final bool isSPP = selectedJenis.contains('SPP');
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Input Terima Uang / Kasir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(value: selectedJenis, decoration: const InputDecoration(labelText: 'Jenis Tagihan', border: OutlineInputBorder()), items: _hargaTagihan.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (val) { if (val != null) setStateDialog(() { selectedJenis = val; nominalCtrl.text = (_hargaTagihan[val] ?? 0).toString(); if (!val.contains('SPP')) selectedBulan = '-'; }); }), const SizedBox(height: 12),
                    if (isSPP) ...[DropdownButtonFormField<String>(value: selectedBulan, decoration: const InputDecoration(labelText: 'Pembayaran Bulan', border: OutlineInputBorder()), items: _listBulan.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(), onChanged: (val) { if (val != null) setStateDialog(() => selectedBulan = val); }), const SizedBox(height: 12)],
                    TextField(controller: nominalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal (Rp)', prefixText: 'Rp ', border: OutlineInputBorder())), const SizedBox(height: 12),
                    TextField(controller: keteranganCtrl, decoration: const InputDecoration(labelText: 'Keterangan Opsional', border: OutlineInputBorder())),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                  onPressed: () {
                    final nominalBersih = nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                    if (nominalBersih.isEmpty || int.tryParse(nominalBersih) == null) { PopupService.show(context, 'Nominal tidak valid.', isSuccess: false); return; }
                    if (isSPP && selectedBulan == '-') { PopupService.show(context, 'Pilih bulan pembayaran SPP.', isSuccess: false); return; }
                    String tagihanFinal = selectedBulan != '-' ? 'Bulan $selectedBulan' : '';
                    if (keteranganCtrl.text.trim().isNotEmpty) { tagihanFinal += tagihanFinal.isNotEmpty ? ' - ${keteranganCtrl.text.trim()}' : keteranganCtrl.text.trim(); }
                    if (tagihanFinal.isEmpty) tagihanFinal = '-';
                    Navigator.pop(context); _prosesSimpanPembayaran(selectedJenis, nominalCtrl.text, tagihanFinal);
                  },
                  child: const Text('Simpan LUNAS', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _prosesSimpanPembayaran(String jenis, String nominalStr, String keterangan) async {
    if (widget.userRole.contains('kepsek')) return;
    setState(() => _isLoading = true);
    try {
      final nominalBersih = nominalStr.replaceAll(RegExp(r'[^0-9]'), '');
      await _supabase.from('pembayaran').insert({'siswa_id': widget.siswaData['id'], 'jenis_pembayaran': jenis, 'bulan_tagihan': keterangan, 'nominal': int.parse(nominalBersih), 'status': 'LUNAS', 'tanggal_bayar': DateTime.now().toIso8601String(), 'penerima': _supabase.auth.currentUser?.email ?? 'Admin TU'});
      await _fetchRiwayat(); if (mounted) PopupService.show(context, 'Tercatat LUNAS!', isSuccess: true);
    } catch (e) {
      if (mounted) { PopupService.show(context, 'Gagal menyimpan.', isSuccess: false); setState(() => _isLoading = false); }
    }
  }

  void _bukaDialogHistoriTagihan(String kategori, List<Map<String, dynamic>> listBayar, int totalMasuk, int kewajiban) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final int sisaKurang = (kewajiban - totalMasuk) > 0 ? (kewajiban - totalMasuk) : 0;
    final bool isLunas = sisaKurang == 0 && totalMasuk > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(isLunas ? Icons.check_circle : Icons.warning_amber_rounded, color: isLunas ? Colors.green : Colors.orange), const SizedBox(width: 10), Expanded(child: Text('Riwayat: $kategori', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isLunas ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isLunas ? Colors.green.shade200 : Colors.orange.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Kewajiban: ${formatter.format(kewajiban)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('Sudah Dibayar: ${formatter.format(totalMasuk)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade800)), Text('Sisa Kekurangan: ${formatter.format(sisaKurang)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isLunas ? Colors.green.shade900 : Colors.red.shade700) )])),
              const SizedBox(height: 16), const Text('Daftar Tanggal & Jam Pembayaran:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Divider(),
              if (listBayar.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Belum ada transaksi.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))) else ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: listBayar.length, itemBuilder: (context, i) {
                final b = listBayar[i]; final rawDate = (b['tanggal_bayar'] ?? b['created_at'] ?? '').toString(); String tglTampil = rawDate; try { if (rawDate.isNotEmpty) tglTampil = DateFormat('dd MMMM yyyy - HH:mm WIB').format(DateTime.parse(rawDate).toLocal()); } catch (_) {}
                return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(formatter.format(b['nominal'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 14)), IconButton(icon: const Icon(Icons.print, color: Colors.red, size: 18), onPressed: () {})]), const SizedBox(height: 4), Text('Waktu: $tglTampil', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), Text('Keterangan: ${b['bulan_tagihan'] ?? '-'} | Kasir: ${b['penerima'] ?? 'Admin'}', style: const TextStyle(fontSize: 11, color: Colors.grey))]));
              })
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isKepsek = widget.userRole.contains('kepsek');
    final Map<String, List<Map<String, dynamic>>> groupedRiwayat = {};
    for (var bayar in _riwayatBayar) { groupedRiwayat.putIfAbsent((bayar['jenis_pembayaran'] ?? 'Lainnya').toString(), () => []).add(bayar); }
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(isKepsek ? 'Laporan Kasir' : 'Detail Kasir Keuangan', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, iconTheme: const IconThemeData(color: Colors.black)),
      floatingActionButton: isKepsek ? null : FloatingActionButton.extended(backgroundColor: Colors.blue.shade900, icon: const Icon(Icons.add_card, color: Colors.white), label: const Text('Input Terima Uang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: _bukaDialogInputBayar),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _fetchRiwayat,
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))), child: Row(children: [const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE6FFFA), child: Icon(Icons.person, color: Colors.teal, size: 28)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((widget.siswaData['full_name'] ?? '-').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('NISN: ${(widget.siswaData['nisn'] ?? '-')} | Kelas: ${(widget.siswaData['kelas'] ?? '-')}', style: const TextStyle(color: Colors.grey, fontSize: 13))]))])),
            const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Daftar Kewajiban & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))))),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _kategoriFolder.length,
                itemBuilder: (context, index) {
                  final namaKategori = _kategoriFolder[index]; final listBayarKategori = groupedRiwayat[namaKategori] ?? [];
                  double totalMasuk = 0; for (var b in listBayarKategori) { if ((b['status'] ?? '') == 'LUNAS') { totalMasuk += (b['nominal'] is num) ? (b['nominal'] as num).toDouble() : 0; } }
                  final int kewajiban = _hargaTagihan[namaKategori] ?? 0; final int sisa = (kewajiban - totalMasuk.toInt()) > 0 ? (kewajiban - totalMasuk.toInt()) : 0; final bool isLunas = sisa == 0 && totalMasuk > 0;

                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isLunas ? Colors.green.shade400 : Colors.grey.shade300, width: isLunas ? 1.5 : 1.0)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16), onTap: () => _bukaDialogHistoriTagihan(namaKategori, listBayarKategori, totalMasuk.toInt(), kewajiban),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 24, backgroundColor: isLunas ? Colors.green.shade100 : Colors.orange.shade100, child: Icon(isLunas ? Icons.check_circle : Icons.warning_amber_rounded, color: isLunas ? Colors.green.shade800 : Colors.orange.shade800, size: 28)), const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(namaKategori, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))), const SizedBox(height: 4), Text(isLunas ? 'LUNAS SEPENUHNYA' : (totalMasuk > 0 ? 'BELUM LUNAS (Sisa: ${formatter.format(sisa)})' : 'BELUM ADA PEMBAYARAN'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isLunas ? Colors.green.shade700 : Colors.orange.shade800))])),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                          ],
                        ),
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

// =========================================================================
// 🔥 HALAMAN BARU: ABSENSI MANUAL GURU INVAL (TATA USAHA & ADMIN)
// =========================================================================
class AbsensiManualInvalScreen extends StatefulWidget {
  const AbsensiManualInvalScreen({super.key});

  @override
  State<AbsensiManualInvalScreen> createState() => _AbsensiManualInvalScreenState();
}

class _AbsensiManualInvalScreenState extends State<AbsensiManualInvalScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<String> _listKelas = [];
  List<String> _listGuru = [];
  List<Map<String, dynamic>> _listJadwalHariIni = [];
  List<Map<String, dynamic>> _listSiswa = [];

  String? _selectedKelas;
  Map<String, dynamic>? _selectedJadwal;
  String? _selectedGuruPengganti;

  Map<String, String> _statusAbsensi = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  String _getNamaHariIni() {
    final now = DateTime.now();
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return hari[now.weekday - 1];
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final resProfiles = await _supabase.from('profiles').select('kelas, role, full_name');
      Set<String> kelasSet = {}; List<String> guruList = [];

      for (var p in resProfiles) {
        if (p['role'] == 'siswa' && p['kelas'] != null && p['kelas'].toString().isNotEmpty) { kelasSet.add(p['kelas'].toString()); } 
        else if (p['role'] == 'guru' && p['full_name'] != null) { guruList.add(p['full_name'].toString()); }
      }

      setState(() { _listKelas = kelasSet.toList()..sort(); _listGuru = guruList..sort(); _isLoading = false; });
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal memuat data awal: $e', isSuccess: false);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onKelasChanged(String kelas) async {
    setState(() { _isLoading = true; _selectedKelas = kelas; _selectedJadwal = null; _listJadwalHariIni = []; _listSiswa = []; _statusAbsensi.clear(); });
    try {
      final hariIni = _getNamaHariIni();
      final resJadwal = await _supabase.from('jadwal').select('*').eq('kelas', kelas).eq('hari', hariIni).order('jam_mulai', ascending: true);
      final resSiswa = await _supabase.from('profiles').select('id, full_name, nisn').eq('role', 'siswa').eq('kelas', kelas).order('full_name', ascending: true);

      List<Map<String, dynamic>> jadwalReal = [];
      for (var j in resJadwal) {
        String mapel = (j['mata_pelajaran'] ?? '').toString().toLowerCase();
        if (!mapel.contains('istirahat') && !mapel.contains('ishoma')) { jadwalReal.add(j); }
      }

      setState(() { _listJadwalHariIni = jadwalReal; _listSiswa = List<Map<String, dynamic>>.from(resSiswa); for (var s in _listSiswa) { _statusAbsensi[s['id'].toString()] = 'Hadir'; } _isLoading = false; });
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal mengambil data kelas: $e', isSuccess: false);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simpanAbsensiInval() async {
    if (_selectedKelas == null || _selectedJadwal == null || _selectedGuruPengganti == null) { PopupService.show(context, 'Pilih Kelas, Jadwal, dan Guru Pengganti terlebih dahulu!', isSuccess: false); return; }
    if (_listSiswa.isEmpty) { PopupService.show(context, 'Tidak ada siswa di kelas ini.', isSuccess: false); return; }

    setState(() => _isLoading = true);
    try {
      String tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String waktu = DateFormat('HH:mm:ss').format(DateTime.now());
      String guruAsli = _selectedJadwal!['guru_pengampu'] ?? '-';
      String mapel = _selectedJadwal!['mata_pelajaran'] ?? '-';
      String guruPengampuTercatat = '$_selectedGuruPengganti (Inval: $guruAsli)';

      List<Map<String, dynamic>> batchInsert = [];
      for (var s in _listSiswa) {
        String sId = s['id'].toString();
        batchInsert.add({ 'siswa_id': sId, 'tanggal': tanggal, 'waktu_absen': waktu, 'status': _statusAbsensi[sId], 'mapel': mapel, 'guru_pengampu': guruPengampuTercatat, 'keterangan': 'Diinput manual oleh TU (Guru Pengganti)', 'status_verifikasi': 'Disetujui' });
      }

      await _supabase.from('absensi').insert(batchInsert);
      if (mounted) { Navigator.pop(context); PopupService.show(context, 'Absensi Inval Berhasil Disimpan!', isSuccess: true); }
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal menyimpan absensi: $e', isSuccess: false);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String hariIni = _getNamaHariIni();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Input Absensi Manual (Inval)', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF))) : Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.info_outline_rounded, color: Colors.blue.shade800, size: 20), const SizedBox(width: 8), Expanded(child: Text('Hari ini: $hariIni. Pilih kelas, jadwal yang kosong, lalu tunjuk guru penggantinya.', style: TextStyle(fontSize: 12, color: Colors.blue.shade900)))])), const SizedBox(height: 16),
                DropdownButtonFormField<String>(value: _selectedKelas, decoration: const InputDecoration(labelText: 'Pilih Kelas', border: OutlineInputBorder()), items: _listKelas.map((k) => DropdownMenuItem(value: k, child: Text('Kelas $k'))).toList(), onChanged: (val) { if (val != null) _onKelasChanged(val); }), const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>>(value: _selectedJadwal, decoration: const InputDecoration(labelText: 'Pilih Jadwal / Mata Pelajaran', border: OutlineInputBorder()), items: _listJadwalHariIni.map((j) { String jam = (j['jam_mulai'] ?? '').toString().substring(0, 5); return DropdownMenuItem(value: j, child: Text('$jam - ${j['mata_pelajaran']} (${j['guru_pengampu']})', style: const TextStyle(fontSize: 12))); }).toList(), onChanged: _selectedKelas == null || _listJadwalHariIni.isEmpty ? null : (val) => setState(() => _selectedJadwal = val), hint: Text(_selectedKelas == null ? 'Pilih kelas dulu' : (_listJadwalHariIni.isEmpty ? 'Tidak ada jadwal hari ini' : 'Pilih Jadwal'))), const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: _selectedGuruPengganti, decoration: const InputDecoration(labelText: 'Pilih Guru Pengganti (Inval)', border: OutlineInputBorder()), items: _listGuru.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: _selectedJadwal == null ? null : (val) => setState(() => _selectedGuruPengganti = val), hint: Text(_selectedJadwal == null ? 'Pilih jadwal dulu' : 'Pilih Guru Pengganti')),
              ],
            ),
          ),
          Expanded(
            child: _selectedGuruPengganti == null ? Center(child: Text('Lengkapi form di atas untuk memunculkan daftar siswa.', style: TextStyle(color: Colors.grey.shade600))) : _listSiswa.isEmpty ? Center(child: Text('Tidak ada data siswa di kelas $_selectedKelas', style: TextStyle(color: Colors.grey.shade600))) : ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: _listSiswa.length,
              itemBuilder: (context, index) {
                final s = _listSiswa[index]; final sId = s['id'].toString(); final currentStatus = _statusAbsensi[sId] ?? 'Hadir';
                return Card(
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)), margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Hadir', 'Izin', 'Sakit', 'Alfa'].map((status) {
                              bool isSelected = currentStatus == status; Color activeColor = Colors.blue; if (status == 'Hadir') activeColor = Colors.green; else if (status == 'Alfa') activeColor = Colors.red; else if (status == 'Izin') activeColor = Colors.orange;
                              return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(status, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)), selected: isSelected, selectedColor: activeColor, onSelected: (val) { if (val) setState(() => _statusAbsensi[sId] = status); }));
                            }).toList(),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedGuruPengganti != null && _listSiswa.isNotEmpty ? Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]), child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _simpanAbsensiInval, icon: const Icon(Icons.save_rounded), label: const Text('SIMPAN ABSENSI INVAL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)))) : null,
    );
  }
}

// =========================================================================
// 🔥 HALAMAN BARU: MANAJEMEN KEHADIRAN & IZIN GURU
// =========================================================================
class KehadiranGuruScreen extends StatefulWidget {
  final String userRole;
  const KehadiranGuruScreen({super.key, this.userRole = 'admin'});

  @override
  State<KehadiranGuruScreen> createState() => _KehadiranGuruScreenState();
}

class _KehadiranGuruScreenState extends State<KehadiranGuruScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _listGuru = [];
  Map<String, String> _statusGuru = {};
  Map<String, TextEditingController> _keteranganGuru = {};
  String _searchQuery = '';

  List<Map<String, dynamic>> _historiGuru = [];

  @override
  void initState() {
    super.initState();
    _fetchGuruDanHistori();
  }

  Future<void> _fetchGuruDanHistori() async {
    setState(() => _isLoading = true);
    try {
      final resProfiles = await _supabase.from('profiles').select('*').eq('role', 'guru').order('full_name', ascending: true);
      final String tanggalHariIni = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final resAbsenHariIni = await _supabase.from('absensi').select('*').eq('tanggal', tanggalHariIni).eq('mapel', 'Absensi Guru');
      final resHistori = await _supabase.from('absensi').select('*, profiles(full_name)').eq('mapel', 'Absensi Guru').neq('status', 'Hadir').order('tanggal', ascending: false);

      setState(() {
        _listGuru = List<Map<String, dynamic>>.from(resProfiles);
        for (var g in _listGuru) {
          String gId = g['id'].toString();
          var existingAbsen;
          try { existingAbsen = resAbsenHariIni.firstWhere((a) => a['siswa_id'].toString() == gId); } catch (_) {}

          if (existingAbsen != null) {
            _statusGuru[gId] = existingAbsen['status'];
            _keteranganGuru[gId] = TextEditingController(text: existingAbsen['keterangan'] ?? '');
          } else {
            _statusGuru[gId] = 'Hadir';
            _keteranganGuru[gId] = TextEditingController();
          }
        }
        _historiGuru = List<Map<String, dynamic>>.from(resHistori);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal memuat data: $e', isSuccess: false);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simpanKehadiranGuru() async {
    if (widget.userRole.contains('kepsek')) return;
    setState(() => _isLoading = true);
    try {
      String tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String waktu = DateFormat('HH:mm:ss').format(DateTime.now());
      List<String> listIdGuru = _listGuru.map((g) => g['id'].toString()).toList();

      if (listIdGuru.isNotEmpty) {
        await _supabase.from('absensi').delete().eq('tanggal', tanggal).eq('mapel', 'Absensi Guru').filter('siswa_id', 'in', listIdGuru);
      }

      List<Map<String, dynamic>> batchInsert = [];
      for (var g in _listGuru) {
        String gId = g['id'].toString();
        String status = _statusGuru[gId] ?? 'Hadir';
        String ket = _keteranganGuru[gId]?.text.trim() ?? '';

        batchInsert.add({
          'siswa_id': gId, 'tanggal': tanggal, 'waktu_absen': waktu, 'status': status, 'mapel': 'Absensi Guru', 'guru_pengampu': 'Tata Usaha', 'keterangan': ket, 'status_verifikasi': 'Disetujui',
        });
      }

      if (batchInsert.isNotEmpty) {
        await _supabase.from('absensi').insert(batchInsert);
      }

      if (mounted) {
        PopupService.show(context, 'Kehadiran Guru berhasil disimpan!', isSuccess: true);
        _fetchGuruDanHistori();
      }
    } catch (e) {
      if (mounted) PopupService.show(context, 'Gagal menyimpan: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isKepsek = widget.userRole.contains('kepsek');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(isKepsek ? 'Pantauan Kehadiran Guru' : 'Kehadiran & Izin Guru', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          bottom: TabBar(labelColor: Colors.teal.shade900, indicatorColor: Colors.teal.shade900, tabs: const [Tab(text: 'Daftar Hari Ini'), Tab(text: 'Histori Izin/Sakit')]),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.teal)) 
          : TabBarView(children: [_buildTabInput(isKepsek), _buildTabHistori()]),
      ),
    );
  }

  Widget _buildTabInput(bool isKepsek) {
    final filteredGuru = _listGuru.where((g) {
      if (_searchQuery.isEmpty) return true;
      return (g['full_name'] ?? '').toString().toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16), color: Colors.white,
          child: TextField(decoration: InputDecoration(hintText: 'Cari Nama Guru...', prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0)), onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase())),
        ),
        Expanded(
          child: filteredGuru.isEmpty ? const Center(child: Text('Data guru tidak ditemukan.', style: TextStyle(color: Colors.grey))) : ListView.builder(
            padding: const EdgeInsets.all(16), itemCount: filteredGuru.length,
            itemBuilder: (context, index) {
              final g = filteredGuru[index]; final gId = g['id'].toString(); final currentStatus = _statusGuru[gId] ?? 'Hadir';

              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const CircleAvatar(backgroundColor: Color(0xFFE6FFFA), child: Icon(Icons.supervisor_account_rounded, color: Colors.teal)), const SizedBox(width: 12), Expanded(child: Text(g['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))]),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Hadir', 'Izin', 'Sakit', 'Alfa'].map((status) {
                            bool isSelected = currentStatus == status; Color activeColor = Colors.blue; if (status == 'Hadir') activeColor = Colors.green; else if (status == 'Alfa') activeColor = Colors.red; else if (status == 'Izin') activeColor = Colors.orange;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(status, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12)),
                                selected: isSelected, selectedColor: activeColor,
                                onSelected: isKepsek ? null : (val) { if (val) setState(() => _statusGuru[gId] = status); },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (currentStatus == 'Izin' || currentStatus == 'Sakit') ...[
                        const SizedBox(height: 12),
                        TextField(enabled: !isKepsek, controller: _keteranganGuru[gId], decoration: InputDecoration(labelText: 'Keterangan (Surat/Alasan)', labelStyle: const TextStyle(fontSize: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!isKepsek) Container(
          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
          child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _simpanKehadiranGuru, icon: const Icon(Icons.save_rounded), label: const Text('SIMPAN KEHADIRAN HARI INI', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5))),
        ),
      ],
    );
  }

  Widget _buildTabHistori() {
    if (_historiGuru.isEmpty) return const Center(child: Text('Belum ada histori izin/sakit guru.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: _historiGuru.length,
      itemBuilder: (context, index) {
        final h = _historiGuru[index]; final nama = h['profiles'] != null ? h['profiles']['full_name'] : 'Nama Tidak Diketahui'; final tgl = h['tanggal'] ?? '-'; final status = h['status'] ?? '-'; final ket = h['keterangan'] ?? '-';
        Color warnaStatus = Colors.blue; if (status == 'Sakit') warnaStatus = Colors.blue; if (status == 'Izin') warnaStatus = Colors.orange; if (status == 'Alfa') warnaStatus = Colors.red;

        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: warnaStatus.withOpacity(0.2), child: Icon(Icons.info_outline, color: warnaStatus)),
            title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 4), Text('Tanggal: $tgl', style: const TextStyle(fontSize: 12, color: Colors.black87)), Text('Keterangan: $ket', style: const TextStyle(fontSize: 12, color: Colors.grey))]),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: warnaStatus.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status, style: TextStyle(color: warnaStatus, fontWeight: FontWeight.bold, fontSize: 12))),
          ),
        );
      },
    );
  }
}