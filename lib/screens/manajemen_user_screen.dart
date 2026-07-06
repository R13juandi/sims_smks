import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tambah_user_screen.dart';

class ManajemenUserScreen extends StatefulWidget {
  final String currentUserRole; // Diterima dari dashboard
  const ManajemenUserScreen({super.key, this.currentUserRole = 'admin'});

  @override
  State<ManajemenUserScreen> createState() => _ManajemenUserScreenState();
}

class _ManajemenUserScreenState extends State<ManajemenUserScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<dynamic> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('profiles').select('*').order('full_name', ascending: true);
      setState(() { _allUsers = data; });
    } catch (e) {} finally { setState(() => _isLoading = false); }
  }

  void _showEditDialog(Map<String, dynamic> user) {
    if (widget.currentUserRole == 'kepsek') return; // PROTEKSI KEPSEK

    final namaCtrl = TextEditingController(text: user['full_name']);
    final nisnCtrl = TextEditingController(text: user['nisn'] ?? '');
    final kelasCtrl = TextEditingController(text: user['kelas'] ?? '');
    String roleValue = user['role'] ?? 'siswa';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Akun & Sandi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
              TextField(controller: nisnCtrl, decoration: const InputDecoration(labelText: 'NISN / NIP')),
              TextField(controller: kelasCtrl, decoration: const InputDecoration(labelText: 'Kelas (Untuk Siswa)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: roleValue, decoration: const InputDecoration(labelText: 'Hak Akses (Role)'),
                items: ['siswa', 'guru', 'admin', 'tata_usaha', 'kepsek'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                onChanged: (val) { if (val != null) roleValue = val; },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                  children: [
                    const Text('Lupa Password?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    const SizedBox(height: 4),
                    const Text('Kirim link pembuatan sandi baru ke email siswa.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                      icon: const Icon(Icons.lock_reset, size: 18), label: const Text('Kirim Link Reset Sandi'),
                      onPressed: () async {
                        try {
                          await _supabase.auth.resetPasswordForEmail(user['email'] ?? '');
                          if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terkirim ke Email!'), backgroundColor: Colors.green)); }
                        } catch (e) {}
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _supabase.from('profiles').update({'full_name': namaCtrl.text, 'nisn': nisnCtrl.text, 'kelas': kelasCtrl.text, 'role': roleValue}).eq('id', user['id']);
                if (context.mounted) { Navigator.pop(context); _fetchUsers(); }
              } catch (e) {}
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String nama) {
    if (widget.currentUserRole == 'kepsek') return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Permanen?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('Hapus $nama beserta seluruh nilainya?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try { await _supabase.from('profiles').delete().eq('id', id); if (context.mounted) { Navigator.pop(context); _fetchUsers(); } } catch (e) {}
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. FILTER BERDASARKAN PENCARIAN
    List<dynamic> filtered = _allUsers.where((u) {
      if (_searchQuery.isEmpty) return true;
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final kelas = (u['kelas'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || kelas.contains(_searchQuery);
    }).toList();

    // 2. BAGI DUA (SISWA DAN STAF)
    List<dynamic> listSiswa = filtered.where((u) => u['role'] == 'siswa').toList();
    List<dynamic> listStaf = filtered.where((u) => u['role'] != 'siswa').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Database Pengguna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white, elevation: 0,
        bottom: TabBar(
          controller: _tabController, labelColor: const Color(0xFF1E40AF), indicatorColor: const Color(0xFF1E40AF),
          tabs: const [Tab(icon: Icon(Icons.school), text: 'Data Siswa'), Tab(icon: Icon(Icons.supervisor_account), text: 'Data Staf/Guru')],
        ),
      ),
      // SEMBUNYIKAN TOMBOL TAMBAH JIKA KEPSEK
      floatingActionButton: widget.currentUserRole == 'kepsek' ? null : FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E40AF),
        onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => TambahUserScreen())); if (result == true) _fetchUsers(); },
        icon: const Icon(Icons.add, color: Colors.white), label: const Text('Tambah Baru', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(hintText: 'Cari nama atau kelas...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              onChanged: (val) { setState(() => _searchQuery = val.trim().toLowerCase()); },
            ),
          ),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // LIST SISWA
                      ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: listSiswa.length,
                        itemBuilder: (c, i) => _buildUserCard(listSiswa[i], isKepsek: widget.currentUserRole == 'kepsek'),
                      ),
                      // LIST GURU/ADMIN
                      ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: listStaf.length,
                        itemBuilder: (c, i) => _buildUserCard(listStaf[i], isKepsek: widget.currentUserRole == 'kepsek'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user, {required bool isKepsek}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.person, color: Color(0xFF1E40AF))),
        title: Text(user['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Role: ${user['role'].toString().toUpperCase()}\nKelas/NIP: ${user['kelas'] ?? user['nisn'] ?? '-'}', style: const TextStyle(fontSize: 12)), 
        // SEMBUNYIKAN TOMBOL EDIT/HAPUS JIKA KEPSEK
        trailing: isKepsek ? null : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditDialog(user)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(user['id'], user['full_name'])),
          ],
        ),
      ),
    );
  }
}