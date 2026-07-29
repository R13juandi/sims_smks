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

  // Mengambil daftar siswa dari tabel profiles beserta nisn dan kelas
  Future<void> _fetchSiswa() async {
    try {
      // 🔥 REVISI: Disesuaikan dengan standar kolom DB kita (nisn, nipd)
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, nisn, nipd, nis, kelas')
          .eq('role', 'siswa')
          .order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          _allSiswa = List<Map<String, dynamic>>.from(response);
          _filteredSiswa = _allSiswa;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mengambil data siswa: $e')),
        );
      }
    }
  }

  // Logika Pencarian Dinamis (Nama, NISN, atau Kelas)
  void _filterSiswa(String query) {
    final search = query.toLowerCase().trim();
    setState(() {
      _filteredSiswa = _allSiswa.where((siswa) {
        final name = (siswa['full_name'] ?? '').toString().toLowerCase();
        final nisn = (siswa['nisn'] ?? siswa['nis'] ?? siswa['nipd'] ?? '').toString().toLowerCase();
        final kelas = (siswa['kelas'] ?? '').toString().toLowerCase();

        return name.contains(search) ||
            nisn.contains(search) ||
            kelas.contains(search);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Pilih Siswa & Rekap Nilai",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // 1. Kolom Pencarian
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                labelText: "Cari Nama, NISN, atau Kelas",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: _filterSiswa,
            ),
          ),

          // 2. List Siswa
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
                : _filteredSiswa.isEmpty
                    ? const Center(
                        child: Text(
                          "Siswa tidak ditemukan.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredSiswa.length,
                        itemBuilder: (context, index) {
                          final siswa = _filteredSiswa[index];
                          // 🔥 REVISI: Mengambil NISN dengan fallback yang aman
                          final nomorNis = siswa['nisn'] ?? siswa['nis'] ?? siswa['nipd'] ?? '-';
                          
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Icon(Icons.person, color: Colors.blue.shade900),
                              ),
                              title: Text(
                                siswa['full_name'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "NISN: $nomorNis | Kelas: ${siswa['kelas'] ?? '-'}",
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                              // 🔥 REVISI PAK HALIM: ROUTING KE HALAMAN BARU (BUKAN POP-UP DIALOG)
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailNilaiSiswaScreen(
                                      siswaId: siswa['id'],
                                      namaSiswa: siswa['full_name'] ?? '-',
                                      nisSiswa: nomorNis.toString(),
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