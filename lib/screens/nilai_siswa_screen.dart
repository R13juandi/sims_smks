import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NilaiSiswaScreen extends StatefulWidget {
  const NilaiSiswaScreen({super.key});

  @override
  State<NilaiSiswaScreen> createState() => _NilaiSiswaScreenState();
}

class _NilaiSiswaScreenState extends State<NilaiSiswaScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listSiswa = [];
  List<Map<String, dynamic>> _listNilai = [];
  bool _isLoading = true;

  String? _selectedSiswa;
  String _selectedSemester = 'Semester 1 (Ganjil)'; // 🔥 Diperbaiki
  String _selectedKategori = 'Tugas';
  String? _selectedMataPelajaran;
  List<String> _listMapel = [];

  // Variabel untuk Filter Data
  String? _selectedFilterMapel;

  final _nilaiController = TextEditingController();
  final _keteranganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;

      final profileRes = await _supabase.from('profiles').select('role, mapel, mata_pelajaran').eq('id', user!.id).maybeSingle();

      if (profileRes != null) {
        String role = profileRes['role'] ?? 'guru';

        // Toleransi pembacaan profil guru (mapel atau mata_pelajaran)
        String mapelGuru = profileRes['mapel'] ?? profileRes['mata_pelajaran'] ?? '';

        if (role == 'guru' && mapelGuru.isNotEmpty) {
          _listMapel = mapelGuru.split(',').map((e) => e.trim()).toList();
        } else {
          _listMapel = [
            'Matematika', 'Bahasa Indonesia', 'Bahasa Inggris', 'IPA', 'IPS', 
            'Informatika', 'PJOK', 'Seni Budaya', 'PPKn', 'Pendidikan Agama', 'Koding & Keterampilan Artificial (KKA)'
          ];
        }

        if (_listMapel.isNotEmpty) {
          _selectedMataPelajaran = _listMapel.first;
          _selectedFilterMapel = _listMapel.first;
        }
      }

      final siswaRes = await _supabase.from('profiles').select('id, full_name, kelas').eq('role', 'siswa').order('full_name', ascending: true);
      final nilaiRes = await _supabase.from('nilai').select('*, profiles(full_name)').order('tanggal', ascending: false);

      if (mounted) {
        setState(() {
          _listSiswa = List<Map<String, dynamic>>.from(siswaRes);
          _listNilai = List<Map<String, dynamic>>.from(nilaiRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _simpanNilai() async {
    if (_selectedSiswa == null || _nilaiController.text.isEmpty || _selectedMataPelajaran == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi data siswa, mata pelajaran, dan nilai!'), backgroundColor: Colors.orange));
      return;
    }

    try {
      String rawValue = _nilaiController.text.replaceAll(',', '.');
      double? parsedValue = double.tryParse(rawValue);
      if (parsedValue == null) throw 'Format angka pada nilai tidak valid.';

      // 🔥 INI KUNCINYA: Menggunakan 'mapel' sesuai screenshot Supabase
      await _supabase.from('nilai').insert({
        'siswa_id': _selectedSiswa,
        'semester': _selectedSemester,
        'kategori': _selectedKategori,
        'mapel': _selectedMataPelajaran, // <-- Diperbaiki
        'nilai': parsedValue,
        'keterangan': _keteranganController.text.trim(),
        'tanggal': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nilai siswa berhasil disimpan!'), backgroundColor: Colors.green));

      _nilaiController.clear();
      _keteranganController.clear();
      _selectedSiswa = null;

      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNilai = _selectedFilterMapel == null
        ? _listNilai
        : _listNilai.where((item) {
            String mapelDB = item['mapel'] ?? item['mata_pelajaran'] ?? '';
            return mapelDB == _selectedFilterMapel;
          }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen & Rekap Nilai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: Colors.blue[900], foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: Colors.white,
            tabs: [Tab(icon: Icon(Icons.add), text: 'Input Nilai'), Tab(icon: Icon(Icons.list_alt), text: 'Rekap Nilai')],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // TAB 1: INPUT NILAI
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ListView(
                      children: [
                        const Text('Pilih Siswa:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSiswa, isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: _listSiswa.map((s) => DropdownMenuItem<String>(value: s['id'].toString(), child: Text('${s['full_name']} (${s['kelas'] ?? '-'})'))).toList(),
                          onChanged: (val) => setState(() => _selectedSiswa = val),
                        ),
                        const SizedBox(height: 16),
                        const Text('Pilih Mata Pelajaran:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedMataPelajaran, decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: _listMapel.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setState(() => _selectedMataPelajaran = val),
                        ),
                        const SizedBox(height: 16),
                        const Text('Pilih Semester:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSemester, decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: ['Semester 1 (Ganjil)', 'Semester 2 (Genap)'].map((sem) => DropdownMenuItem<String>(value: sem, child: Text(sem))).toList(),
                          onChanged: (val) => setState(() => _selectedSemester = val!),
                        ),
                        const SizedBox(height: 16),
                        const Text('Kategori Nilai:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedKategori, decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: ['Tugas', 'Praktek', 'Ulangan Harian', 'UTS', 'UAS'].map((cat) => DropdownMenuItem<String>(value: cat, child: Text(cat))).toList(),
                          onChanged: (val) => setState(() => _selectedKategori = val!),
                        ),
                        const SizedBox(height: 16),
                        const Text('Nilai Angka:', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
                        TextField(controller: _nilaiController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Misal: 85.5', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        const Text('Keterangan (Opsional):', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6),
                        TextField(controller: _keteranganController, decoration: const InputDecoration(hintText: 'Catatan...', border: OutlineInputBorder())),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _simpanNilai, icon: const Icon(Icons.save), label: const Text('SIMPAN NILAI', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // TAB 2: REKAP NILAI
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilterMapel, decoration: const InputDecoration(labelText: 'Filter Berdasarkan Mata Pelajaran', border: OutlineInputBorder()),
                          items: _listMapel.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setState(() => _selectedFilterMapel = val),
                        ),
                      ),
                      Expanded(
                        child: filteredNilai.isEmpty
                            ? const Center(child: Text('Belum ada data nilai untuk mapel ini.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16), itemCount: filteredNilai.length,
                                itemBuilder: (context, index) {
                                  final nilai = filteredNilai[index];
                                  final profile = nilai['profiles'] ?? {};
                                  String mapelTampil = nilai['mapel'] ?? nilai['mata_pelajaran'] ?? '-';

                                  return Card(
                                    elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                                    child: ListTile(
                                      title: Text(profile['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Mapel: $mapelTampil\nSem: ${nilai['semester'] ?? '-'} | Kategori: ${nilai['kategori'] ?? '-'}\nNilai: ${nilai['nilai'] ?? '-'}', style: const TextStyle(height: 1.4)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          await _supabase.from('nilai').delete().eq('id', nilai['id']);
                                          _fetchData();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}