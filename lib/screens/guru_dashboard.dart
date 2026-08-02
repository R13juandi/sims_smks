import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/popup_service.dart'; 
import '../login_screen.dart';
import 'rekap_absensi_guru_screen.dart';

// =========================================================================
// GURU DASHBOARD UTAMA
// =========================================================================
class GuruDashboard extends StatefulWidget {
  const GuruDashboard({super.key});

  @override
  State<GuruDashboard> createState() => _GuruDashboardState();
}

class _GuruDashboardState extends State<GuruDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  Map<String, dynamic> _biodataGuru = {};
  List<Map<String, dynamic>> _semuaJadwalGuru = [];
  List<String> _kelasDariJadwal = []; 
  List<String> _mapelGuru = [];
  Map<String, List<Map<String, dynamic>>> _siswaPerKelas = {};
  
  int _jumlahAbsenPending = 0;

  @override
  void initState() {
    super.initState();
    _loadGuruData();
  }

  Future<void> _loadGuruData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profileRes = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (profileRes != null && mounted) {
        setState(() {
          _biodataGuru = profileRes;
          _mapelGuru = List<String>.from(_biodataGuru['mapel'] ?? []);
        });
      }

      final namaGuru = _biodataGuru['full_name']?.toString().trim() ?? '';

      // 🔥 FUZZY MATCHING: Tarik SEMUA jadwal, filter secara fleksibel
      final semuaJadwalDb = await _supabase.from('jadwal').select('*');
      
      List<String> nameParts = namaGuru.toLowerCase()
          .replaceAll(RegExp(r'[,.]'), '') // Hapus tanda baca
          .split(' ')
          .where((w) => w.length > 2 && w != 'spd' && w != 'skom' && w != 'mpd' && w != 'bpk' && w != 'ibu') // Abaikan gelar
          .toList();

      List<Map<String, dynamic>> jadwalRes = [];
      Set<String> namaGuruAlias = {namaGuru}; // Koleksi format nama guru dari DB

      for (var j in semuaJadwalDb) {
        String guruMapel = (j['guru_pengampu'] ?? '').toString();
        String guruMapelLower = guruMapel.toLowerCase();
        bool isMatch = false;

        if (guruMapelLower.contains(namaGuru.toLowerCase()) || namaGuru.toLowerCase().contains(guruMapelLower)) {
          isMatch = true;
        } else {
          for (String part in nameParts) {
            if (guruMapelLower.contains(part)) {
              isMatch = true;
              break;
            }
          }
        }

        if (isMatch) {
          jadwalRes.add(j);
          namaGuruAlias.add(guruMapel);
        }
      }

      Set<String> kelasUnik = {};
      for (var j in jadwalRes) {
        if (j['kelas'] != null && j['kelas'].toString().isNotEmpty) {
          kelasUnik.add(j['kelas'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _semuaJadwalGuru = jadwalRes;
          _kelasDariJadwal = kelasUnik.isNotEmpty 
              ? kelasUnik.toList() 
              : List<String>.from(_biodataGuru['kelas_mengajar'] ?? []);
          _kelasDariJadwal.sort(); 
        });
      }
      
      final tanggalSekarang = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final pendingRes = await _supabase
          .from('absensi')
          .select('id, guru_pengampu')
          .eq('tanggal', tanggalSekarang)
          .eq('status_verifikasi', 'Pending');
          
      int countPending = 0;
      for (var p in pendingRes) {
         String g = (p['guru_pengampu'] ?? '').toString();
         if (namaGuruAlias.contains(g) || g.toLowerCase().contains(namaGuru.toLowerCase())) {
            countPending++;
         } else {
            for (String part in nameParts) {
              if (g.toLowerCase().contains(part)) {
                countPending++;
                break;
              }
            }
         }
      }

      if (mounted) {
        setState(() {
          _jumlahAbsenPending = countPending;
        });
      }

      if (_kelasDariJadwal.isNotEmpty) {
        final siswaRes = await _supabase
            .from('profiles')
            .select('id, full_name, nisn, kelas')
            .eq('role', 'siswa')
            .inFilter('kelas', _kelasDariJadwal)
            .order('full_name', ascending: true);

        if (mounted) {
          _siswaPerKelas.clear();
          for (var k in _kelasDariJadwal) {
            _siswaPerKelas[k] = [];
          }
          for (var s in siswaRes) {
            String kls = s['kelas'] ?? '';
            if (_siswaPerKelas.containsKey(kls)) {
              _siswaPerKelas[kls]!.add(s);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        PopupService.show(context, 'Gagal memuat data guru: $e', isSuccess: false, judul: 'Terjadi Kesalahan');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF))));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Dashboard Pendidik', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            tooltip: 'Keluar Aplikasi',
            onPressed: () {
              PopupService.showConfirm(
                context,
                'Apakah Anda yakin ingin keluar dari sistem Pendidik?',
                judul: 'Konfirmasi Keluar',
                onConfirm: () async {
                  await _supabase.auth.signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                },
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGuruData,
        color: const Color(0xFF1E40AF),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeaderCard(),
            
            if (_jumlahAbsenPending > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Peringatan: Terdapat $_jumlahAbsenPending absensi siswa yang menunggu verifikasi Anda hari ini!',
                        style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            const Text('Aksi Cepat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuCard(
                        icon: Icons.fact_check_rounded, color: Colors.blue, title: 'Presensi\n& Rekap', badgeCount: _jumlahAbsenPending,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const RekapAbsensiGuruScreen()));
                          _loadGuruData();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuCard(
                        icon: Icons.edit_document, color: Colors.orange.shade700, title: 'Input\nBuku Nilai',
                        onTap: () {
                          final List<String> kelasAdaSiswa = _kelasDariJadwal.where((k) => _siswaPerKelas[k] != null && _siswaPerKelas[k]!.isNotEmpty).toList();
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => InputNilaiGuruScreen(
                              biodataGuru: _biodataGuru, 
                              kelasMengajar: kelasAdaSiswa, 
                              mapelGuru: _mapelGuru,
                            ),
                          ));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuCard(
                        icon: Icons.groups_rounded, color: Colors.purple, title: 'Daftar Siswa\n& Detail',
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (context) => DaftarSiswaGuruScreen(
                            kelasMengajar: _kelasDariJadwal, 
                            siswaPerKelas: _siswaPerKelas,
                            biodataGuru: _biodataGuru,
                          ),
                        )),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuCard(
                        icon: Icons.calendar_month_rounded, color: Colors.red.shade700, title: 'Jadwal\nMengajar',
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (context) => JadwalMengajarGuruScreen(semuaJadwalGuru: _semuaJadwalGuru),
                        )),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0, clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailProfilGuruScreen(biodata: _biodataGuru))),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]), borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selamat Bertugas,', style: TextStyle(color: Colors.white70)),
                    Text(_biodataGuru['full_name'] ?? 'Guru', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(_kelasDariJadwal.isEmpty ? 'Belum ada jadwal mengajar.' : 'Mengajar Kelas: ${_kelasDariJadwal.join(", ")}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required Color color, required String title, required VoidCallback onTap, int badgeCount = 0}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                Icon(icon, color: color, size: 32), const SizedBox(height: 10),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -5, right: -5,
              child: Container(
                padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

// =========================================================================
// JADWAL GURU
// =========================================================================
class JadwalMengajarGuruScreen extends StatefulWidget {
  final List<Map<String, dynamic>> semuaJadwalGuru;
  const JadwalMengajarGuruScreen({super.key, required this.semuaJadwalGuru});

  @override
  State<JadwalMengajarGuruScreen> createState() => _JadwalMengajarGuruScreenState();
}

class _JadwalMengajarGuruScreenState extends State<JadwalMengajarGuruScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _jadwalTerpilih = [];
  String _selectedPeriode = '';
  List<String> _daftarPeriodeHistori = [];

  @override
  void initState() {
    super.initState();
    _extractPeriodeDariData();
  }

  void _extractPeriodeDariData() {
    Set<String> periods = {};
    
    DateTime now = DateTime.now();
    int currentStartYear = now.month >= 7 ? now.year : now.year - 1;
    String currentTa = "$currentStartYear/${currentStartYear + 1}";
    String currentSmtStr = now.month >= 7 ? "Ganjil" : "Genap";
    String activeKey = "$currentSmtStr $currentTa";

    for (var j in widget.semuaJadwalGuru) {
      String dbSemester = (j['semester'] ?? '').toString().trim();
      String dbTahun = (j['tahun_ajaran'] ?? '').toString().trim();
      
      if (dbSemester.isNotEmpty && dbTahun.isNotEmpty) {
         String smtCap = dbSemester.toLowerCase().contains('ganjil') ? 'Ganjil' : 'Genap';
         String key = "$smtCap $dbTahun";
         
         if (key == activeKey) {
           periods.add('Semester $key (Aktif)');
         } else {
           periods.add('Semester $key (Histori)');
         }
      }
    }
    
    List<String> finalPeriods = periods.toList();
    
    finalPeriods.sort((a, b) {
      return b.compareTo(a);
    });

    if (finalPeriods.isEmpty) {
      finalPeriods.add('Semester $activeKey (Aktif)');
    } else if (!finalPeriods.any((p) => p.contains('(Aktif)'))) {
      finalPeriods.insert(0, 'Semester $activeKey (Aktif)');
    }

    setState(() {
      _daftarPeriodeHistori = finalPeriods;
      _selectedPeriode = finalPeriods.firstWhere((p) => p.contains('(Aktif)'), orElse: () => finalPeriods.first);
    });

    _filterJadwalLokal(_selectedPeriode);
  }

  void _filterJadwalLokal(String periode) {
    setState(() => _isLoading = true);
    
    String smtKeyword = periode.toLowerCase().contains('ganjil') ? 'ganjil' : 'genap';
    RegExp regExp = RegExp(r'\d{4}/\d{4}');
    String tahunKeyword = regExp.stringMatch(periode) ?? '';

    List<Map<String, dynamic>> hasil = widget.semuaJadwalGuru.where((j) {
      String dbSemester = (j['semester'] ?? '').toString().toLowerCase();
      String dbTahun = (j['tahun_ajaran'] ?? '').toString().toLowerCase();
      
      bool matchSmt = dbSemester.contains(smtKeyword);
      bool matchTahun = tahunKeyword.isNotEmpty ? dbTahun.contains(tahunKeyword) : true;
      
      return matchSmt && matchTahun;
    }).toList();

    setState(() {
      _jadwalTerpilih = hasil;
      _isLoading = false;
    });
  }

  Map<String, Map<String, List<Map<String, dynamic>>>> _groupJadwalByKelasAndHari() {
    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (var j in _jadwalTerpilih) {
      String kls = j['kelas']?.toString() ?? 'Lainnya';
      String hari = j['hari']?.toString() ?? 'Lainnya';
      if (!grouped.containsKey(kls)) grouped[kls] = {};
      if (!grouped[kls]!.containsKey(hari)) grouped[kls]![hari] = [];
      grouped[kls]![hari]!.add(j);
    }
    return grouped;
  }

  int _dayIndex(String day) {
    switch (day.toLowerCase()) {
      case 'senin': return 1; case 'selasa': return 2; case 'rabu': return 3; case 'kamis': return 4; case 'jumat': return 5; case 'sabtu': return 6; case 'minggu': return 7; default: return 8;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupJadwalByKelasAndHari();
    final sortedKelas = groupedData.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Jadwal Mengajar Anda', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0.5, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedPeriode,
              isExpanded: true,
              icon: const Icon(Icons.history_edu_rounded, color: Color(0xFF1E40AF)),
              decoration: InputDecoration(
                labelText: 'Pilih Periode / Histori Mengajar',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue.shade100, width: 1.5)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFF1E40AF), width: 2)),
              ),
              items: _daftarPeriodeHistori.map((p) => DropdownMenuItem(
                value: p,
                child: Text(p, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
              )).toList(),
              onChanged: (val) {
                if (val != null && val != _selectedPeriode) {
                  setState(() => _selectedPeriode = val);
                  _filterJadwalLokal(val);
                }
              },
            ),
          ),
          
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
              : _jadwalTerpilih.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('Belum ada jadwal / riwayat mengajar\npada \n$_selectedPeriode.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: sortedKelas.map((kls) {
                        final daysMap = groupedData[kls]!;
                        final sortedDays = daysMap.keys.toList()..sort((a, b) => _dayIndex(a).compareTo(_dayIndex(b)));

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue.shade100, width: 1.5)),
                          child: ExpansionTile(
                            shape: const Border(),
                            leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.folder_shared, color: Color(0xFF1E40AF))),
                            title: Text('Kelas $kls', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF))),
                            children: sortedDays.map((hari) {
                              final listJadwal = daysMap[hari]!;
                              return Padding(
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                                child: Card(
                                  elevation: 0, color: const Color(0xFFF8FAFC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                                  child: ExpansionTile(
                                    shape: const Border(),
                                    leading: const Icon(Icons.calendar_today, color: Colors.orange, size: 20),
                                    title: Text('Hari $hari', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    children: listJadwal.map((j) {
                                      final mapel = (j['mata_pelajaran'] ?? j['mapel'] ?? '-').toString().toUpperCase();
                                      final ruang = (j['ruang_kelas'] ?? 'Lt. 2 - R. 05').toString();
                                      final jamMulai = (j['jam_mulai'] ?? '00:00').toString();
                                      final jamSelesai = (j['jam_selesai'] ?? '00:00').toString();

                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.play_arrow_rounded, color: Colors.green, size: 22),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(mapel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.room_outlined, size: 14, color: Colors.teal.shade700),
                                                      const SizedBox(width: 4),
                                                      Text('Ruang: $ruang', style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text('⏰ Pukul: $jamMulai - $jamSelesai WIB', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// INPUT NILAI GURU BATCH
// =========================================================================
class InputNilaiGuruScreen extends StatefulWidget {
  final Map<String, dynamic> biodataGuru;
  final List<String> kelasMengajar;
  final List<String> mapelGuru;

  const InputNilaiGuruScreen({
    super.key,
    required this.biodataGuru,
    required this.kelasMengajar,
    required this.mapelGuru,
  });

  @override
  State<InputNilaiGuruScreen> createState() => _InputNilaiGuruScreenState();
}

class _InputNilaiGuruScreenState extends State<InputNilaiGuruScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _showFormNilai = false;

  String? _selectedKelasNilai;
  String? _selectedMapelNilai;
  String? _selectedKategoriNilai;

  String _semesterBerjalan = 'Semester 1 (Ganjil)';

  List<Map<String, dynamic>> _listSiswaNilai = [];
  final Map<String, TextEditingController> _nilaiControllers = {};
  
  final Map<String, int> _existingNilaiIds = {};

  final List<String> _listKategori = [
    'Ulangan Harian 1', 'Ulangan Harian 2', 'Ulangan Harian 3', 'Ulangan Harian 4',
    'Tugas 1', 'Tugas 2', 'Tugas 3', 'Praktek 1', 'Praktek 2', 'PTS', 'PAS',
  ];

  @override
  void initState() {
    super.initState();
    _fetchSemesterBerjalan();
  }

  Future<void> _fetchSemesterBerjalan() async {
    try {
      final config = await _supabase.from('pengaturan_sistem').select().maybeSingle();
      if (config != null && config['semester_aktif'] != null) {
        String smt = config['semester_aktif'].toString();
        if (mounted) {
          setState(() {
            _semesterBerjalan = smt.toLowerCase().contains('genap') || smt.contains('2')
                ? 'Semester 2 (Genap)' : 'Semester 1 (Ganjil)';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _semesterBerjalan = 'Semester 1 (Ganjil)');
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _nilaiControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getTahunAjaranOtomatis() {
    final now = DateTime.now();
    return (now.month >= 7) ? '${now.year}/${now.year + 1}' : '${now.year - 1}/${now.year}';
  }

  Future<void> _panggilSiswaFormNilai() async {
    if (_selectedKelasNilai == null || _selectedMapelNilai == null || _selectedKategoriNilai == null) {
      PopupService.show(context, 'Mohon lengkapi pilihan Kelas, Mata Pelajaran, dan Kategori Penilaian!', isSuccess: false, judul: 'Filter Belum Lengkap');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resSiswa = await _supabase
          .from('profiles')
          .select('id, full_name, nisn')
          .eq('role', 'siswa')
          .eq('kelas', _selectedKelasNilai!)
          .order('full_name', ascending: true);

      final resNilaiExisting = await _supabase
          .from('nilai')
          .select('id, siswa_id, nilai')
          .eq('kelas', _selectedKelasNilai!)
          .eq('mapel', _selectedMapelNilai!)
          .eq('semester', _semesterBerjalan) 
          .eq('kategori', _selectedKategoriNilai!)
          .eq('tahun_ajaran', _getTahunAjaranOtomatis());

      _existingNilaiIds.clear();
      Map<String, String> existingGrades = {};
      
      for(var n in resNilaiExisting) {
         String sId = n['siswa_id'].toString();
         _existingNilaiIds[sId] = n['id'];
         existingGrades[sId] = n['nilai'].toString();
      }

      _listSiswaNilai = List<Map<String, dynamic>>.from(resSiswa);
      _nilaiControllers.forEach((key, value) => value.dispose());
      _nilaiControllers.clear();

      for (var s in _listSiswaNilai) {
        String sId = s['id'].toString();
        _nilaiControllers[sId] = TextEditingController(text: existingGrades[sId] ?? '');
      }

      setState(() => _showFormNilai = true);
    } catch (e) {
      PopupService.show(context, 'Error mengambil data siswa: $e', isSuccess: false, judul: 'Terjadi Kesalahan');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _tampilkanPesanErrorNilai(List<String> daftarSiswaError) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.warning_rounded, color: Colors.red, size: 48)),
                const SizedBox(height: 24),
                const Text('Gagal Menyimpan!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 12),
                const Text('Nilai harus berada di rentang 0 sampai 100. Sistem menolak penyimpanan karena ada nilai yang tidak wajar pada siswa berikut:', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 12),
                Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text(daftarSiswaError.join(', '), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 13))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('PERBAIKI NILAI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _simpanNilaiKeCloud() async {
    List<String> invalidInputs = [];
    
    for (var s in _listSiswaNilai) {
      String sId = s['id'].toString();
      String nilaiInput = _nilaiControllers[sId]!.text.trim();
      
      if (nilaiInput.isNotEmpty) {
        double? cekNilai = double.tryParse(nilaiInput.replaceAll(',', '.'));
        if (cekNilai == null || cekNilai < 0 || cekNilai > 100) {
          invalidInputs.add(s['full_name']); 
        }
      }
    }

    if (invalidInputs.isNotEmpty) {
      _tampilkanPesanErrorNilai(invalidInputs);
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> batchNilaiInsert = [];

      for (var s in _listSiswaNilai) {
        String sId = s['id'].toString();
        String nilaiInput = _nilaiControllers[sId]!.text.trim();
        if (nilaiInput.isEmpty) continue; 

        Map<String, dynamic> payload = {
          'siswa_id': sId,
          'kelas': _selectedKelasNilai,
          'mapel': _selectedMapelNilai,
          'semester': _semesterBerjalan, 
          'tahun_ajaran': _getTahunAjaranOtomatis(),
          'kategori': _selectedKategoriNilai,
          'nilai': double.tryParse(nilaiInput.replaceAll(',', '.')) ?? 0.0,
          'guru_pengampu': widget.biodataGuru['full_name'],
        };

        if (_existingNilaiIds.containsKey(sId)) {
           payload['id'] = _existingNilaiIds[sId];
        }

        batchNilaiInsert.add(payload);
      }

      if (batchNilaiInsert.isEmpty) {
        PopupService.show(context, 'Tidak ada nilai yang diinputkan untuk disimpan.', isSuccess: false, judul: 'Data Kosong');
        setState(() => _isLoading = false);
        return;
      }

      await _supabase.from('nilai').upsert(batchNilaiInsert);

      if (!mounted) return;
      setState(() => _showFormNilai = false);
      PopupService.show(context, 'Buku Nilai (Rekap) sukses disimpan & diperbarui di server!', isSuccess: true, judul: 'Berhasil');
    } catch (e) {
      PopupService.show(context, 'Gagal menyimpan nilai: $e', isSuccess: false, judul: 'Terjadi Kesalahan');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF))));
    if (_showFormNilai) return _buildFormBukuNilai();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Buku Nilai Guru', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
            child: Row(
              children: [
                Icon(Icons.lock_clock_rounded, size: 20, color: Colors.blue.shade900),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Semester Aktif (Otomatis):', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                      Text('$_semesterBerjalan - ${_getTahunAjaranOtomatis()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Atur Detail Kelas & Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDropdown(_selectedKelasNilai, 'Pilih Kelas Target', widget.kelasMengajar, (v) => setState(() => _selectedKelasNilai = v)),
                  const SizedBox(height: 12),
                  _buildDropdown(_selectedMapelNilai, 'Pilih Mata Pelajaran', widget.mapelGuru, (v) => setState(() => _selectedMapelNilai = v)),
                  const SizedBox(height: 12),
                  _buildDropdown(_selectedKategoriNilai, 'Pilih Kategori Penilaian', _listKategori, (v) => setState(() => _selectedKategoriNilai = v)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _panggilSiswaFormNilai,
            icon: const Icon(Icons.edit_document),
            label: const Text('BUKA BUKU NILAI (INPUT / REKAP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String? value, String hint, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint, style: const TextStyle(fontSize: 13)),
      decoration: InputDecoration(
        filled: true, fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
      ),
      items: items.isEmpty 
          ? [const DropdownMenuItem(value: "", child: Text("Data Kosong / Belum Ada Jadwal"))]
          : items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  Widget _buildFormBukuNilai() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Form: $_selectedKategoriNilai', style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
            Text('Kelas $_selectedKelasNilai | $_selectedMapelNilai | $_semesterBerjalan', style: const TextStyle(fontSize: 11, color: Colors.blue)),
          ],
        ),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => setState(() => _showFormNilai = false)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue.shade800, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Text("Halaman ini berfungsi sebagai INPUT sekaligus REKAP. Nilai yang sudah ada akan otomatis muncul. Untuk mengubah nilai Remedial, cukup ganti angkanya lalu klik Simpan.", style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w500))),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFF1E40AF)),
                    headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    dataRowMaxHeight: 65, 
                    columnSpacing: 25,
                    border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                    columns: const [
                      DataColumn(label: Text('NO')),
                      DataColumn(label: Text('NISN')),
                      DataColumn(label: Text('NAMA PESERTA DIDIK')),
                      DataColumn(label: Text('INPUT NILAI')),
                    ],
                    rows: _listSiswaNilai.asMap().entries.map((entry) {
                      int index = entry.key;
                      var s = entry.value;
                      String sId = s['id'].toString();
                      
                      return DataRow(
                        color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                          if (index % 2 == 0) return Colors.grey.withOpacity(0.05); 
                          return null;
                        }),
                        cells: [
                          DataCell(Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(s['nisn'] ?? '-')),
                          DataCell(Text(s['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          DataCell(
                            Container(
                              width: 100,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: TextField(
                                controller: _nilaiControllers[sId],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                                decoration: InputDecoration(
                                  hintText: '0-100',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                                ),
                              ),
                            ),
                          ),
                        ]
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _simpanNilaiKeCloud,
          icon: const Icon(Icons.save_rounded),
          label: const Text('SIMPAN BUKU NILAI KE SERVER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

// =========================================================================
// DAFTAR SISWA
// =========================================================================
class DaftarSiswaGuruScreen extends StatelessWidget {
  final List<String> kelasMengajar;
  final Map<String, List<Map<String, dynamic>>> siswaPerKelas;
  final Map<String, dynamic> biodataGuru;

  const DaftarSiswaGuruScreen({
    super.key,
    required this.kelasMengajar,
    required this.siswaPerKelas,
    required this.biodataGuru,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> kelasAdaSiswa = kelasMengajar.where((kelas) {
      return siswaPerKelas[kelas] != null && siswaPerKelas[kelas]!.isNotEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Daftar Siswa & Detail', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: kelasAdaSiswa.isEmpty 
          ? const Center(child: Text("Belum ada data siswa di kelas yang Anda ajar.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: kelasAdaSiswa.length,
              itemBuilder: (context, index) {
                String kelas = kelasAdaSiswa[index];
                List<Map<String, dynamic>> siswaList = siswaPerKelas[kelas]!;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  child: ExpansionTile(
                    shape: const Border(),
                    leading: const Icon(Icons.folder_open_rounded, color: Colors.amber, size: 30),
                    title: Text('Data Siswa Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold)),
                    children: siswaList.map((s) => Container(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.person, color: Color(0xFF1E40AF))),
                            title: Text(s['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('NISN: ${s['nisn'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => DetailSiswaOlehGuruScreen(
                                  siswa: s,
                                  biodataGuru: biodataGuru,
                                )
                              ));
                            },
                          ),
                        )).toList(),
                  ),
                );
              },
            ),
    );
  }
}

// =========================================================================
// DETAIL SISWA (TAB NILAI & ABSEN)
// =========================================================================
class DetailSiswaOlehGuruScreen extends StatefulWidget {
  final Map<String, dynamic> siswa;
  final Map<String, dynamic> biodataGuru;

  const DetailSiswaOlehGuruScreen({
    super.key,
    required this.siswa,
    required this.biodataGuru,
  });

  @override
  State<DetailSiswaOlehGuruScreen> createState() => _DetailSiswaOlehGuruScreenState();
}

class _DetailSiswaOlehGuruScreenState extends State<DetailSiswaOlehGuruScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoadingNilai = true;
  bool _isLoadingAbsen = true;
  
  List<Map<String, dynamic>> _listNilai = [];
  List<Map<String, dynamic>> _riwayatAbsen = [];
  int _hadir = 0, _izin = 0, _sakit = 0, _alfa = 0;

  @override
  void initState() {
    super.initState();
    _fetchNilaiSiswa();
    _fetchAbsenSiswa();
  }

  Future<void> _fetchNilaiSiswa() async {
    try {
      final namaGuru = widget.biodataGuru['full_name']?.toString().trim() ?? '';
      
      List<String> nameParts = namaGuru.toLowerCase().replaceAll(RegExp(r'[,.]'), '').split(' ').where((w) => w.length > 2 && w != 'spd' && w != 'skom').toList();

      final res = await _supabase
          .from('nilai')
          .select('*')
          .eq('siswa_id', widget.siswa['id'])
          .order('semester', ascending: false)
          .order('kategori', ascending: true);
          
      List<Map<String, dynamic>> hasilFilter = [];
      for(var n in res) {
        String dbGuru = (n['guru_pengampu'] ?? '').toString().toLowerCase();
        bool isMatch = false;
        
        if (dbGuru.contains(namaGuru.toLowerCase()) || namaGuru.toLowerCase().contains(dbGuru)) {
           isMatch = true;
        } else {
           for (String part in nameParts) {
             if (dbGuru.contains(part)) { isMatch = true; break; }
           }
        }
        if (isMatch) hasilFilter.add(n);
      }

      if (mounted) {
        setState(() {
          _listNilai = hasilFilter;
          _isLoadingNilai = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNilai = false);
        PopupService.show(context, 'Gagal memuat rekap nilai: $e', isSuccess: false, judul: 'Error');
      }
    }
  }

  Future<void> _fetchAbsenSiswa() async {
    try {
      final res = await _supabase
          .from('absensi')
          .select('*')
          .eq('siswa_id', widget.siswa['id'])
          .order('waktu_absen', ascending: false);

      int h = 0, i = 0, s = 0, a = 0;
      for(var ab in res) {
        String st = (ab['status'] ?? '').toString().toUpperCase();
        if (st == 'H' || st == 'HADIR') h++;
        else if (st == 'I' || st == 'IZIN') i++;
        else if (st == 'S' || st == 'SAKIT') s++;
        else a++;
      }

      if (mounted) {
        setState(() {
          _riwayatAbsen = List<Map<String, dynamic>>.from(res);
          _hadir = h; _izin = i; _sakit = s; _alfa = a;
          _isLoadingAbsen = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAbsen = false);
    }
  }

  void _hapusNilai(String nilaiId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text("Hapus Nilai")]),
        content: const Text("Apakah Anda yakin ingin menghapus catatan nilai ini secara permanen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.from('nilai').delete().eq('id', nilaiId);
                _fetchNilaiSiswa();
                if (mounted) PopupService.show(context, 'Data nilai berhasil dihapus.', isSuccess: true);
              } catch (e) {
                if (mounted) PopupService.show(context, 'Gagal menghapus nilai: $e', isSuccess: false);
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editNilai(Map<String, dynamic> n) {
    final TextEditingController editController = TextEditingController(text: n['nilai']?.toString() ?? '0');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.edit_document, color: Colors.blue), SizedBox(width: 8), Text("Edit Nilai Cepat")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori: ${n['kategori']}\nMapel: ${n['mapel'] ?? n['mata_pelajaran']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: editController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
              decoration: InputDecoration(
                labelText: 'Masukkan Angka Baru',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.blue.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              String newVal = editController.text.replaceAll(',', '.');
              double? parsedVal = double.tryParse(newVal);
              
              if (parsedVal != null && parsedVal >= 0 && parsedVal <= 100) {
                try {
                  await _supabase.from('nilai').update({'nilai': parsedVal}).eq('id', n['id']);
                  _fetchNilaiSiswa();
                  if (mounted) PopupService.show(context, 'Nilai berhasil diperbarui!', isSuccess: true);
                } catch (e) {
                  if (mounted) PopupService.show(context, 'Gagal update nilai: $e', isSuccess: false);
                }
              } else {
                if (mounted) PopupService.show(context, 'Mohon masukkan angka 0 - 100 yang valid.', isSuccess: false);
              }
            },
            child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final namaSiswa = widget.siswa['full_name'] ?? 'Siswa';
    final nisn = widget.siswa['nisn'] ?? '-';
    final kelas = widget.siswa['kelas'] ?? '-';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Profil Akademik Siswa', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E40AF), elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Rekap Nilai'),
              Tab(icon: Icon(Icons.fact_check_outlined), text: 'Rekap Absensi'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
              child: Column(
                children: [
                  CircleAvatar(radius: 35, backgroundColor: const Color(0xFF1E40AF).withOpacity(0.1), child: const Icon(Icons.person, size: 40, color: Color(0xFF1E40AF))),
                  const SizedBox(height: 12),
                  Text(namaSiswa, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('Kelas $kelas | NISN: $nisn', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTabNilai(),
                  _buildTabAbsen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabNilai() {
    if (_isLoadingNilai) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
    if (_listNilai.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Anda belum menginputkan nilai apapun\nuntuk siswa ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _listNilai.length,
      itemBuilder: (context, index) {
        final n = _listNilai[index];
        final mapel = n['mapel'] ?? n['mata_pelajaran'] ?? '-';
        final kategori = n['kategori'] ?? '-';
        final semester = n['semester'] ?? '-';
        final nilaiAngka = n['nilai']?.toString() ?? '0';

        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade100, width: 1.5)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Text(nilaiAngka, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kategori, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('📚 Mapel: $mapel', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('🗓️ $semester', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      tooltip: 'Edit Nilai',
                      onPressed: () => _editNilai(n),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Hapus Nilai',
                      onPressed: () => _hapusNilai(n['id'].toString()),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabAbsen() {
    if (_isLoadingAbsen) return const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
    
    int total = _hadir + _izin + _sakit + _alfa;
    double persentase = total > 0 ? (_hadir / total) * 100 : 0.0;
    bool isRajin = persentase >= 80.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tingkat Kehadiran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: isRajin ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text('${persentase.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isRajin ? Colors.green.shade700 : Colors.red.shade700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _itemStat('Hadir', _hadir.toString(), Colors.green.shade700),
                    _itemStat('Izin', _izin.toString(), Colors.orange.shade700),
                    _itemStat('Sakit', _sakit.toString(), Colors.blue.shade700),
                    _itemStat('Alfa', _alfa.toString(), Colors.red.shade700),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Riwayat Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        if (_riwayatAbsen.isEmpty) 
           const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada riwayat presensi.', style: TextStyle(color: Colors.grey)))
        else 
          ..._riwayatAbsen.map((ab) {
            final status = (ab['status'] ?? '-').toString().toUpperCase();
            Color badgeColor = status == 'H' || status == 'HADIR' ? Colors.green : (status == 'I' || status == 'S' || status == 'IZIN' || status == 'SAKIT' ? Colors.orange : Colors.red);
            return Card(
              elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                leading: Icon(Icons.access_time_rounded, color: badgeColor),
                title: Text(ab['tanggal'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Jam Scan: ${ab['waktu_absen'] ?? '-'} WIB', style: const TextStyle(fontSize: 11)),
                trailing: Text(status, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _itemStat(String label, String count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

class DetailProfilGuruScreen extends StatelessWidget {
  final Map<String, dynamic> biodata;
  const DetailProfilGuruScreen({super.key, required this.biodata});

  @override
  Widget build(BuildContext context) {
    final List<String> listMapel = List<String>.from(biodata['mapel'] ?? []);
    final String nama = biodata['full_name'] ?? 'Guru';
    final String email = biodata['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? '-';
    final String nik = biodata['nik'] ?? '-';
    final String jk = biodata['jk'] ?? biodata['jenis_kelamin'] ?? '-';
    final String agama = biodata['agama'] ?? '-';
    final String noHp = biodata['no_hp'] ?? biodata['nomor_hp'] ?? '-';
    final String alamat = biodata['alamat'] ?? biodata['alamat_domisili'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profil Pendidik', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(radius: 45, backgroundColor: const Color(0xFF1E40AF).withOpacity(0.1), child: const Icon(Icons.account_box_rounded, size: 55, color: Color(0xFF1E40AF))),
                const SizedBox(height: 16),
                Text(nama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Tenaga Pendidik / Guru', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('KOMPETENSI MENGAJAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfilRow(Icons.book_rounded, 'Mata Pelajaran yang Diampu', listMapel.isEmpty ? '-' : listMapel.join(', ')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('INFORMASI BIODATA DIRI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfilRow(Icons.badge_rounded, 'Nomor Induk Kependudukan (NIK)', nik),
                  const Divider(height: 24), _buildProfilRow(Icons.email_rounded, 'Alamat Email', email),
                  const Divider(height: 24), _buildProfilRow(Icons.wc_rounded, 'Jenis Kelamin', jk),
                  const Divider(height: 24), _buildProfilRow(Icons.mosque_rounded, 'Agama', agama),
                  const Divider(height: 24), _buildProfilRow(Icons.phone_android_rounded, 'Nomor Handphone', noHp),
                  const Divider(height: 24), _buildProfilRow(Icons.home_rounded, 'Alamat Domisili', alamat),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)), const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))]))
      ],
    );
  }
}