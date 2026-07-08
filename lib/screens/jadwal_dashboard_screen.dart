import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JadwalDashboardScreen extends StatefulWidget {
  const JadwalDashboardScreen({super.key});

  @override
  State<JadwalDashboardScreen> createState() => _JadwalDashboardScreenState();
}

class _JadwalDashboardScreenState extends State<JadwalDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  Map<String, dynamic> _biodata = {};
  List<Map<String, dynamic>> _semuaJadwal = [];
  
  String? _selectedKelas;
  List<String> _listKelasTersedia = [];

  final List<String> _hariUrut = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  @override
  void initState() {
    super.initState();
    _fetchJadwalDanProfil();
  }

  Future<void> _fetchJadwalDanProfil() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      final prof = await _supabase.from('profiles').select('*').eq('id', user!.id).single();
      
      final resJadwal = await _supabase.from('jadwal').select('*');
      List<Map<String, dynamic>> tempJadwal = List<Map<String, dynamic>>.from(resJadwal);
      
      Set<String> kelasSet = tempJadwal.map((e) => (e['kelas'] ?? 'Tanpa Kelas').toString()).toSet();
      List<String> klsList = kelasSet.toList()..sort();

      if (mounted) {
        setState(() {
          _biodata = prof;
          _semuaJadwal = tempJadwal;
          _listKelasTersedia = klsList;

          if (prof['role'] == 'siswa') _selectedKelas = prof['kelas'];
          else { if (klsList.isNotEmpty) _selectedKelas = klsList.first; }
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

    List<Map<String, dynamic>> jadwalFiltered = _semuaJadwal.where((j) => j['kelas'] == _selectedKelas).toList();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Jadwal Pelajaran', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, iconTheme: const IconThemeData(color: Colors.black)),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
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
                  ? const Center(child: Text('Belum ada jadwal untuk kelas ini.', style: TextStyle(color: Colors.grey)))
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
                              String mapel = j['mapel'] ?? j['mata_pelajaran'] ?? '-';
                              
                              // 🔥 DESAIN KHUSUS ISTIRAHAT UNTUK LAYAR GURU / KEPSEK
                              bool isIstirahat = mapel.toLowerCase().contains('istirahat') || mapel.toLowerCase().contains('ishoma');

                              return Card(
                                elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isIstirahat ? Colors.orange.shade300 : Colors.grey.shade300)), color: isIstirahat ? Colors.orange.shade50 : Colors.white,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isIstirahat ? Colors.orange.shade100 : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(jamMulai, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isIstirahat ? Colors.orange.shade900 : Colors.blue.shade900)), Text(jamSelesai, style: TextStyle(fontSize: 11, color: isIstirahat ? Colors.orange.shade800 : Colors.grey))]),
                                  ),
                                  title: Text(mapel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isIstirahat ? Colors.orange.shade900 : Colors.black)),
                                  subtitle: isIstirahat ? null : Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.person, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(j['guru'] ?? j['guru_pengampu'] ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)))])),
                                  trailing: isIstirahat ? Icon(Icons.fastfood, color: Colors.orange.shade300) : null,
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      }
                    )
              )
            ],
          ),
    );
  }
}