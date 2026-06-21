import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detail_nilai_siswa_screen.dart';

class RekapNilaiScreen extends StatefulWidget {
  const RekapNilaiScreen({super.key});

  @override
  State<RekapNilaiScreen> createState() => _RekapNilaiScreenState();
}

class _RekapNilaiScreenState extends State<RekapNilaiScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allSiswa = [];
  List<Map<String, dynamic>> _filteredSiswa = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSiswa();
  }

  // Mengambil daftar siswa dari tabel profiles beserta nis dan kelas
  Future<void> _fetchSiswa() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, nis, kelas')
          .eq('role', 'siswa');

      setState(() {
        _allSiswa = List<Map<String, dynamic>>.from(response);
        _filteredSiswa = _allSiswa;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error mengambil data: $e')));
    }
  }

  // Logika Pencarian Dinamis (Nama, NIS, atau Kelas)
  void _filterSiswa(String query) {
    final search = query.toLowerCase();
    setState(() {
      _filteredSiswa = _allSiswa.where((siswa) {
        final name = (siswa['full_name'] ?? '').toLowerCase();
        final nis = (siswa['nis'] ?? '').toString().toLowerCase();
        final kelas = (siswa['kelas'] ?? '').toLowerCase();

        return name.contains(search) ||
            nis.contains(search) ||
            kelas.contains(search);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Siswa & Rekap Nilai"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Kolom Pencarian
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Cari Nama, NIS, atau Kelas",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterSiswa,
            ),
          ),

          // 2. List Siswa
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSiswa.isEmpty
                ? const Center(child: Text("Siswa tidak ditemukan."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredSiswa.length,
                    itemBuilder: (context, index) {
                      final siswa = _filteredSiswa[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            siswa['full_name'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "NIS: ${siswa['nis'] ?? '-'} | Kelas: ${siswa['kelas'] ?? '-'}",
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailNilaiSiswaScreen(
                                  siswaId: siswa['id'],
                                  namaSiswa: siswa['full_name'] ?? '-',
                                  nisSiswa: siswa['nis']?.toString(),
                                ),
                              ),
                            );
                          },
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
