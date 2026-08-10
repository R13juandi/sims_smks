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

class _SiswaDashboardState extends State<SiswaDashboard> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _biodataSiswa = {};
  
  List<Map<String, dynamic>> _allJadwalDB = []; 
  List<Map<String, dynamic>> _allJadwalAktif = [];
  List<Map<String, dynamic>> _jadwalHariIni = [];

  Map<String, String> _mapNamaGuru = {};
  List<Map<String, dynamic>> _listJadwalPengganti = [];

  @override
  void initState() {
    super.initState();
    _loadSiswaData();
  }

  String _getNamaHariIni() {
    final now = DateTime.now();
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return hari[now.weekday - 1];
  }

  Future<void> _loadSiswaData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() { _isLoading = false; _errorMessage = 'Sesi login tidak ditemukan.'; });
        return;
      }

      final profileRes = await _supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
      _biodataSiswa = profileRes ?? {};

      final resGuru = await _supabase.from('profiles').select('id, full_name');
      for (var g in resGuru) { _mapNamaGuru[g['id'].toString()] = g['full_name'].toString(); }

      final String tglHariIni = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final resPengganti = await _supabase.from('jadwal_pengganti').select('*').eq('tanggal', tglHariIni);
      _listJadwalPengganti = List<Map<String, dynamic>>.from(resPengganti);

      final jadwalRes = await _supabase.from('jadwal').select('*').order('jam_mulai', ascending: true);
      _allJadwalDB = List<Map<String, dynamic>>.from(jadwalRes as List);

      int currentYear = DateTime.now().year;
      int currentMonth = DateTime.now().month;
      int startTa = currentMonth >= 7 ? currentYear : currentYear - 1;
      String activeTa = "$startTa/${startTa + 1}";
      String activeSmt = currentMonth >= 7 ? "Ganjil" : "Genap";

      final kelasSiswa = (_biodataSiswa['kelas'] ?? '').toString();

      _allJadwalAktif = _allJadwalDB.where((j) {
        String dbKelas = (j['kelas'] ?? '').toString().toLowerCase().trim();
        String tKelas = kelasSiswa.toLowerCase().trim();
        bool matchKelas = dbKelas.contains(tKelas) || tKelas.contains(dbKelas);
        bool matchSmt = (j['semester'] ?? '').toString().toLowerCase().contains(activeSmt.toLowerCase());
        bool matchTa = (j['tahun_ajaran'] ?? '').toString().contains(activeTa);
        return matchKelas && matchSmt && matchTa;
      }).toList();

      final hariIni = _getNamaHariIni();
      
      List<Map<String, dynamic>> tempJadwalHariIni = _allJadwalAktif.where((j) => (j['hari'] ?? '') == hariIni).toList();

      List<Map<String, dynamic>> finalJadwalHariIni = [];
      for (var j in tempJadwalHariIni) {
        Map<String, dynamic> jadwalBaru = Map.from(j);
        String guruAsli = j['guru_pengampu'] ?? 'Guru Asli';
        jadwalBaru['guru_tampil'] = guruAsli;
        jadwalBaru['is_infal'] = false;

        try {
          var pengganti = _listJadwalPengganti.firstWhere((p) => p['jadwal_id'].toString() == j['id'].toString());
          String namaPengganti = _mapNamaGuru[pengganti['guru_pengganti_id'].toString()] ?? 'Guru Pengganti';
          jadwalBaru['guru_tampil'] = '$namaPengganti (Infal: $guruAsli)';
          jadwalBaru['is_infal'] = true;
        } catch (_) {}

        finalJadwalHariIni.add(jadwalBaru);
      }

      _jadwalHariIni = finalJadwalHariIni;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _errorMessage = 'Gagal memuat data. Periksa koneksi internet Anda.'; });
        PopupService.show(context, 'Gagal memuat data dashboard: $e', isSuccess: false, judul: 'Koneksi Bermasalah');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))));
    
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400), const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)), const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadSiswaData, child: const Text('Coba Lagi')),
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
    final fotoProfil = (_biodataSiswa['foto_profil'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('SIMS SMK TI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.8, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white, elevation: 0.5,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.power_settings_new_rounded, color: Colors.red[600], size: 18), tooltip: 'Keluar Aplikasi',
              onPressed: () {
                PopupService.showConfirm(
                  context, 'Apakah Anda yakin ingin keluar dari akun Siswa ini?', judul: 'Konfirmasi Keluar',
                  onConfirm: () async {
                    await _supabase.auth.signOut();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            Card(
              elevation: 0, shadowColor: const Color(0xFF1E3A8A).withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailProfilSiswaScreen(biodata: _biodataSiswa))),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 35, backgroundColor: Colors.white24,
                        backgroundImage: fotoProfil.isNotEmpty ? NetworkImage(fotoProfil) : null,
                        child: fotoProfil.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Selamat Datang Kembali,', style: TextStyle(fontSize: 13, color: Colors.white70)), const SizedBox(height: 4),
                            Text(namaLengkap, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)), const SizedBox(height: 12),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(30)), child: Text('Kelas $kelas  •  NISN $nisn', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Aksi Cepat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.25,
              children: [
                _buildMenuCard(icon: Icons.camera_front_rounded, color: Colors.blue.shade600, title: 'Presensi\n& Rekap', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AbsensiSiswaScreen()))),
                _buildMenuCard(
                  icon: Icons.analytics_rounded, color: Colors.amber.shade700, title: 'Rapor\nSemester',
                  onTap: () {
                    final uid = _supabase.auth.currentUser?.id;
                    if (uid == null) { PopupService.show(context, 'Sesi login tidak ditemukan.', isSuccess: false, judul: 'Akses Gagal'); return; }
                    Navigator.push(context, MaterialPageRoute(builder: (context) => NilaiRaporScreen(siswaId: uid)));
                  },
                ),
                _buildMenuCard(
                  icon: Icons.account_balance_wallet_rounded, color: Colors.teal.shade600, title: 'Tagihan\n& SPP',
                  onTap: () {
                    final uid = _supabase.auth.currentUser?.id;
                    if (uid == null) { PopupService.show(context, 'Sesi login tidak ditemukan.', isSuccess: false, judul: 'Akses Gagal'); return; }
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SiswaAdministrasiScreen(siswaId: uid)));
                  },
                ),
                _buildMenuCard(icon: Icons.calendar_month_rounded, color: Colors.indigo.shade500, title: 'Jadwal\nPelajaran', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JadwalSemingguSiswaScreen(allJadwalDB: _allJadwalDB, biodataSiswa: _biodataSiswa)))),
              ],
            ),
            const SizedBox(height: 32),
            Text('Jadwal Hari Ini ($hariIni)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            _jadwalHariIni.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: const Column(children: [Icon(Icons.auto_stories_outlined, size: 40, color: Color(0xFF94A3B8)), SizedBox(height: 12), Text('Tidak ada jadwal pelajaran aktif hari ini.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500))]),
                  )
                : ListView.builder(
                    physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: _jadwalHariIni.length,
                    itemBuilder: (context, index) {
                      final j = _jadwalHariIni[index];
                      final jamMulaiRaw = (j['jam_mulai'] ?? '00:00').toString();
                      final jamSelesaiRaw = (j['jam_selesai'] ?? '00:00').toString();
                      final jamMulai = jamMulaiRaw.length >= 5 ? jamMulaiRaw.substring(0, 5) : jamMulaiRaw;
                      final jamSelesai = jamSelesaiRaw.length >= 5 ? jamSelesaiRaw.substring(0, 5) : jamSelesaiRaw;
                      final guru = (j['guru_tampil'] ?? j['guru_pengampu'] ?? '-').toString();
                      final bool isInfal = j['is_infal'] ?? false;
                      final mapel = (j['mata_pelajaran'] ?? j['mapel'] ?? '-').toString().toUpperCase();
                      final ruang = (j['ruang_kelas'] ?? 'Lt. 2 - R. 05').toString();
                      final isIstirahat = mapel.contains('ISTIRAHAT') || mapel.contains('ISHOMA');

                      if (isIstirahat) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle), child: Icon(Icons.fastfood, color: Colors.orange.shade800, size: 20)), const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(mapel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange.shade900)), const SizedBox(height: 4), Text('Waktu Istirahat: $jamMulai - $jamSelesai WIB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700))])),
                            ],
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), decoration: BoxDecoration(color: isInfal ? Colors.teal.shade50 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isInfal ? Colors.teal.shade200 : const Color(0xFFF1F5F9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isInfal ? Colors.teal.shade100 : const Color(0xFF3B82F6).withOpacity(0.06), shape: BoxShape.circle), child: Icon(isInfal ? Icons.swap_horiz_rounded : Icons.menu_book_rounded, color: isInfal ? Colors.teal.shade700 : const Color(0xFF3B82F6), size: 20)), const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [Expanded(child: Text(mapel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isInfal ? Colors.teal.shade900 : const Color(0xFF0F172A)))), if (isInfal) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.teal.shade700, borderRadius: BorderRadius.circular(4)), child: const Text('INFAL', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))]), const SizedBox(height: 6),
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(isInfal ? Icons.supervisor_account_rounded : Icons.person_outline_rounded, size: 14, color: isInfal ? Colors.teal.shade700 : const Color(0xFF64748B)), const SizedBox(width: 6), Expanded(child: Text(guru, style: TextStyle(fontSize: 12, color: isInfal ? Colors.teal.shade800 : const Color(0xFF64748B), fontWeight: isInfal ? FontWeight.bold : FontWeight.w500), overflow: TextOverflow.visible))]), const SizedBox(height: 4),
                                  Row(children: [Icon(Icons.room_outlined, size: 14, color: Colors.teal.shade700), const SizedBox(width: 6), Text('Ruang: $ruang', style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.bold))]), const SizedBox(height: 4),
                                  Text('⏰ Waktu: $jamMulai - $jamSelesai WIB', style: TextStyle(fontSize: 11, color: isInfal ? Colors.blue.shade800 : Colors.blue.shade700, fontWeight: FontWeight.bold)),
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

  Widget _buildMenuCard({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(20), elevation: 2, shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 28)), const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// JADWAL SEMINGGU SISWA (PERBAIKAN REGEX "I" & FILTER HISTORI)
// =========================================================================
class JadwalSemingguSiswaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allJadwalDB; 
  final Map<String, dynamic> biodataSiswa;

  const JadwalSemingguSiswaScreen({
    super.key, 
    required this.allJadwalDB, 
    required this.biodataSiswa
  });

  @override
  State<JadwalSemingguSiswaScreen> createState() =>
      _JadwalSemingguSiswaScreenState();
}

class _JadwalSemingguSiswaScreenState extends State<JadwalSemingguSiswaScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _jadwalTerpilih = [];

  String _selectedPeriodeLabel = '';
  List<Map<String, String>> _daftarPeriodeHistori = [];
  
  final List<String> _listHari = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu',
  ];

  @override
  void initState() {
    super.initState();
    _generateDaftarPeriode();
  }

  void _generateDaftarPeriode() {
    int currentYear = DateTime.now().year;
    int currentMonth = DateTime.now().month;
    int startTa = currentMonth >= 7 ? currentYear : currentYear - 1;
    int activeSmtVal = currentMonth >= 7 ? 1 : 2; 

    String kelasSiswa = (widget.biodataSiswa['kelas'] ?? 'X TKJ').toString();
    int tingkat = 10;
    if (kelasSiswa.toUpperCase().contains('XII') || kelasSiswa.contains('12')) tingkat = 12;
    else if (kelasSiswa.toUpperCase().contains('XI') || kelasSiswa.contains('11')) tingkat = 11;

    String suffix = kelasSiswa.replaceAll(RegExp(r'^(XII|XI|X|12|11|10)\s*', caseSensitive: false), '').trim();
    if (suffix.isEmpty) suffix = 'TKJ';

    List<Map<String, String>> periods = [];
    int tempTingkat = tingkat;
    int tempSmt = activeSmtVal;
    int tempStartTa = startTa;

    while(tempTingkat >= 10) {
        String strTingkat = tempTingkat == 12 ? 'XII' : (tempTingkat == 11 ? 'XI' : 'X');
        String targetKelas = "$strTingkat $suffix";
        String taStr = "$tempStartTa/${tempStartTa+1}";
        String smtStr = tempSmt == 1 ? 'Ganjil' : 'Genap';
        bool isAktif = (tempTingkat == tingkat && tempSmt == activeSmtVal && tempStartTa == startTa);

        periods.add({
            'label': '$targetKelas - $smtStr $taStr ${isAktif ? '(Aktif)' : '(Histori)'}',
            'kelas': targetKelas,
            'semester': smtStr,
            'tahun_ajaran': taStr,
            'is_aktif': isAktif ? 'true' : 'false'
        });

        if (tempSmt == 2) {
            tempSmt = 1;
        } else {
            tempSmt = 2;
            tempStartTa--;
            tempTingkat--;
        }
    }

    setState(() {
        _daftarPeriodeHistori = periods;
        _selectedPeriodeLabel = periods.first['label']!;
    });
    
    _filterJadwalLokal(periods.first);
  }

  void _filterJadwalLokal(Map<String, String> period) {
    setState(() => _isLoading = true);
    
    String tKelas = period['kelas']!.toLowerCase().trim();
    String tSmt = period['semester']!.toLowerCase();
    String tTa = period['tahun_ajaran']!;
    bool isAktif = period['is_aktif'] == 'true';

    List<Map<String, dynamic>> hasil = widget.allJadwalDB.where((j) {
        String dbKelas = (j['kelas'] ?? '').toString().toLowerCase().trim();
        String dbSmt = (j['semester'] ?? '').toString().toLowerCase();
        String dbTa = (j['tahun_ajaran'] ?? '').toString();

        bool matchKelas = dbKelas.contains(tKelas) || tKelas.contains(dbKelas);
        bool matchSmt = dbSmt.contains(tSmt);
        bool matchTa = dbTa.contains(tTa);

        return matchKelas && matchSmt && matchTa;
    }).toList();

    if (hasil.isEmpty && isAktif) {
        hasil = widget.allJadwalDB.where((j) {
            String dbKelas = (j['kelas'] ?? '').toString().toLowerCase().trim();
            String dbSmt = (j['semester'] ?? '').toString().toLowerCase();
            bool matchKelas = dbKelas.contains(tKelas) || tKelas.contains(dbKelas);
            bool matchSmt = dbSmt.contains(tSmt);
            return matchKelas && matchSmt; 
        }).toList();
    }

    setState(() {
        _jadwalTerpilih = hasil;
        _isLoading = false;
    });
  }

  String _getNamaHariIni() {
    final now = DateTime.now();
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return hari[now.weekday - 1];
  }

  void _showDialogHistoriJadwal() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.history_edu_rounded, color: Color(0xFF1E40AF), size: 28),
              SizedBox(width: 12),
              Text('Pilih Histori Jadwal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _daftarPeriodeHistori.length,
              itemBuilder: (context, index) {
                final item = _daftarPeriodeHistori[index];
                final String label = item['label']!;
                final bool isSelected = _selectedPeriodeLabel == label;
                final bool isAktif = item['is_aktif'] == 'true';

                return Card(
                  elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? const Color(0xFF1E40AF) : Colors.grey.shade300, width: isSelected ? 2 : 1)),
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  child: ListTile(
                    dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(isAktif ? Icons.calendar_month_rounded : Icons.history_rounded, color: isSelected ? const Color(0xFF1E40AF) : Colors.grey),
                    title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: isSelected ? const Color(0xFF1E40AF) : Colors.black87)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF1E40AF), size: 20) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!isSelected) { setState(() => _selectedPeriodeLabel = label); _filterJadwalLokal(item); }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hariIni = _getNamaHariIni();
    bool isHistoriView = !_selectedPeriodeLabel.contains('(Aktif)');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jadwal Pelajaran Mingguan', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_selectedPeriodeLabel, style: TextStyle(fontSize: 11, color: isHistoriView ? Colors.orange.shade800 : Colors.blue.shade800, fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ActionChip(
              onPressed: _showDialogHistoriJadwal,
              avatar: Icon(isHistoriView ? Icons.history_rounded : Icons.filter_list_rounded, size: 16, color: const Color(0xFF1E40AF)),
              label: const Text('Histori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
              backgroundColor: Colors.blue.shade50, side: BorderSide(color: Colors.blue.shade200),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
          : _jadwalTerpilih.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16),
                        Text('Data jadwal pelajaran untuk periode\n"$_selectedPeriodeLabel"\nbelum diinputkan oleh Admin / Tata Usaha ke dalam database.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _listHari.length,
                  itemBuilder: (context, index) {
                    final hari = _listHari[index];
                    final jadwals = _jadwalTerpilih.where((j) => (j['hari'] ?? '') == hari).toList();
                    final bool isHariIni = hari == hariIni && !isHistoriView;

                    if (jadwals.isEmpty && !isHariIni) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isHariIni ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0), width: isHariIni ? 1.5 : 1)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: isHariIni || jadwals.isNotEmpty,
                          leading: Icon(Icons.calendar_today_rounded, size: 24, color: isHariIni ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1)),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(hari, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isHariIni ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B))),
                              if (isHariIni) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(6)), child: const Text('HARI INI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)))),
                            ],
                          ),
                          children: [
                            if (jadwals.isEmpty)
                              const Padding(padding: EdgeInsets.only(bottom: 20), child: Text('Tidak ada jadwal pelajaran', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic)))
                            else
                              ...jadwals.map((j) {
                                final jamMulaiRaw = (j['jam_mulai'] ?? '00:00').toString();
                                final jamSelesaiRaw = (j['jam_selesai'] ?? '00:00').toString();
                                final jamMulai = jamMulaiRaw.length >= 5 ? jamMulaiRaw.substring(0, 5) : jamMulaiRaw;
                                final jamSelesai = jamSelesaiRaw.length >= 5 ? jamSelesaiRaw.substring(0, 5) : jamSelesaiRaw;
                                final guru = (j['guru_pengampu'] ?? j['guru'] ?? '-').toString();
                                final mapel = (j['mata_pelajaran'] ?? j['mapel'] ?? '-').toString().toUpperCase();
                                final ruang = (j['ruang_kelas'] ?? 'Lt. 2 - R. 05').toString();
                                final isIstirahat = mapel.contains('ISTIRAHAT') || mapel.contains('ISHOMA');

                                return Container(
                                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  decoration: BoxDecoration(color: isIstirahat ? Colors.orange.shade50 : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: isIstirahat ? Colors.orange.shade200 : const Color(0xFFE2E8F0))),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isIstirahat ? Colors.orange.shade100 : const Color(0xFFDBEAFE), shape: BoxShape.circle), child: Icon(isIstirahat ? Icons.fastfood : Icons.menu_book_rounded, color: isIstirahat ? Colors.orange.shade800 : const Color(0xFF1E40AF), size: 20)), const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(mapel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isIstirahat ? Colors.orange.shade900 : const Color(0xFF0F172A))), const SizedBox(height: 6),
                                            if (!isIstirahat) ...[
                                              Row(children: [const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)), const SizedBox(width: 6), Expanded(child: Text(guru, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis))]), const SizedBox(height: 4),
                                              Row(children: [Icon(Icons.room_outlined, size: 14, color: Colors.teal.shade700), const SizedBox(width: 6), Text('Ruang: $ruang', style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.bold))]), const SizedBox(height: 4),
                                            ],
                                            Text('⏰ Waktu: $jamMulai - $jamSelesai WIB', style: TextStyle(fontSize: 11, color: isIstirahat ? Colors.orange.shade800 : Colors.blue.shade700, fontWeight: FontWeight.bold)),
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
        const bulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
        tglLahirFormatted = '${tgl.day} ${bulan[tgl.month - 1]} ${tgl.year}';
      } catch (_) { tglLahirFormatted = '-'; }
    }

    final nama = (biodata['full_name'] ?? 'Siswa').toString();
    final kelas = (biodata['kelas'] ?? '-').toString();
    final nisn = (biodata['nisn'] ?? '-').toString();
    final nipd = (biodata['nipd'] ?? '-').toString();
    final nik = (biodata['nik'] ?? '-').toString();
    final jk = (biodata['jk'] ?? biodata['jenis_kelamin'] ?? '-').toString();
    final agama = (biodata['agama'] ?? '-').toString();
    final noHp = (biodata['no_hp'] ?? biodata['nomor_hp'] ?? '-').toString();
    final domisili = (biodata['alamat'] ?? biodata['alamat_domisili'] ?? '-').toString();
    final tempatLahir = (biodata['tempat_lahir'] ?? '').toString();
    final fotoProfil = (biodata['foto_profil'] ?? '').toString(); // 🔥 AMBIL FOTO

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Profil Data Diri Siswa', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Center(
            child: Column(
              children: [
                // 🔥 AVATAR FOTO PROFIL SISWA
                Container(
                  padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF3B82F6), width: 2)),
                  child: CircleAvatar(
                    radius: 45, backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                    backgroundImage: fotoProfil.isNotEmpty ? NetworkImage(fotoProfil) : null,
                    child: fotoProfil.isEmpty ? const Icon(Icons.person_rounded, size: 50, color: Color(0xFF1E3A8A)) : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(nama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.center), const SizedBox(height: 4),
                Text('Status: Siswa Aktif', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('INFORMASI DATA AKADEMIK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 20, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemProfil(Icons.school_rounded, 'Kelas Aktif', kelas), const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _itemProfil(Icons.badge_rounded, 'NIPD (Nomor Induk Peserta Didik)', nipd), const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _itemProfil(Icons.fingerprint_rounded, 'NISN (Nomor Induk Siswa Nasional)', nisn),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text('BIODATA DIRI LENGKAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 20, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemProfil(Icons.credit_card_rounded, 'NIK (Nomor Induk Kependudukan)', nik), const Divider(height: 24, color: Color(0xFFF1F5F9)),
                if (tempatLahir.trim().isNotEmpty) ...[_itemProfil(Icons.cake_rounded, 'Tempat, Tanggal Lahir', '$tempatLahir, $tglLahirFormatted'), const Divider(height: 24, color: Color(0xFFF1F5F9))],
                _itemProfil(Icons.wc_rounded, 'Jenis Kelamin', jk), const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _itemProfil(Icons.mosque_rounded, 'Agama', agama), const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _itemProfil(Icons.phone_android_rounded, 'Nomor Handphone Aktif', noHp), const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _itemProfil(Icons.home_rounded, 'Alamat Domisili / Tempat Tinggal', domisili),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _itemProfil(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: Colors.blueGrey.shade700)), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)), const SizedBox(height: 2), Text((value == null || value.isEmpty) ? '-' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)))])),
      ],
    );
  }
}