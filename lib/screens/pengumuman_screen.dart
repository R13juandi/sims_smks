import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PengumumanScreen extends StatefulWidget {
  const PengumumanScreen({super.key});

  @override
  State<PengumumanScreen> createState() => _PengumumanScreenState();
}

class _PengumumanScreenState extends State<PengumumanScreen> {
  final _supabase = Supabase.instance.client;
  final _judulController = TextEditingController();
  final _isiController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _listPengumuman = [];

  @override
  void initState() {
    super.initState();
    _fetchPengumuman();
  }

  @override
  void dispose() {
    _judulController.dispose();
    _isiController.dispose();
    super.dispose();
  }

  // Mengambil daftar pengumuman dari Supabase
  Future<void> _fetchPengumuman() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('pengumuman')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);

      setState(() {
        _listPengumuman = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Error fetch pengumuman: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Membuat pengumuman baru ke Supabase
  Future<void> _buatPengumuman() async {
    if (_judulController.text.trim().isEmpty ||
        _isiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul dan isi pengumuman tidak boleh kosong!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('pengumuman').insert({
        'judul': _judulController.text.trim(),
        'isi': _isiController.text.trim(),
        'penulis_id': user.id,
      });

      _judulController.clear();
      _isiController.clear();

      if (!mounted) return;
      Navigator.pop(context); // Tutup bottom sheet form

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengumuman berhasil diterbitkan!'),
          backgroundColor: Colors.green,
        ),
      );

      _fetchPengumuman(); // Refresh daftar pengumuman
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menerbitkan pengumuman: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Menampilkan Form Input Pengumuman (Bottom Sheet)
  void _showFormPengumuman() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buat Pengumuman Baru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _judulController,
                  decoration: InputDecoration(
                    labelText: 'Judul Pengumuman',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _isiController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Isi atau Konten Pengumuman',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _buatPengumuman,
                  child: const Text(
                    'TERBITKAN SEKARANG',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pengumuman Sekolah',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading && _listPengumuman.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
            )
          : _listPengumuman.isEmpty
          ? const Center(
              child: Text(
                'Belum ada pengumuman akademik.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchPengumuman,
              color: const Color(0xFF1E3A8A),
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _listPengumuman.length,
                itemBuilder: (context, index) {
                  final p = _listPengumuman[index];
                  final tgl = p['created_at'] != null
                      ? DateFormat(
                          'dd MMM yyyy, HH:mm',
                        ).format(DateTime.parse(p['created_at']))
                      : '-';
                  final penulis = p['profiles']?['full_name'] ?? 'Sistem';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p['judul'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.campaign_rounded,
                              color: Color(0xFF1E40AF),
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Oleh: $penulis • $tgl',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        Text(
                          p['isi'] ?? '-',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E40AF),
        onPressed: _showFormPengumuman,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
