import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detail_user_screen.dart';
import 'tambah_user_screen.dart';

class ManajemenUserScreen extends StatefulWidget {
  const ManajemenUserScreen({super.key});

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
  final List<String> _listKelasFolder = ['X TKJ', 'XI TKJ', 'XII TKJ'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('profiles').select('*').order('full_name', ascending: true);
      setState(() { _allUsers = data; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil data: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _filterUsersByRoleAndSearch(String role) {
    return _allUsers.where((user) {
      final userRole = (user['role'] ?? '').toString().toLowerCase();
      if (userRole != role) return false;
      if (_searchQuery.isEmpty) return true;
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final kelas = (user['kelas'] ?? '').toString().toLowerCase();
      final nisn = (user['nisn'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || kelas.contains(_searchQuery) || nisn.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Database Pengguna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
            Text('Panel Hak Akses: Tata Usaha (TU)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
          ],
        ),
        backgroundColor: Colors.white, elevation: 0,
        bottom: TabBar(
          controller: _tabController, labelColor: const Color(0xFF1E40AF), unselectedLabelColor: const Color(0xFF64748B), indicatorColor: const Color(0xFF1E40AF), labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(icon: Icon(Icons.school_rounded), text: 'Folder Siswa'), Tab(icon: Icon(Icons.supervisor_account_rounded), text: 'Daftar Guru')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E40AF),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const TambahUserScreen()));
          if (result == true) _fetchUsers();
        },
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text('Tambah Pengguna', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama, kelas, atau NISN...', prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) { setState(() => _searchQuery = val.trim().toLowerCase()); },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
                : TabBarView(controller: _tabController, children: [_buildTabSiswa(), _buildUserList('guru')]),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSiswa() {
    if (_searchQuery.isNotEmpty) { return _buildUserList('siswa'); }
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: _listKelasFolder.length,
      itemBuilder: (context, index) {
        final kelas = _listKelasFolder[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.folder_rounded, color: Colors.amber)),
            title: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15)), subtitle: const Text('Klik untuk melihat siswa', style: TextStyle(fontSize: 12)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => FolderSiswaDetailScreen(kelas: kelas, allUsers: _allUsers)));
              if (result == true) _fetchUsers();
            },
          ),
        );
      },
    );
  }

  Widget _buildUserList(String role) {
    final filteredList = _filterUsersByRoleAndSearch(role);
    if (filteredList.isEmpty) { return Center(child: Text('Tidak ada data ${role == 'siswa' ? 'Siswa' : 'Guru'} ditemukan', style: const TextStyle(color: Color(0xFF64748B)))); }
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final user = filteredList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: role == 'siswa' ? const Color(0xFFDBEAFE) : const Color(0xFFDCEFDC), child: Icon(role == 'siswa' ? Icons.person : Icons.badge_rounded, color: role == 'siswa' ? const Color(0xFF1E40AF) : Colors.green[800])),
            title: Text(user['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), subtitle: Text(role == 'siswa' ? 'Kelas: ${user['kelas'] ?? '-'}' : 'Tenaga Pendidik / Guru', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailUserScreen(userData: user)));
              if (result == true) _fetchUsers();
            },
          ),
        );
      },
    );
  }
}

class FolderSiswaDetailScreen extends StatelessWidget {
  final String kelas;
  final List<dynamic> allUsers;
  const FolderSiswaDetailScreen({super.key, required this.kelas, required this.allUsers});

  @override
  Widget build(BuildContext context) {
    final siswaDiKelas = allUsers.where((u) => u['role'] == 'siswa' && u['kelas'] == kelas).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text('Siswa $kelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black), elevation: 0.5),
      body: siswaDiKelas.isEmpty
          ? const Center(child: Text('Belum ada siswa terdaftar di kelas ini.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: siswaDiKelas.length,
              itemBuilder: (context, index) {
                final user = siswaDiKelas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.person, color: Color(0xFF1E40AF))),
                    title: Text(user['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('NISN: ${user['nisn'] ?? '-'}', style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DetailUserScreen(userData: user))).then((result) { if (result == true) Navigator.pop(context, true); });
                    },
                  ),
                );
              },
            ),
    );
  }
}