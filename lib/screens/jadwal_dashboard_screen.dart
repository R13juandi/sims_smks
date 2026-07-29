import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      
      // 1. Ambil Jadwal Semester Berjalan
      final resJadwal = await _supabase.from('jadwal').select('*').eq('semester', 'Ganjil').eq('tahun_ajaran', '2025/2026');
      List<Map<String, dynamic>> tempJadwal = List<Map<String, dynamic>>.from(resJadwal);
      
      // 2. Ambil Histori Jadwal Semester Lalu (Untuk Kelas 11 & 12)
      List<Map<String, dynamic>> tempHistori = [];
      String kelasSiswa = (prof['kelas'] ?? '').toString();
      
      // 🔥 REVISI DOSEN: Jika bukan kelas X, tarik riwayat jadwal semester lalu
      if (!kelasSiswa.startsWith('X ') && !kelasSiswa.startsWith('10')) {
        final resHistori = await _supabase.from('jadwal').select('*').neq('tahun_ajaran', '2025/2026');
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSiswa = _biodata['role'] == 'siswa';
    String kelasSiswa = (_biodata['kelas'] ?? '').toString();
    bool isKelasSepuluh = kelasSiswa.startsWith('X ') || kelasSiswa.startsWith('10');

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
              // TAB 1: JADWAL SEMESTER BERJALAN
              _buildJadwalList(_semuaJadwal, isSiswa, false),

              // TAB 2: HISTORI JADWAL (REVISI PAK HALIM)
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
                : _buildJadwalList(_historiJadwal, isSiswa, true),
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

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [const Icon(Icons.calendar_month, size: 18, color: Colors.grey), const SizedBox(width: 8), Text(hari.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2))])),
                      ...listHariIni.map((j) {
                        String jamMulai = j['jam_mulai'] != null && j['jam_mulai'].toString().length >= 5 ? j['jam_mulai'].toString().substring(0, 5) : '00:00';
                        String jamSelesai = j['jam_selesai'] != null && j['jam_selesai'].toString().length >= 5 ? j['jam_selesai'].toString().substring(0, 5) : '00:00';
                        
                        // 🔥 REVISI DOSEN: HURUF KAPITAL MUTLAK
                        String mapel = (j['mapel'] ?? j['mata_pelajaran'] ?? '-').toString().toUpperCase();
                        // 🔥 REVISI DOSEN: ATRIBUT RUANG KELAS
                        String ruang = (j['ruang_kelas'] ?? 'R. 101').toString();
                        
                        bool isIstirahat = mapel.contains('ISTIRAHAT') || mapel.contains('ISHOMA');

                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isIstirahat ? Colors.orange.shade300 : Colors.grey.shade300)), color: isIstirahat ? Colors.orange.shade50 : Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isIstirahat ? Colors.orange.shade100 : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(jamMulai, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isIstirahat ? Colors.orange.shade900 : Colors.blue.shade900)), Text(jamSelesai, style: TextStyle(fontSize: 11, color: isIstirahat ? Colors.orange.shade800 : Colors.grey))]),
                            ),
                            title: Text(mapel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isIstirahat ? Colors.orange.shade900 : Colors.black)),
                            subtitle: isIstirahat ? null : Padding(
                              padding: const EdgeInsets.only(top: 6), 
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [const Icon(Icons.person, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(j['guru'] ?? j['guru_pengampu'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)))]),
                                  const SizedBox(height: 4),
                                  // 🔥 TAMPILAN RUANG KELAS & SEMESTER
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