import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/popup_service.dart';

class DetailUserScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DetailUserScreen({super.key, required this.userData});

  @override
  State<DetailUserScreen> createState() => _DetailUserScreenState();
}

class _DetailUserScreenState extends State<DetailUserScreen> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isEditing = false;
  bool _isSaving = false;
  String _currentUserRole = '';
  
  // Data Akademik Tambahan (Sesuai Revisi Pak Halim)
  bool _isLoadingAkademik = true;
  List<Map<String, dynamic>> _listAbsensiSiswa = [];
  List<Map<String, dynamic>> _listNilaiSiswa = [];
  TabController? _detailTabController;

  late TextEditingController _namaController;
  late TextEditingController _hpController;
  late TextEditingController _alamatController;
  late TextEditingController _nikController;
  late TextEditingController _agamaController;
  late TextEditingController _jkController;
  late TextEditingController _kelasController;
  late TextEditingController _nisnController;
  late TextEditingController _nipdController;

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(length: widget.userData['role'] == 'siswa' ? 2 : 1, vsync: this);
    _fetchCurrentUserRole();
    _fetchDataAkademikSiswa();

    _namaController = TextEditingController(text: widget.userData['full_name'] ?? '');
    _hpController = TextEditingController(text: widget.userData['nomor_hp'] ?? '');
    _alamatController = TextEditingController(text: widget.userData['alamat'] ?? '');
    _nikController = TextEditingController(text: widget.userData['nik'] ?? '');
    _agamaController = TextEditingController(text: widget.userData['agama'] ?? '');
    _jkController = TextEditingController(text: widget.userData['jenis_kelamin'] ?? '');
    _kelasController = TextEditingController(text: widget.userData['kelas'] ?? '');
    _nisnController = TextEditingController(text: widget.userData['nisn'] ?? '');
    _nipdController = TextEditingController(text: widget.userData['nipd'] ?? '');
  }

  Future<void> _fetchCurrentUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase.from('profiles').select('role').eq('id', user.id).single();
        if (mounted) setState(() => _currentUserRole = res['role']?.toString().toLowerCase() ?? '');
      }
    } catch (e) {
      debugPrint('Error fetch current user role: $e');
    }
  }

  // 🔥 REVISI PAK HALIM: Menarik data Absensi & Nilai secara komprehensif untuk siswa
  Future<void> _fetchDataAkademikSiswa() async {
    if (widget.userData['role'] != 'siswa') {
      setState(() => _isLoadingAkademik = false);
      return;
    }

    try {
      final siswaId = widget.userData['id'];
      
      // Tarik Absensi
      final resAbsen = await _supabase
          .from('absensi')
          .select('*')
          .eq('siswa_id', siswaId)
          .order('tanggal', ascending: false);

      // Tarik Nilai
      final resNilai = await _supabase
          .from('nilai')
          .select('*')
          .eq('siswa_id', siswaId)
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _listAbsensiSiswa = List<Map<String, dynamic>>.from(resAbsen);
          _listNilaiSiswa = List<Map<String, dynamic>>.from(resNilai);
          _isLoadingAkademik = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat data akademik siswa: $e');
      if (mounted) setState(() => _isLoadingAkademik = false);
    }
  }

  @override
  void dispose() {
    _detailTabController?.dispose();
    _namaController.dispose(); 
    _hpController.dispose(); 
    _alamatController.dispose(); 
    _nikController.dispose(); 
    _agamaController.dispose(); 
    _jkController.dispose(); 
    _kelasController.dispose(); 
    _nisnController.dispose(); 
    _nipdController.dispose(); 
    super.dispose();
  }

  Future<void> _updateDataUser() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> updatePayload = {
        'full_name': _namaController.text.trim(), 
        'nomor_hp': _hpController.text.trim(), 
        'alamat': _alamatController.text.trim(), 
        'nik': _nikController.text.trim(), 
        'agama': _agamaController.text.trim(), 
        'jenis_kelamin': _jkController.text.trim(),
      };
      if (widget.userData['role'] == 'siswa') {
        updatePayload['kelas'] = _kelasController.text.trim(); 
        updatePayload['nisn'] = _nisnController.text.trim(); 
        updatePayload['nipd'] = _nipdController.text.trim();
      }

      await _supabase.from('profiles').update(updatePayload).eq('id', widget.userData['id']);
      if (!mounted) return;
      
      PopupService.show(context, 'Perubahan data berhasil disimpan!', isSuccess: true, onClose: () => Navigator.pop(context, true));
    } catch (e) {
      if (mounted) {
        PopupService.show(context, 'Gagal memperbarui data: $e', isSuccess: false, judul: 'Terjadi Kesalahan');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _hapusUser() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Hapus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Apakah Anda yakin ingin menghapus data ${widget.userData['full_name']} secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSaving = true);
              try {
                await _supabase.from('profiles').delete().eq('id', widget.userData['id']);
                if (!mounted) return;
                
                PopupService.show(context, 'Pengguna berhasil dihapus permanen.', isSuccess: true, onClose: () => Navigator.pop(context, true));
              } catch (e) {
                if (mounted) {
                  PopupService.show(context, 'Gagal menghapus akun: $e', isSuccess: false, judul: 'Gagal');
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text('Hapus Permanen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.userData['role'] ?? 'siswa';
    bool isSiswa = role == 'siswa';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Data Pengguna' : 'Detail Biodata', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white, 
        elevation: 0.5, 
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20), onPressed: () => Navigator.pop(context, false)),
        actions: [
          if (!_isEditing && (_currentUserRole == 'tata_usaha' || _currentUserRole == 'admin')) 
            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF), size: 28), onPressed: () => setState(() => _isEditing = true)),
          if (_currentUserRole == 'tata_usaha' || _currentUserRole == 'admin') 
            IconButton(icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent), onPressed: _hapusUser),
        ],
        bottom: isSiswa ? TabBar(
          controller: _detailTabController,
          labelColor: const Color(0xFF1E40AF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1E40AF),
          tabs: const [
            Tab(text: 'Biodata & Profil'),
            Tab(text: 'Rekap Absen & Nilai'),
          ],
        ) : null,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
          : isSiswa 
              ? TabBarView(
                  controller: _detailTabController,
                  children: [
                    _buildTabBiodata(role),
                    _buildTabAkademikSiswa(),
                  ],
                )
              : _buildTabBiodata(role),
    );
  }

  Widget _buildTabBiodata(String role) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40, 
                  backgroundColor: role == 'siswa' ? const Color(0xFFDBEAFE) : const Color(0xFFDCEFDC), 
                  child: Icon(role == 'siswa' ? Icons.school : Icons.badge_rounded, size: 40, color: role == 'siswa' ? const Color(0xFF1E40AF) : Colors.green),
                ),
                const SizedBox(height: 12),
                Text(role.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12, color: role == 'siswa' ? const Color(0xFF1E40AF) : Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text("INFORMASI UMUM", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Divider(),
          _buildInputField('Email Akun', null, widget.userData['email'] ?? '-', false),
          _buildInputField('Nama Lengkap', _namaController, widget.userData['full_name'], _isEditing),
          _buildInputField('Jenis Kelamin', _jkController, widget.userData['jenis_kelamin'], _isEditing),
          _buildInputField('Agama', _agamaController, widget.userData['agama'], _isEditing),
          _buildInputField('Nomor NIK', _nikController, widget.userData['nik'], _isEditing),

          const SizedBox(height: 20),
          const Text("KONTAK & DOMISILI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Divider(),
          _buildInputField('Nomor Handphone', _hpController, widget.userData['nomor_hp'], _isEditing),
          _buildInputField('Alamat Rumah', _alamatController, widget.userData['alamat'], _isEditing, maxLines: 2),

          if (role == 'siswa') ...[
            const SizedBox(height: 20),
            const Text("DATA AKADEMIK SISWA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const Divider(),
            _buildInputField('Kelas Aktif', _kelasController, widget.userData['kelas'], _isEditing),
            _buildInputField('Nomor Induk (NIPD)', _nipdController, widget.userData['nipd'], _isEditing),
            _buildInputField('Nomor NISN', _nisnController, widget.userData['nisn'], _isEditing),
          ],

          if (role == 'guru') ...[
            const SizedBox(height: 20),
            const Text("DATA AKADEMIK PENGAJAR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const Divider(),
            _buildInputField('Kelas Mengajar', null, (widget.userData['kelas_mengajar'] as List?)?.join(', ') ?? '-', false),
            _buildInputField('Mata Pelajaran', null, (widget.userData['mapel'] as List?)?.join(', ') ?? '-', false),
          ],

          const SizedBox(height: 20),
          _buildInputField('Status Akun', null, widget.userData['status_aktif'] == true ? 'Aktif' : 'Non-Aktif', false),

          if (_isEditing) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => setState(() => _isEditing = false), child: const Text('Batal'))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _updateDataUser, child: const Text('Simpan Data', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 TAB AKADEMIK: MENAMPILKAN ABSENSI & NILAI LENGKAP SISWA (REVISI PAK HALIM)
  Widget _buildTabAkademikSiswa() {
    if (_isLoadingAkademik) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rekapitulasi Kehadiran Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E40AF))),
          const SizedBox(height: 8),
          _listAbsensiSiswa.isEmpty
              ? const Text('Belum ada data absensi tercatat.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _listAbsensiSiswa.length > 5 ? 5 : _listAbsensiSiswa.length, // Tampilkan 5 terbaru
                  itemBuilder: (context, index) {
                    final abs = _listAbsensiSiswa[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      // 🔥 PERBAIKAN ERROR BUILD FLUTTER: Diganti dari shade350 ke shade300
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      child: ListTile(
                        dense: true,
                        title: Text('Tanggal: ${abs['tanggal']} | Status: ${abs['status']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Mapel: ${abs['mapel'] ?? "-"} | Jam: ${abs['waktu_absen'] ?? "-"}', style: const TextStyle(fontSize: 12)),
                        trailing: Text(abs['status_verifikasi'] ?? 'Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: abs['status_verifikasi'] == 'Disetujui' ? Colors.green : Colors.orange)),
                      ),
                    );
                  },
                ),
          
          const SizedBox(height: 24),
          const Text('Daftar Nilai & Mutu Akademik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E40AF))),
          const SizedBox(height: 8),
          _listNilaiSiswa.isEmpty
              ? const Text('Belum ada data nilai diinputkan.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _listNilaiSiswa.length,
                  itemBuilder: (context, index) {
                    final nil = _listNilaiSiswa[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      // 🔥 PERBAIKAN ERROR BUILD FLUTTER: Diganti dari shade350 ke shade300
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      child: ListTile(
                        dense: true,
                        title: Text('${nil['mata_pelajaran'] ?? nil['mapel'] ?? "-"} (${nil['kategori'] ?? "-"})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Semester: ${nil['semester'] ?? "-"} | Ket: ${nil['keterangan'] ?? "-"}', style: const TextStyle(fontSize: 12)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text('Nilai: ${nil['nilai']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13)),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController? controller, dynamic fallbackValue, bool isEditing, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (isEditing && controller != null) TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E40AF))), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))
          else Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBD5E1))), child: Text(fallbackValue?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14))),
        ],
      ),
    );
  }
}