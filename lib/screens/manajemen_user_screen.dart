import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'tambah_user_screen.dart';

class ManajemenUserScreen extends StatefulWidget {
  const ManajemenUserScreen({super.key});

  @override
  State<ManajemenUserScreen> createState() => _ManajemenUserScreenState();
}

class _ManajemenUserScreenState extends State<ManajemenUserScreen> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';

  TabController? _tabController;
  bool _isKepsek = false; // 🔥 Variabel Detektif Role

  @override
  void initState() {
    super.initState();
    _fetchUsersAndRole();
  }

  Future<void> _fetchUsersAndRole() async {
    setState(() => _isLoading = true);
    try {
      // 1. Cek Role Akun yang sedang Login
      final currentUser = _supabase.auth.currentUser;
      final myProfile = await _supabase.from('profiles').select('role').eq('id', currentUser!.id).single();
      
      bool isKepsekLogin = myProfile['role'] == 'kepsek';

      // 2. Ambil semua data user
      final res = await _supabase.from('profiles').select('*').order('full_name', ascending: true);
      
      if (mounted) {
        setState(() {
          _isKepsek = isKepsekLogin;
          // 🔥 Jika Kepsek, Tab hanya 2. Jika Admin/TU, Tab ada 3.
          _tabController = TabController(length: _isKepsek ? 2 : 3, vsync: this);
          _users = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar('Gagal memuat data: $e', Colors.red);
    }
  }

  void _showSnackBar(String pesan, Color warna) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna, behavior: SnackBarBehavior.floating));
  }

  // ==========================================================
  // 🔥 TAMPILAN DETAIL DATA PENGGUNA (HANYA BACA / READ-ONLY)
  // ==========================================================
  void _bukaDialogDetail(Map<String, dynamic> user) {
    bool isSiswa = user['role'] == 'siswa';
    
    String tglLahir = user['tanggal_lahir'] ?? '-';
    if (tglLahir != '-') {
      try { tglLahir = DateFormat('dd MMMM yyyy').format(DateTime.parse(tglLahir)); } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(backgroundColor: Colors.blue.shade100, child: Icon(isSiswa ? Icons.school : Icons.badge, color: Colors.blue.shade900)),
              const SizedBox(width: 12),
              Expanded(child: Text('Detail Pengguna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Nama Lengkap', user['full_name']),
                _buildInfoRow('Email Akun', user['email']),
                _buildInfoRow('Role / Jabatan', user['role'].toString().toUpperCase()),
                const Divider(height: 24),
                
                if (isSiswa) ...[
                  _buildInfoRow('Kelas Aktif', user['kelas']),
                  _buildInfoRow('NISN', user['nisn']),
                  _buildInfoRow('NIPD', user['nipd']),
                ] else ...[
                  _buildInfoRow('NIP', user['nip']),
                  _buildInfoRow('Mata Pelajaran', (user['mapel'] as List<dynamic>?)?.join(', ') ?? user['mata_pelajaran']),
                  _buildInfoRow('Kelas Mengajar', (user['kelas_mengajar'] as List<dynamic>?)?.join(', ')),
                ],
                
                const Divider(height: 24),
                _buildInfoRow('Jenis Kelamin', user['jenis_kelamin']),
                _buildInfoRow('Tempat, Tgl Lahir', '${user['tempat_lahir'] ?? '-'}, $tglLahir'),
                _buildInfoRow('Agama', user['agama']),
                _buildInfoRow('Nomor HP', user['nomor_hp']),
                _buildInfoRow('NIK', user['nik']),
                _buildInfoRow('Alamat Domisili', user['alamat']),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value != null && value.isNotEmpty ? value : '-', style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ==========================================================
  // 🔥 DIALOG EDIT PENUH (HANYA MUNCUL UNTUK ADMIN & TU)
  // ==========================================================
  void _bukaDialogEdit(Map<String, dynamic> user) {
    bool isSiswa = user['role'] == 'siswa';

    final nameCtrl = TextEditingController(text: user['full_name']);
    final hpCtrl = TextEditingController(text: user['nomor_hp']);
    final alamatCtrl = TextEditingController(text: user['alamat']);
    final nikCtrl = TextEditingController(text: user['nik']);
    final tempatLahirCtrl = TextEditingController(text: user['tempat_lahir']);
    final tglLahirCtrl = TextEditingController(text: user['tanggal_lahir']);
    final passwordCtrl = TextEditingController();

    final nisnCtrl = TextEditingController(text: user['nisn']);
    final nipdCtrl = TextEditingController(text: user['nipd']);
    final nipCtrl = TextEditingController(text: user['nip']);
    
    String mapelStr = (user['mapel'] as List<dynamic>?)?.join(', ') ?? '';
    String kelasMengajarStr = (user['kelas_mengajar'] as List<dynamic>?)?.join(', ') ?? '';
    final mapelCtrl = TextEditingController(text: mapelStr);
    final kelasMengajarCtrl = TextEditingController(text: kelasMengajarStr);

    String selectedRole = user['role'] ?? 'siswa';
    String? selectedJK = user['jenis_kelamin'];
    String? selectedAgama = user['agama'];
    String? selectedKelasSiswa = user['kelas'];

    final List<String> listRole = ['siswa', 'guru', 'tata_usaha', 'admin', 'kepsek'];
    final List<String> listAgama = ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'];
    final List<String> listJK = ['Laki-laki', 'Perempuan'];
    final List<String> listKelasTersedia = ['X TKJ', 'XI TKJ', 'XII TKJ']; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Edit Data: ${user['full_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection('Keamanan Akun'),
                      TextField(
                        controller: passwordCtrl, obscureText: true,
                        decoration: const InputDecoration(labelText: 'Reset Password (Kosongkan jika tidak diganti)', border: OutlineInputBorder(), hintText: 'Masukkan sandi baru...'),
                      ),
                      const SizedBox(height: 16),

                      _buildHeaderSection('Data Pribadi'),
                      _buildTextField('Nama Lengkap', nameCtrl),
                      _buildTextField('NIK', nikCtrl, isNumber: true),
                      _buildTextField('Nomor HP', hpCtrl, isNumber: true),
                      _buildTextField('Tempat Lahir', tempatLahirCtrl),
                      _buildTextField('Tanggal Lahir (YYYY-MM-DD)', tglLahirCtrl),
                      _buildTextField('Alamat Domisili', alamatCtrl, maxLines: 2),

                      DropdownButtonFormField<String>(
                        value: listJK.contains(selectedJK) ? selectedJK : null, decoration: const InputDecoration(labelText: 'Jenis Kelamin', border: OutlineInputBorder()),
                        items: listJK.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setStateDialog(() => selectedJK = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: listAgama.contains(selectedAgama) ? selectedAgama : null, decoration: const InputDecoration(labelText: 'Agama', border: OutlineInputBorder()),
                        items: listAgama.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setStateDialog(() => selectedAgama = v),
                      ),
                      const SizedBox(height: 16),

                      _buildHeaderSection('Data Akademik & Hak Akses'),
                      DropdownButtonFormField<String>(
                        value: listRole.contains(selectedRole) ? selectedRole : null, decoration: const InputDecoration(labelText: 'Role / Jabatan', border: OutlineInputBorder()),
                        items: listRole.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                        onChanged: isSiswa ? null : (v) => setStateDialog(() => selectedRole = v!),
                      ),
                      if (isSiswa) const Padding(padding: EdgeInsets.only(top: 4, bottom: 12), child: Text('*Akun Siswa tidak dapat diubah rolenya', style: TextStyle(color: Colors.red, fontSize: 11))),
                      const SizedBox(height: 12),

                      if (selectedRole == 'siswa') ...[
                        _buildTextField('NISN', nisnCtrl, isNumber: true),
                        _buildTextField('NIPD', nipdCtrl, isNumber: true),
                        DropdownButtonFormField<String>(
                          value: listKelasTersedia.contains(selectedKelasSiswa) ? selectedKelasSiswa : null, decoration: const InputDecoration(labelText: 'Kelas Aktif', border: OutlineInputBorder()),
                          items: listKelasTersedia.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setStateDialog(() => selectedKelasSiswa = v),
                        ),
                        const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('*Ubah kelas ini untuk menaikkan/menurunkan kelas siswa.', style: TextStyle(color: Colors.green, fontSize: 11, fontStyle: FontStyle.italic))),
                      ],

                      if (selectedRole != 'siswa') ...[
                        _buildTextField('NIP (Opsional)', nipCtrl, isNumber: true),
                        _buildTextField('Mata Pelajaran', mapelCtrl, hint: 'Cth: Matematika, B. Inggris (Pisahkan dgn koma)'),
                        _buildTextField('Kelas Mengajar', kelasMengajarCtrl, hint: 'Cth: X TKJ, XI TKJ (Pisahkan dgn koma)'),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                  onPressed: () async {
                    Navigator.pop(context);
                    _prosesUpdateUser(
                      userId: user['id'], roleAsliSiswa: isSiswa, name: nameCtrl.text, hp: hpCtrl.text, alamat: alamatCtrl.text, nik: nikCtrl.text,
                      tmptLahir: tempatLahirCtrl.text, tglLahir: tglLahirCtrl.text, jk: selectedJK, agama: selectedAgama, roleBaru: selectedRole,
                      nisn: nisnCtrl.text, nipd: nipdCtrl.text, kelasSiswa: selectedKelasSiswa, nip: nipCtrl.text, mapelStr: mapelCtrl.text, kelasMngjrStr: kelasMengajarCtrl.text, passwordBaru: passwordCtrl.text
                    );
                  },
                  child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false, int maxLines = 1, String hint = ''}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, keyboardType: isNumber ? TextInputType.number : TextInputType.text, maxLines: maxLines, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder())));
  }

  Widget _buildHeaderSection(String title) {
    return Padding(padding: const EdgeInsets.only(top: 8, bottom: 12), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)));
  }

  Future<void> _prosesUpdateUser({
    required String userId, required bool roleAsliSiswa, required String name, required String hp,
    required String alamat, required String nik, required String tmptLahir, required String tglLahir,
    String? jk, String? agama, required String roleBaru, required String nisn, required String nipd, String? kelasSiswa,
    required String nip, required String mapelStr, required String kelasMngjrStr, required String passwordBaru
  }) async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> updates = {
        'full_name': name, 'nomor_hp': hp, 'alamat': alamat, 'nik': nik, 'tempat_lahir': tmptLahir, 'tanggal_lahir': tglLahir.isEmpty ? null : tglLahir, 'jenis_kelamin': jk, 'agama': agama,
      };

      if (roleAsliSiswa) {
        updates['nisn'] = nisn; updates['nipd'] = nipd; updates['kelas'] = kelasSiswa;
      } else {
        updates['role'] = roleBaru; updates['nip'] = nip;
        updates['mapel'] = mapelStr.isEmpty ? [] : mapelStr.split(',').map((e) => e.trim()).toList();
        updates['kelas_mengajar'] = kelasMngjrStr.isEmpty ? [] : kelasMngjrStr.split(',').map((e) => e.trim()).toList();
      }

      await _supabase.from('profiles').update(updates).eq('id', userId);

      if (passwordBaru.isNotEmpty) {
        try {
          await _supabase.rpc('admin_update_password', params: {'uid': userId, 'new_pass': passwordBaru});
          _showSnackBar('Biodata & Password berhasil diperbarui!', Colors.green);
        } catch (e) {
          _showSnackBar('Biodata diperbarui, TAPI gagal ubah password (RPC Error).', Colors.orange);
        }
      } else {
        _showSnackBar('Biodata berhasil diperbarui!', Colors.green);
      }
      _fetchUsersAndRole(); // Refresh Data
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Gagal memperbarui: $e', Colors.red);
    }
  }

  void _konfirmasiHapus(String id, String nama) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengguna?'), content: Text('Anda yakin ingin menghapus data $nama? Aksi ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _supabase.from('profiles').delete().eq('id', id);
                _fetchUsersAndRole(); // Refresh Data
                _showSnackBar('Pengguna berhasil dihapus', Colors.green);
              } catch (e) {
                setState(() => _isLoading = false);
                _showSnackBar('Gagal menghapus pengguna.', Colors.red);
              }
            },
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredList = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final nama = (u['full_name'] ?? '').toString().toLowerCase();
      final r = (u['role'] ?? '').toString().toLowerCase();
      final nisn = (u['nisn'] ?? '').toString().toLowerCase();
      return nama.contains(_searchQuery) || r.contains(_searchQuery) || nisn.contains(_searchQuery);
    }).toList();

    final listSiswa = filteredList.where((u) => u['role'] == 'siswa').toList();
    final listGuru = filteredList.where((u) => u['role'] == 'guru' || u['role'] == 'kepsek').toList();
    final listStaff = filteredList.where((u) => u['role'] == 'tata_usaha' || u['role'] == 'admin').toList();

    // Pastikan TabController sudah dirender setelah Fetch Data
    if (_tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manajemen Pengguna', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5, iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController, labelColor: Colors.blue.shade900, unselectedLabelColor: Colors.grey, indicatorColor: Colors.blue.shade900,
          tabs: [
            const Tab(text: 'Siswa'), 
            const Tab(text: 'Pendidik'), 
            if (!_isKepsek) const Tab(text: 'Staff & Admin') // 🔥 Sembunyikan untuk Kepsek
          ],
        ),
      ),
      // 🔥 Sembunyikan Floating Action Button untuk Kepsek
      floatingActionButton: _isKepsek ? null : FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade900, icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TambahUserScreen())).then((_) => _fetchUsersAndRole());
        },
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari Nama, NISN, atau NIK...', prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSiswaList(listSiswa), 
                    _buildPegawaiList(listGuru),
                    if (!_isKepsek) _buildPegawaiList(listStaff), // 🔥 Sembunyikan untuk Kepsek
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiswaList(List<Map<String, dynamic>> siswaData) {
    if (siswaData.isEmpty) return const Center(child: Text('Data siswa tidak ditemukan.', style: TextStyle(color: Colors.grey)));

    Map<String, List<Map<String, dynamic>>> groupedSiswa = {};
    for (var s in siswaData) {
      final k = s['kelas'] ?? 'Tanpa Kelas';
      if (!groupedSiswa.containsKey(k)) groupedSiswa[k] = [];
      groupedSiswa[k]!.add(s);
    }
    final sortedKelas = groupedSiswa.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKelas.length,
      itemBuilder: (context, index) {
        String kelas = sortedKelas[index];
        List<Map<String, dynamic>> listSiswaKelas = groupedSiswa[kelas]!;

        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: ExpansionTile(
            leading: const Icon(Icons.folder_shared_rounded, color: Colors.amber, size: 36),
            title: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
            subtitle: Text('${listSiswaKelas.length} Siswa terdaftar', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            children: listSiswaKelas.map((siswa) {
              return Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: const CircleAvatar(backgroundColor: Color(0xFFE6FFFA), child: Icon(Icons.school, color: Colors.teal)),
                  title: Text(siswa['full_name'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('NISN: ${siswa['nisn'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                  onTap: () => _bukaDialogDetail(siswa), 
                  // 🔥 Sembunyikan ikon Edit & Hapus untuk Kepsek
                  trailing: _isKepsek ? const Icon(Icons.chevron_right, color: Colors.grey) : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _bukaDialogEdit(siswa)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _konfirmasiHapus(siswa['id'], siswa['full_name'])),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPegawaiList(List<Map<String, dynamic>> usersData) {
    if (usersData.isEmpty) return const Center(child: Text('Data tidak ditemukan.', style: TextStyle(color: Colors.grey)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: usersData.length,
      itemBuilder: (context, index) {
        final user = usersData[index];
        final role = (user['role'] ?? 'Siswa').toString().toUpperCase();
        
        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(Icons.badge, color: Colors.blue.shade900)),
            title: Text(user['full_name'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Role: $role', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600, fontSize: 12)),
                Text('Email: ${user['email'] ?? '-'}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            onTap: () => _bukaDialogDetail(user),
            // 🔥 Sembunyikan ikon Edit & Hapus untuk Kepsek
            trailing: _isKepsek ? const Icon(Icons.chevron_right, color: Colors.grey) : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _bukaDialogEdit(user)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _konfirmasiHapus(user['id'], user['full_name'])),
              ],
            ),
          ),
        );
      },
    );
  }
}