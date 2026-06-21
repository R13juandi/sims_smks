import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailUserScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DetailUserScreen({super.key, required this.userData});

  @override
  State<DetailUserScreen> createState() => _DetailUserScreenState();
}

class _DetailUserScreenState extends State<DetailUserScreen> {
  final _supabase = Supabase.instance.client;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers untuk SEMUA data
  late TextEditingController _namaController;
  late TextEditingController _hpController;
  late TextEditingController _alamatController;
  late TextEditingController _nikController;
  late TextEditingController _agamaController;
  late TextEditingController _jkController;

  // Khusus Siswa
  late TextEditingController _kelasController;
  late TextEditingController _nisnController;
  late TextEditingController _nipdController;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(
      text: widget.userData['full_name'] ?? '',
    );
    _hpController = TextEditingController(
      text: widget.userData['nomor_hp'] ?? '',
    );
    _alamatController = TextEditingController(
      text: widget.userData['alamat'] ?? '',
    );
    _nikController = TextEditingController(text: widget.userData['nik'] ?? '');
    _agamaController = TextEditingController(
      text: widget.userData['agama'] ?? '',
    );
    _jkController = TextEditingController(
      text: widget.userData['jenis_kelamin'] ?? '',
    );

    _kelasController = TextEditingController(
      text: widget.userData['kelas'] ?? '',
    );
    _nisnController = TextEditingController(
      text: widget.userData['nisn'] ?? '',
    );
    _nipdController = TextEditingController(
      text: widget.userData['nipd'] ?? '',
    );
  }

  @override
  void dispose() {
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

      await _supabase
          .from('profiles')
          .update(updatePayload)
          .eq('id', widget.userData['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perubahan data berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _hapusUser() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Konfirmasi Hapus',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data ${widget.userData['full_name']} secara permanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi == true) {
      setState(() => _isSaving = true);
      try {
        await _supabase
            .from('profiles')
            .delete()
            .eq('id', widget.userData['id']);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus akun: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.userData['role'] ?? 'siswa';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Data Pengguna' : 'Detail Biodata',
          style: const TextStyle(
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
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF1E40AF),
                size: 28,
              ),
              onPressed: () => setState(() => _isEditing = true),
            ),
          IconButton(
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
            ),
            onPressed: _hapusUser,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER ICON
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: role == 'siswa'
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFDCEFDC),
                          child: Icon(
                            role == 'siswa'
                                ? Icons.school
                                : Icons.badge_rounded,
                            size: 40,
                            color: role == 'siswa'
                                ? const Color(0xFF1E40AF)
                                : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 12,
                            color: role == 'siswa'
                                ? const Color(0xFF1E40AF)
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // BIODATA UMUM
                  const Text(
                    "INFORMASI UMUM",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const Divider(),
                  _buildInputField(
                    'Email Akun',
                    null,
                    widget.userData['email'] ?? '-',
                    false,
                  ), // Email tidak bisa diedit via profile table
                  _buildInputField(
                    'Nama Lengkap',
                    _namaController,
                    widget.userData['full_name'],
                    _isEditing,
                  ),
                  _buildInputField(
                    'Jenis Kelamin',
                    _jkController,
                    widget.userData['jenis_kelamin'],
                    _isEditing,
                  ),
                  _buildInputField(
                    'Agama',
                    _agamaController,
                    widget.userData['agama'],
                    _isEditing,
                  ),
                  _buildInputField(
                    'Nomor NIK',
                    _nikController,
                    widget.userData['nik'],
                    _isEditing,
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "KONTAK & DOMISILI",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const Divider(),
                  _buildInputField(
                    'Nomor Handphone',
                    _hpController,
                    widget.userData['nomor_hp'],
                    _isEditing,
                  ),
                  _buildInputField(
                    'Alamat Rumah',
                    _alamatController,
                    widget.userData['alamat'],
                    _isEditing,
                    maxLines: 2,
                  ),

                  // BIODATA AKADEMIK (SISWA)
                  if (role == 'siswa') ...[
                    const SizedBox(height: 20),
                    const Text(
                      "DATA AKADEMIK SISWA",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const Divider(),
                    _buildInputField(
                      'Kelas Aktif',
                      _kelasController,
                      widget.userData['kelas'],
                      _isEditing,
                    ),
                    _buildInputField(
                      'Nomor Induk (NIPD)',
                      _nipdController,
                      widget.userData['nipd'],
                      _isEditing,
                    ),
                    _buildInputField(
                      'Nomor NISN',
                      _nisnController,
                      widget.userData['nisn'],
                      _isEditing,
                    ),
                  ],

                  // BIODATA AKADEMIK (GURU)
                  if (role == 'guru') ...[
                    const SizedBox(height: 20),
                    const Text(
                      "DATA AKADEMIK PENGAJAR",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const Divider(),
                    _buildInputField(
                      'Kelas Mengajar',
                      null,
                      (widget.userData['kelas_mengajar'] as List?)?.join(
                            ', ',
                          ) ??
                          '-',
                      false,
                    ),
                    _buildInputField(
                      'Mata Pelajaran',
                      null,
                      (widget.userData['mapel'] as List?)?.join(', ') ?? '-',
                      false,
                    ),
                  ],

                  // STATUS AKTIF
                  const SizedBox(height: 20),
                  _buildInputField(
                    'Status Akun',
                    null,
                    widget.userData['status_aktif'] == true
                        ? 'Aktif'
                        : 'Non-Aktif',
                    false,
                  ),

                  // TOMBOL SIMPAN
                  if (_isEditing) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => setState(() => _isEditing = false),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _updateDataUser,
                            child: const Text(
                              'Simpan Data',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // Widget gabungan untuk View dan Edit
  Widget _buildInputField(
    String label,
    TextEditingController? controller,
    dynamic fallbackValue,
    bool isEditing, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (isEditing && controller != null)
            TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E40AF)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                fallbackValue?.toString() ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
