import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailNilaiSiswaScreen extends StatefulWidget {
  final String siswaId;
  final String namaSiswa;
  final String? nisSiswa;

  const DetailNilaiSiswaScreen({super.key, required this.siswaId, required this.namaSiswa, this.nisSiswa});

  @override
  State<DetailNilaiSiswaScreen> createState() => _DetailNilaiSiswaScreenState();
}

class _DetailNilaiSiswaScreenState extends State<DetailNilaiSiswaScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listNilai = [];
  bool _isLoading = true;
  String _userRole = 'siswa';

  final List<String> _listMapel = [
    'Pendidikan Agama dan Budi Pekerti', 'Pendidikan Pancasila (PPKn)', 'Bahasa Indonesia', 'Matematika', 'Bahasa Inggris', 'Pendidikan Jasmani, Olahraga, dan Kesehatan', 'Sejarah Indonesia', 'Seni Budaya', 'Informatika', 'Dasar-dasar Teknik Jaringan Komputer dan Telekomunikasi', 'Administrasi Sistem Jaringan', 'Teknologi Jaringan Berbasis Luas (WAN)', 'Administrasi Infrastruktur Jaringan', 'Teknologi Layanan Jaringan', 'Produk Kreatif dan Kewirausahaan',
  ];

  final List<String> _listKategori = ['Tugas', 'UTS', 'UAS', 'Praktek', 'Ulangan Harian'];

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndNilai();
  }

  Future<void> _fetchUserDataAndNilai() async {
    await _fetchUserData();
    await _fetchNilai();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
        if (res != null) { setState(() { _userRole = res['role'] ?? 'siswa'; }); }
      }
    } catch (_) {
      setState(() => _userRole = 'siswa');
    }
  }

  Future<void> _fetchNilai() async {
    try {
      setState(() => _isLoading = true);
      final response = await _supabase.from('nilai').select('*').eq('siswa_id', widget.siswaId).order('id', ascending: false);
      setState(() { _listNilai = List<Map<String, dynamic>>.from(response); _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showNilaiDialog({Map<String, dynamic>? nilaiItem}) {
    final isEdit = nilaiItem != null;
    String selectedMapel = isEdit ? nilaiItem['mata_pelajaran'] : _listMapel.first;
    String selectedKategori = isEdit ? (nilaiItem['kategori'] ?? _listKategori.first) : _listKategori.first;
    String selectedSemester = isEdit ? (nilaiItem['semester'] ?? 'Semester 1 (Ganjil)') : 'Semester 1 (Ganjil)';

    final nilaiController = TextEditingController(text: isEdit ? nilaiItem['nilai'].toString() : '');
    final keteranganController = TextEditingController(text: isEdit ? (nilaiItem['keterangan'] ?? '') : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? "Edit Nilai" : "Tambah Nilai Baru"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _listMapel.contains(selectedMapel) ? selectedMapel : _listMapel.first, isExpanded: true,
                      items: _listMapel.map((val) => DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedMapel = val!),
                      decoration: const InputDecoration(labelText: "Mata Pelajaran", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSemester, items: ['Semester 1 (Ganjil)', 'Semester 2 (Genap)'].map((val) => DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedSemester = val!),
                      decoration: const InputDecoration(labelText: "Semester", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _listKategori.contains(selectedKategori) ? selectedKategori : _listKategori.first,
                      items: _listKategori.map((val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedKategori = val!),
                      decoration: const InputDecoration(labelText: "Kategori Nilai", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nilaiController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Nilai Angka", border: OutlineInputBorder(), hintText: 'Misal: 85.5')),
                    const SizedBox(height: 12),
                    TextField(controller: keteranganController, decoration: const InputDecoration(labelText: "Keterangan (Opsional)", border: OutlineInputBorder(), hintText: 'Catatan guru...')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
                  onPressed: () async {
                    String rawValue = nilaiController.text.replaceAll(',', '.');
                    final nilaiAngka = double.tryParse(rawValue);
                    if (nilaiAngka == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi nilai angka dengan benar!'))); return; }
                    try {
                      if (isEdit) {
                        await _supabase.from('nilai').update({'mata_pelajaran': selectedMapel, 'semester': selectedSemester, 'kategori': selectedKategori, 'nilai': nilaiAngka, 'keterangan': keteranganController.text.trim()}).eq('id', nilaiItem['id']);
                      } else {
                        await _supabase.from('nilai').insert({'siswa_id': widget.siswaId, 'mata_pelajaran': selectedMapel, 'semester': selectedSemester, 'kategori': selectedKategori, 'nilai': nilaiAngka, 'keterangan': keteranganController.text.trim(), 'tanggal': DateTime.now().toIso8601String()});
                      }
                      if (!mounted) return;
                      Navigator.pop(context); _fetchNilai();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nilai berhasil disimpan.')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saat menyimpan nilai: $e')));
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _hapusNilai(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Nilai"), content: const Text("Apakah Anda yakin ingin menghapus data nilai ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(onPressed: () async { await _supabase.from('nilai').delete().eq('id', id); if (mounted) { Navigator.pop(context); _fetchNilai(); } }, child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text("Nilai: ${widget.namaSiswa}", style: const TextStyle(fontSize: 16)), backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'kepsek' || _userRole == 'guru')
          ? FloatingActionButton.extended(backgroundColor: const Color(0xFF1E40AF), onPressed: () => _showNilaiDialog(), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Input Nilai', style: TextStyle(color: Colors.white)))
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.namaSiswa, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))), const SizedBox(height: 4), Text("NIS: ${widget.nisSiswa ?? '-'}", style: const TextStyle(color: Colors.grey, fontSize: 14))]),
            ),
            const SizedBox(height: 16),
            const Text('Histori Input Nilai Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _listNilai.isEmpty
                  ? const Center(child: Text("Belum ada data nilai. Tekan tombol Input Nilai.", textAlign: TextAlign.center))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blue.shade50), columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                            DataColumn(label: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                            DataColumn(label: Text('Semester', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                            DataColumn(label: Text('Nilai', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                          ],
                          rows: _listNilai.map((nilai) {
                            return DataRow(
                              cells: [
                                DataCell(Text(nilai['mata_pelajaran'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                DataCell(Text(nilai['kategori'] ?? '-', style: const TextStyle(fontSize: 13))),
                                DataCell(Text(nilai['semester']?.toString().replaceAll('Semester 1 ', '').replaceAll('Semester 2 ', '') ?? '-', style: const TextStyle(fontSize: 13))),
                                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(nilai['nilai'].toString(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)))),
                                DataCell((_userRole == 'admin' || _userRole == 'kepsek' || _userRole == 'guru') ? Row(children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showNilaiDialog(nilaiItem: nilai)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _hapusNilai(nilai['id'].toString()))]) : const Text('-')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}