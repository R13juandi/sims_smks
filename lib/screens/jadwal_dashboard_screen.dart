import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class JadwalDashboardScreen extends StatefulWidget {
  const JadwalDashboardScreen({super.key});

  @override
  State<JadwalDashboardScreen> createState() => _JadwalDashboardScreenState();
}

class _JadwalDashboardScreenState extends State<JadwalDashboardScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  Map<String, dynamic> _biodata = {};
  List<Map<String, dynamic>> _semuaJadwal = [];
  List<Map<String, dynamic>> _historiJadwal = [];
  
  // 🔥 MENAMPUNG DATA JADWAL PENGGANTI & GURU
  List<Map<String, dynamic>> _listJadwalPengganti = [];
  Map<String, String> _mapNamaGuru = {};

  String? _selectedKelas;
  List<String> _listKelasTersedia = [];
  late TabController _tabController;

  final List<String> _hariUrut = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchJadwalDanProfil();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchJadwalDanProfil() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      final prof = await _supabase.from('profiles').select('*').eq('id', user!.id).single();
      
      // 🔥 1. Ambil Nama Semua Guru (Untuk Kamus Override Nama)
      final resGuru = await _supabase.from('profiles').select('id, full_name').inFilter('role', ['guru', 'admin', 'kepsek']);
      for (var g in resGuru) {
        _mapNamaGuru[g['id'].toString()] = g['full_name'].toString();
      }

      // 🔥 2. Ambil Data Jadwal Pengganti (Khusus Tanggal Hari Ini)
      final String tglHariIni = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final resPengganti = await _supabase.from('jadwal_pengganti').select('*').eq('tanggal', tglHariIni);
      _listJadwalPengganti = List<Map<String, dynamic>>.from(resPengganti);
      
      // OTOMATIS: Mendeteksi Semester Berjalan Sesuai Waktu Real
      DateTime now = DateTime.now();
      int currentStartYear = now.month >= 7 ? now.year : now.year - 1;
      String currentTa = "$currentStartYear/${currentStartYear + 1}";
      String currentSmtStr = now.month >= 7 ? "Ganjil" : "Genap";
      
      // 🔥 3. PERBAIKAN: Baca dari tabel 'jadwal' (Bukan jadwal_pelajaran)
      final resJadwal = await _supabase.from('jadwal').select('*').eq('semester', currentSmtStr).eq('tahun_ajaran', currentTa);
      List<Map<String, dynamic>> tempJadwal = List<Map<String, dynamic>>.from(resJadwal);
      
      // 4. Ambil Histori Jadwal Semester Lalu (Untuk Kelas 11 & 12)
      List<Map<String, dynamic>> tempHistori = [];
      String kelasSiswa = (prof['kelas'] ?? '').toString();
      
      if (!kelasSiswa.startsWith('X ') && !kelasSiswa.startsWith('10')) {
        // 🔥 PERBAIKAN: Baca dari tabel 'jadwal'
        final resHistori = await _supabase.from('jadwal').select('*').neq('tahun_ajaran', currentTa);
        tempHistori = List<Map<String, dynamic>>.from(resHistori);
      }
      
      Set<String> kelasSet = tempJadwal.map((e) => (e['kelas'] ?? 'Tanpa Kelas').toString()).toSet();
      List<String> klsList = kelasSet.toList()..sort();

      if (mounted) {
        setState(() {
          _biodata = prof;
          _semuaJadwal = tempJadwal;
          _historiJadwal = tempHistori;
          _listKelasTersedia = klsList;

          if (prof['role'] == 'siswa') {
            _selectedKelas = prof['kelas'];
          } else { 
            if (klsList.isNotEmpty) _selectedKelas = klsList.first; 
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetch jadwal: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // 🔥 FUNGSI MERGE/OVERRIDE JADWAL MASTER DENGAN GURU PENGGANTI
  // =========================================================================
  List<Map<String, dynamic>> _terapkanGuruPengganti(List<Map<String, dynamic>> jadwalMaster) {
    List<Map<String, dynamic>> hasil = [];
    // Deteksi Nama Hari Ini (agar override hanya terjadi pada jadwal hari ini)
    final String hariIni = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][DateTime.now().weekday - 1];

    for (var j in jadwalMaster) {
      Map<String, dynamic> jadwalBaru = Map.from(j);
      
      // 🔥 PERBAIKAN: Langsung ambil nama dari kolom guru_pengampu
      String namaGuruAsli = j['guru_pengampu'] ?? 'Belum Diatur';
      jadwalBaru['guru_tampil'] = namaGuruAsli;
      jadwalBaru['is_diganti'] = false;

      // Logika Penimpaan: Hanya menimpa jika jadwal berada pada 'Hari Ini'
      if (j['hari'] == hariIni) {
        var cekPengganti;
        try {
          cekPengganti = _listJadwalPengganti.firstWhere((p) => p['jadwal_id'].toString() == j['id'].toString());
        } catch (_) {}

        if (cekPengganti != null) {
          String namaGuruGanti = _mapNamaGuru[cekPengganti['guru_pengganti_id'].toString()] ?? 'Guru Pengganti';
          jadwalBaru['guru_tampil'] = '$namaGuruGanti (Menggantikan: $namaGuruAsli)';
          jadwalBaru['is_diganti'] = true;
        }
      }

      hasil.add(jadwalBaru);
    }

    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    bool isSiswa = _biodata['role'] == 'siswa';
    String kelasSiswa = (_biodata['kelas'] ?? '').toString();
    bool isKelasSepuluh = kelasSiswa.startsWith('X ') || kelasSiswa.startsWith('10');

    // 🔥 TERAPKAN OVERRIDE PADA SEMUA JADWAL
    List<Map<String, dynamic>> jadwalBerjalanTerOverride = _terapkanGuruPengganti(_semuaJadwal);
    List<Map<String, dynamic>> jadwalHistoriTerOverride = _terapkanGuruPengganti(_historiJadwal);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Jadwal Pelajaran', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.white, 
        elevation: 0.5, 
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade900,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade900,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today, size: 18), text: 'Semester Berjalan'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Histori Semester'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildJadwalList(jadwalBerjalanTerOverride, isSiswa, false),
              isSiswa && isKelasSepuluh
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum ada histori jadwal pelajaran\nkarena Anda saat ini masih berada di Kelas 10.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                : _buildJadwalList(jadwalHistoriTerOverride, isSiswa, true),
            ],
          ),
    );
  }

  Widget _buildJadwalList(List<Map<String, dynamic>> sumberData, bool isSiswa, bool isHistori) {
    List<Map<String, dynamic>> jadwalFiltered = sumberData.where((j) => j['kelas'] == _selectedKelas).toList();
    jadwalFiltered.sort((a, b) {
      int cmp = _hariUrut.indexOf(a['hari'] ?? '').compareTo(_hariUrut.indexOf(b['hari'] ?? ''));
      if (cmp == 0) return (a['jam_mulai'] ?? '').compareTo(b['jam_mulai'] ?? '');
      return cmp;
    });

    Map<String, List<Map<String, dynamic>>> groupedJadwal = {};
    for (var j in jadwalFiltered) {
      String hari = j['hari'] ?? 'Senin';
      if (!groupedJadwal.containsKey(hari)) groupedJadwal[hari] = [];
      groupedJadwal[hari]!.add(j);
    }

    // Deteksi Nama Hari Ini (Untuk Highlight Biru)
    final String hariIni = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][DateTime.now().weekday - 1];

    return Column(
      children: [
        if (!isHistori)
          Container(
            padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                const Icon(Icons.class_, color: Colors.blue), const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _listKelasTersedia.contains(_selectedKelas) ? _selectedKelas : null,
                    decoration: InputDecoration(labelText: isSiswa ? 'Kelas Anda' : 'Pilih Kelas', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    items: _listKelasTersedia.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    onChanged: isSiswa ? null : (val) => setState(() => _selectedKelas = val),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: groupedJadwal.isEmpty 
            ? Center(child: Text(isHistori ? 'Tidak ada data riwayat jadwal lama untuk kelas ini.' : 'Belum ada jadwal untuk kelas ini.', style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(16), itemCount: _hariUrut.length,
                itemBuilder: (context, index) {
                  String hari = _hariUrut[index];
                  if (!groupedJadwal.containsKey(hari)) return const SizedBox(); 
                  
                  List<Map<String, dynamic>> listHariIni = groupedJadwal[hari]!;
                  bool isToday = (hari == hariIni && !isHistori);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12), 
                        child: Row(
                          children: [
                            Icon(isToday ? Icons.today_rounded : Icons.calendar_month, size: 18, color: isToday ? Colors.blue.shade700 : Colors.grey), 
                            const SizedBox(width: 8), 
                            Text(isToday ? '$hari (Hari Ini)' : hari.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? Colors.blue.shade700 : Colors.grey, letterSpacing: 1.2))
                          ]
                        )
                      ),
                      ...listHariIni.map((j) {
                        String jamMulai = j['jam_mulai'] != null && j['jam_mulai'].toString().length >= 5 ? j['jam_mulai'].toString().substring(0, 5) : '00:00';
                        String jamSelesai = j['jam_selesai'] != null && j['jam_selesai'].toString().length >= 5 ? j['jam_selesai'].toString().substring(0, 5) : '00:00';
                        
                        String mapel = (j['mata_pelajaran'] ?? '-').toString().toUpperCase();
                        String ruang = (j['ruang_kelas'] ?? 'R. 101').toString();
                        
                        bool isIstirahat = mapel.contains('ISTIRAHAT') || mapel.contains('ISHOMA');
                        
                        // 🔥 CEK OVERRIDE GURU PENGGANTI 
                        bool isDiganti = j['is_diganti'] ?? false;
                        String namaGuru = (j['guru_tampil'] ?? '-').toString();

                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 12), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isIstirahat ? Colors.orange.shade300 : (isDiganti ? Colors.teal.shade300 : Colors.grey.shade300))), 
                          color: isIstirahat ? Colors.orange.shade50 : (isDiganti ? Colors.teal.shade50 : Colors.white),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isIstirahat ? Colors.orange.shade100 : (isDiganti ? Colors.teal.shade100 : Colors.blue.shade50), borderRadius: BorderRadius.circular(8)),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(jamMulai, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isIstirahat ? Colors.orange.shade900 : (isDiganti ? Colors.teal.shade900 : Colors.blue.shade900))), Text(jamSelesai, style: TextStyle(fontSize: 11, color: isIstirahat ? Colors.orange.shade800 : Colors.grey))]),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(mapel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isIstirahat ? Colors.orange.shade900 : Colors.black))),
                                if (isDiganti)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.teal.shade700, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('INFAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                                  )
                              ],
                            ),
                            subtitle: isIstirahat ? null : Padding(
                              padding: const EdgeInsets.only(top: 6), 
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(isDiganti ? Icons.swap_horiz_rounded : Icons.person, size: 14, color: isDiganti ? Colors.teal.shade800 : Colors.grey), const SizedBox(width: 4), 
                                      Expanded(child: Text(namaGuru, style: TextStyle(fontSize: 12, color: isDiganti ? Colors.teal.shade900 : Colors.grey, fontWeight: isDiganti ? FontWeight.bold : FontWeight.normal))),
                                    ]
                                  ),
                                  const SizedBox(height: 4),
                                  Row(children: [const Icon(Icons.room, size: 14, color: Colors.blue), const SizedBox(width: 4), Text('Ruang: $ruang | ${j['semester'] ?? "Ganjil"} ${j['tahun_ajaran'] ?? ""}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800))]),
                                ],
                              ),
                            ),
                            trailing: isIstirahat ? Icon(Icons.fastfood, color: Colors.orange.shade300) : null,
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
        )
      ],
    );
  }
}