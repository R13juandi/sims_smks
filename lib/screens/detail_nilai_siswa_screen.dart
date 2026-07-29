import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/popup_service.dart'; // 🔥 IMPOR POPUP TENGAH LAYAR

class DetailNilaiSiswaScreen extends StatefulWidget {
  final String siswaId;
  final String namaSiswa;
  final String? nisSiswa;

  const DetailNilaiSiswaScreen({
    super.key,
    required this.siswaId,
    required this.namaSiswa,
    this.nisSiswa,
  });

  @override
  State<DetailNilaiSiswaScreen> createState() => _DetailNilaiSiswaScreenState();
}

class _DetailNilaiSiswaScreenState extends State<DetailNilaiSiswaScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listNilai = [];
  bool _isLoading = true;
  String _userRole = 'siswa';

  // 🔥 VARIABEL SEMESTER BERJALAN (OTOMATIS DARI DATABASE)
  String _semesterBerjalan = 'Semester 1 (Ganjil)';

  final List<String> _listMapel = [
    'Pendidikan Agama dan Budi Pekerti',
    'Pendidikan Pancasila (PPKn)',
    'Bahasa Indonesia',
    'Matematika',
    'Bahasa Inggris',
    'Pendidikan Jasmani, Olahraga, dan Kesehatan',
    'Sejarah Indonesia',
    'Seni Budaya',
    'Informatika',
    'Dasar-dasar Teknik Jaringan Komputer dan Telekomunikasi',
    'Administrasi Sistem Jaringan',
    'Teknologi Jaringan Berbasis Luas (WAN)',
    'Administrasi Infrastruktur Jaringan',
    'Teknologi Layanan Jaringan',
    'Produk Kreatif dan Kewirausahaan',
  ];

  // 🔥 REVISI DOSEN: Ulangan Harian ditaruh di urutan pertama agar konsisten
  final List<String> _listKategori = [
    'Ulangan Harian',
    'Tugas',
    'Praktek',
    'PTS',
    'PAS',
    'UTS',
    'UAS'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndNilai();
  }

  Future<void> _fetchUserDataAndNilai() async {
    await _fetchSemesterBerjalan();
    await _fetchUserData();
    await _fetchNilai();
  }

  // =========================================================================
  // 🔥 REVISI DOSEN: MENGAMBIL SEMESTER BERJALAN DARI PENGATURAN SISTEM
  // =========================================================================
  Future<void> _fetchSemesterBerjalan() async {
    try {
      final config = await _supabase.from('pengaturan_sistem').select().maybeSingle();
      if (config != null && config['semester_aktif'] != null) {
        String smt = config['semester_aktif'].toString();
        setState(() {
          _semesterBerjalan = smt.toLowerCase().contains('genap') || smt.contains('2')
              ? 'Semester 2 (Genap)'
              : 'Semester 1 (Ganjil)';
        });
      }
    } catch (_) {
      // Fallback aman jika tabel belum di-seed
      setState(() => _semesterBerjalan = 'Semester 1 (Ganjil)');
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
        if (res != null) {
          setState(() {
            _userRole = res['role'] ?? 'siswa';
          });
        }
      }
    } catch (_) {
      setState(() => _userRole = 'siswa');
    }
  }

  Future<void> _fetchNilai() async {
    try {
      setState(() => _isLoading = true);
      // 🔥 Kueri dikunci HANYA untuk Semester Berjalan (Sesuai arahan Pak Halim)
      final response = await _supabase
          .from('nilai')
          .select('*')
          .eq('siswa_id', widget.siswaId)
          .eq('semester', _semesterBerjalan)
          .order('id', ascending: false);
      setState(() {
        _listNilai = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // 🔥 DIALOG INPUT NILAI GURU (TANPA PILIHAN SEMESTER MANUAL)
  // =========================================================================
  void _showNilaiDialog({Map<String, dynamic>? nilaiItem}) {
    final isEdit = nilaiItem != null;
    String selectedMapel = isEdit ? (nilaiItem['mata_pelajaran'] ?? _listMapel.first) : _listMapel.first;
    String selectedKategori = isEdit ? (nilaiItem['kategori'] ?? _listKategori.first) : _listKategori.first;

    final nilaiController = TextEditingController(text: isEdit ? nilaiItem['nilai'].toString() : '');
    final keteranganController = TextEditingController(text: isEdit ? (nilaiItem['keterangan'] ?? '') : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? "Edit Nilai" : "Input Nilai Baru", style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 INFO SEMESTER BERJALAN (READ-ONLY)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_clock_rounded, size: 18, color: Colors.blue.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Semester Berjalan: $_semesterBerjalan",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _listMapel.contains(selectedMapel) ? selectedMapel : _listMapel.first,
                      isExpanded: true,
                      items: _listMapel.map((val) => DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedMapel = val!),
                      decoration: const InputDecoration(labelText: "Mata Pelajaran", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _listKategori.contains(selectedKategori) ? selectedKategori : _listKategori.first,
                      items: _listKategori.map((val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedKategori = val!),
                      decoration: const InputDecoration(labelText: "Kategori Nilai", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nilaiController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Nilai Angka (0 - 100)", border: OutlineInputBorder(), hintText: 'Misal: 85.5'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keteranganController,
                      decoration: const InputDecoration(labelText: "Keterangan (Opsional)", border: OutlineInputBorder(), hintText: 'Catatan guru...'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  onPressed: () async {
                    String rawValue = nilaiController.text.replaceAll(',', '.');
                    final nilaiAngka = double.tryParse(rawValue);
                    if (nilaiAngka == null || nilaiAngka < 0 || nilaiAngka > 100) {
                      PopupService.show(context, 'Isi nilai angka antara 0 - 100 dengan benar!', isSuccess: false, judul: 'Peringatan');
                      return;
                    }
                    try {
                      if (isEdit) {
                        await _supabase.from('nilai').update({
                          'mata_pelajaran': selectedMapel,
                          'semester': _semesterBerjalan, // 🔥 SELALU KUNCI KE SEMESTER BERJALAN
                          'kategori': selectedKategori,
                          'nilai': nilaiAngka,
                          'keterangan': keteranganController.text.trim()
                        }).eq('id', nilaiItem['id']);
                      } else {
                        await _supabase.from('nilai').insert({
                          'siswa_id': widget.siswaId,
                          'mata_pelajaran': selectedMapel,
                          'semester': _semesterBerjalan, // 🔥 SELALU KUNCI KE SEMESTER BERJALAN
                          'kategori': selectedKategori,
                          'nilai': nilaiAngka,
                          'keterangan': keteranganController.text.trim(),
                          'tanggal': DateTime.now().toIso8601String()
                        });
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                      _fetchNilai();
                      PopupService.show(context, 'Nilai berhasil disimpan.', isSuccess: true);
                    } catch (e) {
                      PopupService.show(context, 'Error saat menyimpan nilai: $e', isSuccess: false, judul: 'Gagal');
                    }
                  },
                  child: const Text("Simpan", style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text("Hapus Nilai"),
        content: const Text("Apakah Anda yakin ingin menghapus data nilai ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              await _supabase.from('nilai').delete().eq('id', id);
              if (mounted) {
                Navigator.pop(context);
                _fetchNilai();
                PopupService.show(context, 'Nilai berhasil dihapus.', isSuccess: true);
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Buku Nilai: ${widget.namaSiswa}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'kepsek' || _userRole == 'guru')
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1E40AF),
              onPressed: () => _showNilaiDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Input Nilai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.namaSiswa, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                      const SizedBox(height: 4),
                      Text("NIS: ${widget.nisSiswa ?? '-'}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade300)),
                    child: Text(_semesterBerjalan, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Histori Input Nilai (Semester Berjalan)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _listNilai.isEmpty
                      ? const Center(child: Text("Belum ada data nilai di semester berjalan ini.\nTekan tombol Input Nilai.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blue.shade50),
                              columnSpacing: 20,
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
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                      child: Text(nilai['nilai'].toString(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                    )),
                                    DataCell((_userRole == 'admin' || _userRole == 'kepsek' || _userRole == 'guru')
                                        ? Row(children: [
                                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showNilaiDialog(nilaiItem: nilai)),
                                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _hapusNilai(nilai['id'].toString()))
                                          ])
                                        : const Text('-')),
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