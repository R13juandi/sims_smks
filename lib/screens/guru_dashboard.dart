import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import 'absensi_screen.dart';
import 'rekap_absensi_guru_screen.dart';

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
  List<String> _kelasMengajar = [];
  List<String> _mapelGuru = [];
  Map<String, List<Map<String, dynamic>>> _siswaPerKelas = {};

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
          _kelasMengajar = List<String>.from(
            _biodataGuru['kelas_mengajar'] ?? [],
          );
          _mapelGuru = List<String>.from(_biodataGuru['mapel'] ?? []);
        });
      }

      final namaGuru = _biodataGuru['full_name']?.toString().trim() ?? '';

      final jadwalRes = await _supabase
          .from('jadwal')
          .select('*')
          .ilike('guru_pengampu', '%$namaGuru%');

      if (mounted) {
        setState(() {
          _semuaJadwalGuru = List<Map<String, dynamic>>.from(jadwalRes);
        });
      }

      if (_kelasMengajar.isNotEmpty) {
        final siswaRes = await _supabase
            .from('profiles')
            .select('id, full_name, nisn, kelas')
            .eq('role', 'siswa')
            .inFilter('kelas', _kelasMengajar)
            .order('full_name', ascending: true);

        if (mounted) {
          _siswaPerKelas.clear();
          for (var k in _kelasMengajar) {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
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
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
            tooltip: 'Keluar Aplikasi',
            onPressed: () async {
              await _supabase.auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 24),
          const Text(
            'Aksi Cepat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMenuCard(
                      icon: Icons.fact_check_rounded,
                      color: Colors.blue,
                      title: 'Absen\nSiswa',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AbsencesScreenAtGuru(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMenuCard(
                      icon: Icons.receipt_long_rounded,
                      color: Colors.green,
                      title: 'Rekap\nAbsensi',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RekapAbsensiGuruScreen(),
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
                      icon: Icons.edit_document,
                      color: Colors.orange.shade700,
                      title: 'Input\nNilai',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InputNilaiGuruScreen(
                            biodataGuru: _biodataGuru,
                            kelasMengajar: _kelasMengajar,
                            mapelGuru: _mapelGuru,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMenuCard(
                      icon: Icons.groups_rounded,
                      color: Colors.purple,
                      title: 'Daftar\nSiswa',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DaftarSiswaGuruScreen(
                            kelasMengajar: _kelasMengajar,
                            siswaPerKelas: _siswaPerKelas,
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
                      icon: Icons.calendar_month_rounded,
                      color: Colors.red.shade700,
                      title: 'Jadwal Mengajar Anda',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JadwalMengajarGuruScreen(
                            semuaJadwalGuru: _semuaJadwalGuru,
                          ),
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
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DetailProfilGuruScreen(biodata: _biodataGuru),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat Bertugas,',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      _biodataGuru['full_name'] ?? 'Guru',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mengajar Kelas: ${_kelasMengajar.join(", ")}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class AbsencesScreenAtGuru extends AbsensiScreen {
  const AbsencesScreenAtGuru({super.key});
}

// ====================================================================================
// 🔥 HALAMAN BARU: JADWAL MENGAJAR GURU (FOLDER KELAS & HARI)
// ====================================================================================
class JadwalMengajarGuruScreen extends StatelessWidget {
  final List<Map<String, dynamic>> semuaJadwalGuru;
  const JadwalMengajarGuruScreen({super.key, required this.semuaJadwalGuru});

  Map<String, Map<String, List<Map<String, dynamic>>>>
  _groupJadwalByKelasAndHari() {
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
      case 'senin':
        return 1;
      case 'selasa':
        return 2;
      case 'rabu':
        return 3;
      case 'kamis':
        return 4;
      case 'jumat':
        return 5;
      case 'sabtu':
        return 6;
      case 'minggu':
        return 7;
      default:
        return 8;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupJadwalByKelasAndHari();
    final sortedKelas = groupedData.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Jadwal Mengajar Anda',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: semuaJadwalGuru.isEmpty
          ? Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Anda belum memiliki jadwal mengajar di sistem.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: sortedKelas.map((kls) {
                final daysMap = groupedData[kls]!;
                final sortedDays = daysMap.keys.toList()
                  ..sort((a, b) => _dayIndex(a).compareTo(_dayIndex(b)));

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.shade100, width: 1.5),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(
                        Icons.folder_shared,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    title: Text(
                      'Kelas $kls',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    children: sortedDays.map((hari) {
                      final listJadwal = daysMap[hari]!;
                      return Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 8,
                        ),
                        child: Card(
                          elevation: 0,
                          color: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ExpansionTile(
                            shape: const Border(),
                            leading: const Icon(
                              Icons.calendar_today,
                              color: Colors.orange,
                              size: 20,
                            ),
                            title: Text(
                              'Hari $hari',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            children: listJadwal.map((j) {
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                leading: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                title: Text(
                                  j['mata_pelajaran'] ?? '-',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Sesi: ${j['sesi'] ?? '-'} | Pukul: ${j['jam_mulai']} - ${j['jam_selesai']}',
                                  style: const TextStyle(fontSize: 12),
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
    );
  }
}

// ====================================================================================
// HALAMAN: MANAJEMEN INPUT & REKAP NILAI GURU
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
  bool _showRekapNilai = false;

  String? _selectedKelasNilai;
  String? _selectedMapelNilai;
  String? _selectedSemesterNilai;
  String? _selectedKategoriNilai;

  List<Map<String, dynamic>> _listSiswaNilai = [];
  List<Map<String, dynamic>> _listRekapNilai = [];
  final Map<String, TextEditingController> _nilaiControllers = {};

  final List<String> _listKategori = [
    'Ujian Harian',
    'UTS',
    'UAS',
    'Tugas Mandiri',
    'Tugas Kelompok',
  ];

  @override
  void dispose() {
    for (var controller in _nilaiControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getTahunAjaranOtomatis() {
    final now = DateTime.now();
    return (now.month >= 7)
        ? '${now.year}/${now.year + 1}'
        : '${now.year - 1}/${now.year}';
  }

  Future<void> _panggilSiswaFormNilai() async {
    if (_selectedKelasNilai == null ||
        _selectedMapelNilai == null ||
        _selectedSemesterNilai == null ||
        _selectedKategoriNilai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi seluruh filter!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, nisn')
          .eq('role', 'siswa')
          .eq('kelas', _selectedKelasNilai!)
          .order('full_name', ascending: true);

      _listSiswaNilai = List<Map<String, dynamic>>.from(res);
      _nilaiControllers.forEach((key, value) => value.dispose());
      _nilaiControllers.clear();

      for (var s in _listSiswaNilai) {
        _nilaiControllers[s['id'].toString()] = TextEditingController();
      }

      setState(() {
        _showFormNilai = true;
        _showRekapNilai = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _panggilRekapNilai() async {
    if (_selectedKelasNilai == null ||
        _selectedMapelNilai == null ||
        _selectedSemesterNilai == null ||
        _selectedKategoriNilai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi seluruh filter!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('nilai')
          .select('*, siswa:profiles!nilai_siswa_id_fkey(full_name, nisn)')
          .eq('kelas', _selectedKelasNilai!)
          .eq('mapel', _selectedMapelNilai!)
          .eq('semester', _selectedSemesterNilai!)
          .eq('kategori', _selectedKategoriNilai!)
          .eq('tahun_ajaran', _getTahunAjaranOtomatis());

      setState(() {
        _listRekapNilai = List<Map<String, dynamic>>.from(res);
        _showRekapNilai = true;
        _showFormNilai = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simpanNilaiKeCloud() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> batchNilaiInsert = [];

      for (var s in _listSiswaNilai) {
        String sId = s['id'].toString();
        String nilaiInput = _nilaiControllers[sId]!.text.trim();
        if (nilaiInput.isEmpty) continue;

        batchNilaiInsert.add({
          'siswa_id': sId,
          'kelas': _selectedKelasNilai,
          'mapel': _selectedMapelNilai,
          'semester': _selectedSemesterNilai,
          'tahun_ajaran': _getTahunAjaranOtomatis(),
          'kategori': _selectedKategoriNilai,
          'nilai': double.tryParse(nilaiInput) ?? 0.0,
          'guru_pengampu': widget.biodataGuru['full_name'],
        });
      }

      if (batchNilaiInsert.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada nilai yang diinputkan.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      await _supabase
          .from('nilai')
          .upsert(
            batchNilaiInsert,
            onConflict: 'siswa_id, mapel, semester, kategori, tahun_ajaran',
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nilai siswa sukses diunggah!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _showFormNilai = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
        ),
      );
    if (_showFormNilai) return _buildFormInputBody();
    if (_showRekapNilai) return _buildRekapDetailBody();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Manajemen Nilai',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Penyusunan Form Nilai Siswa',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            _selectedKelasNilai,
            'Pilih Kelas Target',
            widget.kelasMengajar,
            (v) => setState(() => _selectedKelasNilai = v),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            _selectedMapelNilai,
            'Pilih Mata Pelajaran',
            widget.mapelGuru,
            (v) => setState(() => _selectedMapelNilai = v),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            _selectedSemesterNilai,
            'Pilih Semester',
            ['Semester 1 (Ganjil)', 'Semester 2 (Genap)'],
            (v) => setState(() => _selectedSemesterNilai = v),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            _selectedKategoriNilai,
            'Pilih Kategori Penilaian',
            _listKategori,
            (v) => setState(() => _selectedKategoriNilai = v),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  'Tahun Ajaran: ${_getTahunAjaranOtomatis()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _panggilSiswaFormNilai,
            child: const Text(
              'TAMPILKAN FORM INPUT SISWA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              foregroundColor: const Color(0xFF1E40AF),
              side: const BorderSide(color: Color(0xFF1E40AF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _panggilRekapNilai,
            child: const Text(
              'LIHAT REKAP NILAI TERINPUT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String? value,
    String hint,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint),
      decoration: const InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildFormInputBody() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Input: $_selectedKategoriNilai',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => setState(() => _showFormNilai = false),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _listSiswaNilai.length,
        itemBuilder: (context, index) {
          final s = _listSiswaNilai[index];
          String sId = s['id'].toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['full_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'NISN: ${s['nisn'] ?? '-'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _nilaiControllers[sId],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '0-100',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E40AF),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _simpanNilaiKeCloud,
          child: const Text(
            'SUBMIT SEMUA NILAI',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRekapDetailBody() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Laporan Nilai',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => setState(() => _showRekapNilai = false),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kelas: $_selectedKelasNilai',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _selectedSemesterNilai ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '📚 Mapel : $_selectedMapelNilai',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '📝 Kategori : $_selectedKategoriNilai',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _listRekapNilai.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data nilai masuk pada kategori ini.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _listRekapNilai.length,
                    itemBuilder: (context, index) {
                      final r = _listRekapNilai[index];
                      final profile = r['siswa'] ?? {};
                      final double nilai =
                          double.tryParse(r['nilai'].toString()) ?? 0.0;
                      final bool isLulus = nilai >= 75.0;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile['full_name'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'NISN: ${profile['nisn'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLulus
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isLulus
                                              ? Colors.green.shade200
                                              : Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        isLulus
                                            ? 'TUNTAS (LULUS)'
                                            : 'BELUM TUNTAS (REMEDIAL)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isLulus
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: isLulus
                                      ? const Color(0xFF1E40AF)
                                      : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    r['nilai'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================================
// HALAMAN: DAFTAR SISWA GURU (HANYA KELAS YANG DIAJAR)
// ====================================================================================
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
        title: const Text(
          'Daftar Siswa Binaan',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: kelasMengajar.length,
        itemBuilder: (context, index) {
          String kelas = kelasMengajar[index];
          List<Map<String, dynamic>> siswaList = siswaPerKelas[kelas] ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ExpansionTile(
              shape: const Border(),
              leading: const Icon(
                Icons.folder_open_rounded,
                color: Colors.amber,
                size: 30,
              ),
              title: Text(
                'Data Siswa Kelas $kelas',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: siswaList.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Tidak ada siswa.'),
                      ),
                    ]
                  : siswaList
                        .map(
                          (s) => ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(
                                Icons.person,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            title: Text(s['full_name'] ?? '-'),
                            subtitle: Text('NISN: ${s['nisn'] ?? '-'}'),
                          ),
                        )
                        .toList(),
            ),
          );
        },
      ),
    );
  }
}

// ====================================================================================
// HALAMAN: DETAIL PROFIL LENGKAP GURU
// ====================================================================================
class DetailProfilGuruScreen extends StatelessWidget {
  final Map<String, dynamic> biodata;
  const DetailProfilGuruScreen({super.key, required this.biodata});

  @override
  Widget build(BuildContext context) {
    final List<String> listKelas = List<String>.from(
      biodata['kelas_mengajar'] ?? [],
    );
    final List<String> listMapel = List<String>.from(biodata['mapel'] ?? []);

    final String nama = biodata['full_name'] ?? 'Guru';
    final String email =
        biodata['email'] ??
        Supabase.instance.client.auth.currentUser?.email ??
        '-';
    final String nik = biodata['nik'] ?? '-';
    final String jk = biodata['jk'] ?? biodata['jenis_kelamin'] ?? '-';
    final String agama = biodata['agama'] ?? '-';
    final String noHp = biodata['no_hp'] ?? biodata['nomor_hp'] ?? '-';
    final String alamat =
        biodata['alamat'] ?? biodata['alamat_domisili'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Profil Pendidik',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xFF1E40AF).withOpacity(0.1),
                  child: const Icon(
                    Icons.account_box_rounded,
                    size: 55,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  nama,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tenaga Pendidik / Guru',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'KOMPETENSI MENGAJAR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E40AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfilRow(
                    Icons.class_rounded,
                    'Mengajar Kelas',
                    listKelas.isEmpty ? '-' : listKelas.join(', '),
                  ),
                  const Divider(height: 24),
                  _buildProfilRow(
                    Icons.book_rounded,
                    'Mata Pelajaran',
                    listMapel.isEmpty ? '-' : listMapel.join(', '),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'INFORMASI BIODATA DIRI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E40AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfilRow(
                    Icons.badge_rounded,
                    'Nomor Induk Kependudukan (NIK)',
                    nik,
                  ),
                  const Divider(height: 24),
                  _buildProfilRow(Icons.email_rounded, 'Alamat Email', email),
                  const Divider(height: 24),
                  _buildProfilRow(Icons.wc_rounded, 'Jenis Kelamin', jk),
                  const Divider(height: 24),
                  _buildProfilRow(Icons.mosque_rounded, 'Agama', agama),
                  const Divider(height: 24),
                  _buildProfilRow(
                    Icons.phone_android_rounded,
                    'Nomor Handphone',
                    noHp,
                  ),
                  const Divider(height: 24),
                  _buildProfilRow(
                    Icons.home_rounded,
                    'Alamat Domisili',
                    alamat,
                  ),
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
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
