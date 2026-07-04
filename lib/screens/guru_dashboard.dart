import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import 'absensi_screen.dart';
import 'rekap_absensi_guru_screen.dart';
import 'detail_user_screen.dart';

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

      final jadwalRes = await _supabase
          .from('jadwal')
          .select('*')
          .ilike('guru_pengampu', '%$namaGuru%');

      Set<String> kelasUnik = {};
      for (var j in jadwalRes) {
        if (j['kelas'] != null && j['kelas'].toString().isNotEmpty) {
          kelasUnik.add(j['kelas'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _semuaJadwalGuru = List<Map<String, dynamic>>.from(jadwalRes);
          _kelasDariJadwal = kelasUnik.isNotEmpty 
              ? kelasUnik.toList() 
              : List<String>.from(_biodataGuru['kelas_mengajar'] ?? []);
          _kelasDariJadwal.sort(); 
        });
      }
      
      final tanggalSekarang = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final pendingRes = await _supabase
          .from('absensi')
          .select('id')
          .eq('tanggal', tanggalSekarang)
          .ilike('guru_pengampu', '%$namaGuru%')
          .eq('status_verifikasi', 'Pending');
          
      if (mounted) {
        setState(() {
          _jumlahAbsenPending = List.from(pendingRes).length;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Dashboard Pendidik',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            tooltip: 'Keluar Aplikasi',
            onPressed: () async {
              await _supabase.auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false,
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
                decoration: BoxDecoration(
                  color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)
                ),
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
                        icon: Icons.fact_check_rounded, color: Colors.blue, title: 'Absen\nSiswa',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AbsencesScreenAtGuru())),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuCard(
                        icon: Icons.receipt_long_rounded, color: Colors.green, title: 'Rekap\nAbsensi', badgeCount: _jumlahAbsenPending,
                        onTap: () async {
                           await Navigator.push(context, MaterialPageRoute(builder: (context) => const RekapAbsensiGuruScreen()));
                          _loadGuruData();
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
                        icon: Icons.edit_document, color: Colors.orange.shade700, title: 'Buku\nNilai',
                        onTap: () => Navigator.push(
                          context, MaterialPageRoute(
                            builder: (context) => InputNilaiGuruScreen(
                              biodataGuru: _biodataGuru, kelasMengajar: _kelasDariJadwal, mapelGuru: _mapelGuru,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuCard(
                        icon: Icons.groups_rounded, color: Colors.purple, title: 'Daftar\nSiswa',
                        onTap: () => Navigator.push(
                          context, MaterialPageRoute(
                            builder: (context) => DaftarSiswaGuruScreen(
                              kelasMengajar: _kelasDariJadwal, siswaPerKelas: _siswaPerKelas,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuCard(
                        icon: Icons.calendar_month_rounded, color: Colors.red.shade700, title: 'Jadwal Mengajar Anda',
                        onTap: () => Navigator.push(
                          context, MaterialPageRoute(
                            builder: (context) => JadwalMengajarGuruScreen(semuaJadwalGuru: _semuaJadwalGuru),
                          ),
                        ),
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
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => DetailProfilGuruScreen(biodata: _biodataGuru)));
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
            borderRadius: BorderRadius.circular(24),
          ),
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
                    Text(
                      _kelasDariJadwal.isEmpty ? 'Belum ada jadwal mengajar.' : 'Mengajar Kelas: ${_kelasDariJadwal.join(", ")}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
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
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                Icon(icon, color: color, size: 32), const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -5, right: -5,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class AbsencesScreenAtGuru extends AbsensiScreen {
  const AbsencesScreenAtGuru({super.key});
}

class JadwalMengajarGuruScreen extends StatelessWidget {
  final List<Map<String, dynamic>> semuaJadwalGuru;
  const JadwalMengajarGuruScreen({super.key, required this.semuaJadwalGuru});

  Map<String, Map<String, List<Map<String, dynamic>>>> _groupJadwalByKelasAndHari() {
    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (var j in semuaJadwalGuru) {
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
      body: semuaJadwalGuru.isEmpty
          ? Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Anda belum memiliki jadwal mengajar di sistem.', style: TextStyle(color: Colors.grey, fontSize: 13))))
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
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                leading: const Icon(Icons.play_arrow_rounded, color: Colors.green, size: 20),
                                title: Text(j['mata_pelajaran'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: Text('Sesi: ${j['sesi'] ?? '-'} | Pukul: ${j['jam_mulai']} - ${j['jam_selesai']}', style: const TextStyle(fontSize: 12)),
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
    );
  }
}

// ====================================================================================
// 🔥 HALAMAN BUKU NILAI GURU (INPUT & REKAP JADI SATU) + VALIDASI KEREN 0-100
// ====================================================================================
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
  String? _selectedSemesterNilai;
  String? _selectedKategoriNilai;

  List<Map<String, dynamic>> _listSiswaNilai = [];
  final Map<String, TextEditingController> _nilaiControllers = {};
  
  final Map<String, int> _existingNilaiIds = {};

  final List<String> _listKategori = ['Ulangan Harian', 'UTS', 'UAS', 'Tugas', 'Praktek'];

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
    if (_selectedKelasNilai == null || _selectedMapelNilai == null || _selectedSemesterNilai == null || _selectedKategoriNilai == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mohon lengkapi seluruh filter di atas!'), backgroundColor: Colors.orange));
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
          .eq('semester', _selectedSemesterNilai!)
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 FUNGSI NOTIFIKASI KEREN JIKA NILAI TIDAK MASUK AKAL (<0 atau >100)
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.red, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gagal Menyimpan!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nilai harus berada di rentang 0 sampai 100. Sistem menolak penyimpanan karena ada nilai yang tidak wajar pada siswa berikut:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(
                    daftarSiswaError.join(', '),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14)
                    ),
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
    // 🔥 1. VALIDASI PRE-SAVE (Cek angka melebihi 100 atau kurang dari 0)
    List<String> invalidInputs = [];
    
    for (var s in _listSiswaNilai) {
      String sId = s['id'].toString();
      String nilaiInput = _nilaiControllers[sId]!.text.trim();
      
      if (nilaiInput.isNotEmpty) {
        double? cekNilai = double.tryParse(nilaiInput.replaceAll(',', '.'));
        if (cekNilai == null || cekNilai < 0 || cekNilai > 100) {
          invalidInputs.add(s['full_name']); // Catat nama murid yang nilainya salah
        }
      }
    }

    // Jika ada yang salah, tampilkan Popup Keren dan Hentikan Save
    if (invalidInputs.isNotEmpty) {
      _tampilkanPesanErrorNilai(invalidInputs);
      return;
    }

    // 2. LANJUT SIMPAN JIKA SEMUA VALID
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
          'semester': _selectedSemesterNilai,
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada nilai yang diinputkan.'), backgroundColor: Colors.orange));
        setState(() => _isLoading = false);
        return;
      }

      await _supabase.from('nilai').upsert(batchNilaiInsert);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buku Nilai (Rekap) sukses disimpan & diperbarui!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
      setState(() => _showFormNilai = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
          const Text('Atur Detail Kelas & Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
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
                  _buildDropdown(_selectedSemesterNilai, 'Pilih Semester', ['Semester 1 (Ganjil)', 'Semester 2 (Genap)'], (v) => setState(() => _selectedSemesterNilai = v)),
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
            Text('Kelas $_selectedKelasNilai | $_selectedMapelNilai', style: const TextStyle(fontSize: 11, color: Colors.blue)),
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

class DaftarSiswaGuruScreen extends StatelessWidget {
  final List<String> kelasMengajar;
  final Map<String, List<Map<String, dynamic>>> siswaPerKelas;

  const DaftarSiswaGuruScreen({
    super.key,
    required this.kelasMengajar,
    required this.siswaPerKelas,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Daftar Siswa Binaan', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: kelasMengajar.isEmpty 
          ? const Center(child: Text("Anda belum memiliki jadwal mengajar terdaftar.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: kelasMengajar.length,
              itemBuilder: (context, index) {
                String kelas = kelasMengajar[index];
                List<Map<String, dynamic>> siswaList = siswaPerKelas[kelas] ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  child: ExpansionTile(
                    shape: const Border(),
                    leading: const Icon(Icons.folder_open_rounded, color: Colors.amber, size: 30),
                    title: Text('Data Siswa Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold)),
                    children: siswaList.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(16), child: Text('Tidak ada siswa.'))]
                        : siswaList.map((s) => ListTile(
                                leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.person, color: Color(0xFF1E40AF))),
                                title: Text(s['full_name'] ?? '-'),
                                subtitle: Text('NISN: ${s['nisn'] ?? '-'}'),
                              )).toList(),
                  ),
                );
              },
            ),
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