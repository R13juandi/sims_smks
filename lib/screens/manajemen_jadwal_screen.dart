import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManajemenJadwalScreen extends StatefulWidget {
  const ManajemenJadwalScreen({super.key});

  @override
  State<ManajemenJadwalScreen> createState() => _ManajemenJadwalScreenState();
}

class _ManajemenJadwalScreenState extends State<ManajemenJadwalScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedHari, _selectedKelas, _selectedGuru, _selectedMapel;
  Map<String, String>? _selectedSesi;

  final List<String> _listHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'];
  final List<String> _listKelas = ['X TKJ', 'XI TKJ', 'XII TKJ'];

  // DATA JAM PELAJARAN OTOMATIS (Dari Excel Sekolah)
  final List<Map<String, String>> _listSesiPelajaran = [
    {
      'nama': 'Jam ke-1 (07:30 - 08:00)',
      'mulai': '07:30:00',
      'selesai': '08:00:00',
    },
    {
      'nama': 'Jam ke-2 (08:00 - 08:30)',
      'mulai': '08:00:00',
      'selesai': '08:30:00',
    },
    {
      'nama': 'Jam ke-3 (08:30 - 09:00)',
      'mulai': '08:30:00',
      'selesai': '09:00:00',
    },
    {
      'nama': 'Jam ke-4 (09:00 - 09:30)',
      'mulai': '09:00:00',
      'selesai': '09:30:00',
    },
    {
      'nama': 'Jam ke-5 (09:30 - 10:00)',
      'mulai': '09:30:00',
      'selesai': '10:00:00',
    },
    {
      'nama': 'Jam ke-6 (10:30 - 11:00)',
      'mulai': '10:30:00',
      'selesai': '11:00:00',
    },
    {
      'nama': 'Jam ke-7 (11:00 - 11:30)',
      'mulai': '11:00:00',
      'selesai': '11:30:00',
    },
    {
      'nama': 'Jam ke-8 (11:30 - 12:00)',
      'mulai': '11:30:00',
      'selesai': '12:00:00',
    },
    {
      'nama': 'Jam ke-9 (12:45 - 13:10)',
      'mulai': '12:45:00',
      'selesai': '13:10:00',
    },
    {
      'nama': 'Jam ke-10 (13:10 - 13:35)',
      'mulai': '13:10:00',
      'selesai': '13:35:00',
    },
  ];

  List<String> _listGuruTerfilter = [];
  List<dynamic> _dataGuruLengkap = [];
  List<String> _mapelGuruTerfilter = [];

  Future<void> _autoFillGuruDanMapel(String kelasTerpilih) async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('full_name, mapel, kelas_mengajar, email')
          .eq('role', 'guru');
      String kS = kelasTerpilih
          .replaceAll('.', '')
          .replaceAll(' ', '')
          .toUpperCase();

      List<String> gD = [];
      List<dynamic> dD = [];

      for (var guru in res) {
        List<dynamic> kelasArray = guru['kelas_mengajar'] ?? [];
        for (var k in kelasArray) {
          if (k
                  .toString()
                  .replaceAll('.', '')
                  .replaceAll(' ', '')
                  .toUpperCase() ==
              kS) {
            if (!gD.contains(guru['full_name'])) {
              gD.add(guru['full_name']);
              dD.add(guru);
            }
            break;
          }
        }
      }

      setState(() {
        _listGuruTerfilter = gD;
        _dataGuruLengkap = dD;
        _selectedGuru = null;
        _selectedMapel = null;
        _selectedHari = null;
        _mapelGuruTerfilter = [];
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onGuruDipilih(String? namaGuru) {
    if (namaGuru == null) return;
    setState(() {
      _selectedGuru = namaGuru;
      _selectedMapel = null;
      final guruData = _dataGuruLengkap.firstWhere(
        (g) => g['full_name'] == namaGuru,
        orElse: () => null,
      );

      if (guruData != null) {
        _mapelGuruTerfilter = List<String>.from(guruData['mapel'] ?? []);
        String emailGuru = (guruData['email'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        // HARI OTOMATIS BERDASARKAN EMAIL GURU
        if (emailGuru == 'guru1@sekolah.com')
          _selectedHari = 'Senin';
        else if (emailGuru == 'guru2@sekolah.com')
          _selectedHari = 'Selasa';
        else if (emailGuru == 'guru3@sekolah.com')
          _selectedHari = 'Rabu';
        else if (emailGuru == 'rizkyjuandi3@gmail.com')
          _selectedHari = 'Kamis';
        else if (emailGuru == 'guru4@sekolah.com')
          _selectedHari = 'Jumat';
        else
          _selectedHari = null;
      } else {
        _mapelGuruTerfilter = [];
        _selectedHari = null;
      }
    });
  }

  Future<void> _simpanJadwal() async {
    if (_selectedHari == null ||
        _selectedKelas == null ||
        _selectedGuru == null ||
        _selectedMapel == null ||
        _selectedSesi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi semua data!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.from('jadwal').insert({
        'hari': _selectedHari,
        'kelas': _selectedKelas,
        'mata_pelajaran': _selectedMapel!.trim(),
        'guru_pengampu': _selectedGuru,
        'sesi': _selectedSesi!['nama'],
        'jam_mulai': _selectedSesi!['mulai'],
        'jam_selesai': _selectedSesi!['selesai'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal Berhasil Diterbitkan!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedHari = null;
        _selectedKelas = null;
        _selectedGuru = null;
        _selectedMapel = null;
        _selectedSesi = null;
        _listGuruTerfilter = [];
        _mapelGuruTerfilter = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Buat Jadwal Pelajaran',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FORMULIR PENYUSUNAN JADWAL SMART',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          const Divider(height: 24),
                          _buildLabel('1. Tentukan Kelas Target'),
                          DropdownButtonFormField<String>(
                            value: _selectedKelas,
                            hint: const Text('Pilih Kelas'),
                            decoration: InputDecoration(
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _listKelas
                                .map(
                                  (k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(k),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _selectedKelas = val);
                              if (val != null) _autoFillGuruDanMapel(val);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('2. Pilih Guru Pengampu'),
                          DropdownButtonFormField<String>(
                            value: _selectedGuru,
                            hint: Text(
                              _listGuruTerfilter.isEmpty
                                  ? 'Pilih kelas dahulu'
                                  : 'Pilih Guru',
                            ),
                            decoration: InputDecoration(
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _listGuruTerfilter
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ),
                                )
                                .toList(),
                            onChanged: _listGuruTerfilter.isEmpty
                                ? null
                                : _onGuruDipilih,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('3. Pilih Mata Pelajaran'),
                          DropdownButtonFormField<String>(
                            value: _selectedMapel,
                            hint: Text(
                              _mapelGuruTerfilter.isEmpty
                                  ? 'Pilih guru dahulu'
                                  : 'Pilih Mapel',
                            ),
                            decoration: InputDecoration(
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _mapelGuruTerfilter
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                            onChanged: _mapelGuruTerfilter.isEmpty
                                ? null
                                : (val) => setState(() => _selectedMapel = val),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('4. Hari Belajar (Otomatis/Manual)'),
                          DropdownButtonFormField<String>(
                            value: _listHari.contains(_selectedHari)
                                ? _selectedHari
                                : null,
                            hint: const Text('Pilih Hari'),
                            decoration: InputDecoration(
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _listHari
                                .map(
                                  (h) => DropdownMenuItem(
                                    value: h,
                                    child: Text(h),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedHari = val),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('5. Sesi Jam Pelajaran (Otomatis)'),
                          DropdownButtonFormField<Map<String, String>>(
                            value: _selectedSesi,
                            hint: const Text('Pilih Jam Pelajaran'),
                            decoration: InputDecoration(
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _listSesiPelajaran
                                .map(
                                  (sesi) =>
                                      DropdownMenuItem<Map<String, String>>(
                                        value: sesi,
                                        child: Text(
                                          sesi['nama']!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedSesi = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _simpanJadwal,
                      icon: const Icon(Icons.verified_user_rounded, size: 18),
                      label: const Text(
                        'PUBLIKASIKAN JADWAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
      ),
    ),
  );
}
