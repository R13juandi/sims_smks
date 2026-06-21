import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TambahUserScreen extends StatefulWidget {
  const TambahUserScreen({super.key});

  @override
  State<TambahUserScreen> createState() => _TambahUserScreenState();
}

class _TambahUserScreenState extends State<TambahUserScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  // Controller Akun Dasar
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controller Biodata Lengkap
  final _namaController = TextEditingController();
  final _tempatLahirController = TextEditingController();
  final _alamatController = TextEditingController();
  final _nikController = TextEditingController();
  final _nipdController = TextEditingController();
  final _nisnController = TextEditingController();
  final _hpController = TextEditingController();

  // State Dropdown & Picker
  String _selectedRole = 'siswa';
  String _selectedAgama = 'Islam';
  String _selectedJK = 'Laki-laki';
  String? _selectedKelasSiswa;
  DateTime? _selectedTanggalLahir;

  // PILIHAN GANDA (MULTI-SELECT) UNTUK GURU
  List<String> _selectedMapelGuru = [];
  List<String> _selectedKelasGuru = [];

  // PERBAIKAN: Hanya TKJ & Hilangkan tanda titik di sebelah Romawi
  final List<String> _daftarKelas = ['X TKJ', 'XI TKJ', 'XII TKJ'];
  final List<String> _daftarAgama = [
    'Islam',
    'Kristen',
    'Katolik',
    'Hindu',
    'Buddha',
    'Khonghucu',
  ];
  final List<String> _daftarJK = ['Laki-laki', 'Perempuan'];
  List<String> _daftarMapelDinamis = [];

  @override
  void initState() {
    super.initState();
    _fetchMataPelajaran();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _namaController.dispose();
    _tempatLahirController.dispose();
    _alamatController.dispose();
    _nikController.dispose();
    _nipdController.dispose();
    _nisnController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  Future<void> _fetchMataPelajaran() async {
    try {
      final res = await _supabase
          .from('mata_pelajaran')
          .select('nama_mapel')
          .order('nama_mapel', ascending: true);

      // JIKA TABEL DI DATABASE KOSONG, GUNAKAN DAFTAR DEFAULT
      if (res.isEmpty) {
        _gunakanMapelDefault();
      } else {
        setState(() {
          _daftarMapelDinamis = List<String>.from(
            res.map((m) => m['nama_mapel']),
          );
        });
      }
    } catch (e) {
      // JIKA KONEKSI ERROR, GUNAKAN DAFTAR DEFAULT
      _gunakanMapelDefault();
    }
  }

  // FUNGSI BARU: Daftar Mapel Default (Sudah dirapikan khusus TKJ)
  void _gunakanMapelDefault() {
    setState(() {
      _daftarMapelDinamis = [
        'PAI dan Budi Pekerti',
        'PPKN',
        'Bahasa Indonesia',
        'Matematika',
        'Bahasa Inggris',
        'Sejarah',
        'PJOK',
        'Seni Budaya',
        'Project IPAS',
        'Informatika',
        'Kejuruan TKJ',
        'KKA (Koding dan Kecerdasan AI)',
        'Produk Kreatif dan Kewirausahaan',
        'Muatan Lokal',
      ];
    });
  }

  // Pop-up Centang Banyak Mapel
  void _showMultiSelectMapel() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              title: const Text(
                'Pilih Mata Pelajaran (Bisa > 1)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _daftarMapelDinamis.length,
                  itemBuilder: (context, index) {
                    final item = _daftarMapelDinamis[index];
                    return CheckboxListTile(
                      title: Text(item, style: const TextStyle(fontSize: 13)),
                      value: _selectedMapelGuru.contains(item),
                      onChanged: (bool? checked) {
                        setPopupState(() {
                          if (checked == true) {
                            _selectedMapelGuru.add(item);
                          } else {
                            _selectedMapelGuru.remove(item);
                          }
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Selesai'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Pop-up Centang Banyak Kelas
  void _showMultiSelectKelas() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              title: const Text(
                'Pilih Kelas Mengajar (Bisa > 1)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _daftarKelas.length,
                  itemBuilder: (context, index) {
                    final kelas = _daftarKelas[index];
                    return CheckboxListTile(
                      title: Text(kelas, style: const TextStyle(fontSize: 13)),
                      value: _selectedKelasGuru.contains(kelas),
                      onChanged: (bool? checked) {
                        setPopupState(() {
                          if (checked == true) {
                            _selectedKelasGuru.add(kelas);
                          } else {
                            _selectedKelasGuru.remove(kelas);
                          }
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Selesai'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _prosesRegistrasiUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'siswa' && _selectedKelasSiswa == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih kelas siswa!')),
      );
      return;
    }

    if (_selectedRole == 'guru' &&
        (_selectedMapelGuru.isEmpty || _selectedKelasGuru.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guru wajib memiliki minimal 1 mapel & 1 kelas!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse authRes = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String? newUserId = authRes.user?.id;

      if (newUserId != null) {
        // 🔥 PERBAIKAN: KEMBALIKAN KE full_name
        Map<String, dynamic> profileData = {
          'id': newUserId,
          'full_name': _namaController.text.trim(),
          'role': _selectedRole,
          'email': _emailController.text.trim(),
          'status_aktif': true,
          'nomor_hp': _hpController.text.trim(),
          'alamat': _alamatController.text.trim(),
          'agama': _selectedAgama,
          'jenis_kelamin': _selectedJK,
        };

        // KONDISI JIKA GURU
        if (_selectedRole == 'guru') {
          profileData['mapel'] = _selectedMapelGuru;
          profileData['kelas_mengajar'] = _selectedKelasGuru;
          // PASTIKAN NIK GURU DISIMPAN
          profileData['nik'] = _nikController.text.trim();
        }

        // KONDISI JIKA SISWA
        if (_selectedRole == 'siswa') {
          profileData.addAll({
            'kelas': _selectedKelasSiswa,
            'tempat_lahir': _tempatLahirController.text.trim(),
            'tanggal_lahir': _selectedTanggalLahir != null
                ? DateFormat('yyyy-MM-dd').format(_selectedTanggalLahir!)
                : null,
            'nik': _nikController.text.trim(),
            'nipd': _nipdController.text.trim(),
            'nisn': _nisnController.text.trim(),
          });
        }

        await _supabase.from('profiles').insert(profileData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Akun ${_selectedRole.toUpperCase()} sukses diterbitkan!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Registrasi Pengguna Baru',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PILIH PERAN AKUN / ROLE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'siswa',
                          child: Text('Siswa (Peserta Didik)'),
                        ),
                        DropdownMenuItem(
                          value: 'guru',
                          child: Text('Guru (Tenaga Pendidik)'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                    const SizedBox(height: 20),

                    // KREDENSIAL LOGIN
                    _buildTextField(
                      'Alamat Email Resmi',
                      _emailController,
                      TextInputType.emailAddress,
                      Icons.email_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Kata Sandi Akun',
                      _passwordController,
                      TextInputType.text,
                      Icons.lock_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 24),

                    // BIODATA UTAMA
                    _buildTextField(
                      'Nama Lengkap',
                      _namaController,
                      TextInputType.name,
                      Icons.person_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      'Jenis Kelamin',
                      _selectedJK,
                      _daftarJK,
                      (val) => setState(() => _selectedJK = val!),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      'Agama',
                      _selectedAgama,
                      _daftarAgama,
                      (val) => setState(() => _selectedAgama = val!),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Nomor Handphone Aktif',
                      _hpController,
                      TextInputType.phone,
                      Icons.phone_android_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'Alamat Domisili',
                      _alamatController,
                      TextInputType.text,
                      Icons.home_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // NIK SEKARANG BISA DIISI OLEH GURU DAN SISWA
                    _buildTextField(
                      'NIK (Nomor Induk Kependudukan)',
                      _nikController,
                      TextInputType.number,
                      Icons.credit_card_rounded,
                    ),

                    // PANEL TUGAS GURU MULTI-SELECT
                    if (_selectedRole == 'guru') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'PENGATURAN TUGAS MENGAJAR MULTI-MAPEL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 10),

                      InkWell(
                        onTap: _showMultiSelectMapel,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedMapelGuru.isEmpty
                                      ? 'Pilih Mata Pelajaran (Klik Di Sini)'
                                      : 'Mapel Terpilih: ${_selectedMapelGuru.join(", ")}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.book_rounded,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      InkWell(
                        onTap: _showMultiSelectKelas,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedKelasGuru.isEmpty
                                      ? 'Pilih Kelas Mengajar (Klik Di Sini)'
                                      : 'Kelas Terpilih: ${_selectedKelasGuru.join(", ")}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.school_rounded,
                                color: Colors.indigo,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // SISWA ONLY
                    if (_selectedRole == 'siswa') ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Tempat Lahir',
                        _tempatLahirController,
                        TextInputType.text,
                        Icons.location_city_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'NIPD',
                        _nipdController,
                        TextInputType.number,
                        Icons.badge_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'NISN',
                        _nisnController,
                        TextInputType.number,
                        Icons.fingerprint_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        'Kelas Aktif',
                        _selectedKelasSiswa ?? 'X TKJ',
                        _daftarKelas,
                        (val) => setState(() => _selectedKelasSiswa = val),
                      ),
                    ],

                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _prosesRegistrasiUser,
                      child: const Text(
                        'DAFTARKAN PENGGUNA BARU',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    TextInputType type,
    IconData icon, {
    bool isPassword = false,
    int maxLines = 1,
  }) {
    return Column(
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
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: type,
          obscureText: isPassword,
          maxLines: maxLines,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          validator: (val) =>
              val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final String verifiedValue = items.contains(value) ? value : items.first;
    return Column(
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
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: verifiedValue,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
