import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManajemenJadwalScreen extends StatefulWidget {
  const ManajemenJadwalScreen({super.key});

  @override
  State<ManajemenJadwalScreen> createState() => _ManajemenJadwalScreenState();
}

class _ManajemenJadwalScreenState extends State<ManajemenJadwalScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _jadwalList = [];
  List<String> _guruList = [];
  bool _isLoading = true;

  final List<String> _kelasList = ['X TKJ', 'XI TKJ', 'XII TKJ'];
  final List<String> _hariList = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  // ==========================================================
  // KONFIGURASI MATA PELAJARAN SPESIFIK PER GURU
  // Admin bisa menambahkan Guru baru & Mapelnya di sini
  // ==========================================================
  final Map<String, List<String>> _guruMapelConfig = {
    'Djuwandi': [
      'Bahasa Indonesia',
      'Matematika',
      'KKA (Koding dan Kecerdasan AI)',
    ],
    'Iqbal': ['Kejuruan TKJ', 'Informatika', 'Project IPAS'],
    'Ahmad': ['PAI dan Budi Pekerti', 'PPKN', 'Sejarah'],
    'Rosita': ['Bahasa Inggris', 'Produk Kreatif dan Kewirausahaan'],
    // NAMA GURU BARU (Contoh)
    'Muhammad Rizqi': [
      'Matematika',
      'Informatika',
      'Kejuruan TKJ',
      'Project IPAS',
    ],
  };

  // Mapel Default jika Guru belum diatur di atas
  final List<String> _defaultMapelList = [
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

  @override
  void initState() {
    super.initState();
    _fetchGurus();
    _fetchJadwal();
  }

  // 🔥 PERBAIKAN: Menggunakan 'full_name' sesuai dengan database Supabase Anda
  Future<void> _fetchGurus() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('full_name, role');

      List<String> daftarGuru = [];
      for (var user in response) {
        if (user['role'] != null &&
            user['role'].toString().toLowerCase() == 'guru') {
          if (user['full_name'] != null) {
            daftarGuru.add(user['full_name'].toString());
          }
        }
      }

      daftarGuru.sort((a, b) => a.compareTo(b));

      if (mounted) {
        setState(() {
          _guruList = daftarGuru;
        });
      }
    } catch (e) {
      print('Error fetch guru: $e');
      _showSnackBar('Gagal memuat daftar guru', Colors.red);
    }
  }

  Future<void> _fetchJadwal() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('jadwal')
          .select()
          .order('jam_mulai', ascending: true);
      if (mounted) setState(() => _jadwalList = data);
    } catch (e) {
      _showSnackBar('Gagal memuat jadwal: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String timeDb) {
    if (timeDb.length >= 5) return timeDb.substring(0, 5);
    return timeDb;
  }

  void _showFormDialog({Map<String, dynamic>? jadwal}) {
    final isEdit = jadwal != null;

    String? selectedHari = isEdit ? jadwal['hari'] : null;
    String? selectedKelas = isEdit ? jadwal['kelas'] : null;
    String? selectedGuru = isEdit ? jadwal['guru_pengampu'] : null;
    String? selectedMapel = isEdit ? jadwal['mata_pelajaran'] : null;

    List<String> currentMapelList = [];
    if (selectedGuru != null) {
      currentMapelList = _guruMapelConfig[selectedGuru] ?? _defaultMapelList;
    }

    if (isEdit) {
      if (selectedKelas != null && !_kelasList.contains(selectedKelas))
        _kelasList.add(selectedKelas!);
      if (selectedGuru != null && !_guruList.contains(selectedGuru))
        _guruList.add(selectedGuru!);
      if (selectedMapel != null && !currentMapelList.contains(selectedMapel))
        currentMapelList.add(selectedMapel!);
    }

    TimeOfDay? jamMulai = isEdit && jadwal['jam_mulai'] != null
        ? TimeOfDay(
            hour: int.parse(jadwal['jam_mulai'].split(':')[0]),
            minute: int.parse(jadwal['jam_mulai'].split(':')[1]),
          )
        : null;

    TimeOfDay? jamSelesai = isEdit && jadwal['jam_selesai'] != null
        ? TimeOfDay(
            hour: int.parse(jadwal['jam_selesai'].split(':')[0]),
            minute: int.parse(jadwal['jam_selesai'].split(':')[1]),
          )
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                isEdit ? 'Edit Jadwal' : 'Tambah Jadwal',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedHari,
                      hint: const Text('Pilih Hari'),
                      items: _hariList
                          .map(
                            (h) => DropdownMenuItem(value: h, child: Text(h)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedHari = val),
                      decoration: const InputDecoration(
                        labelText: 'Hari',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedGuru,
                      hint: Text(
                        _guruList.isEmpty
                            ? 'Tidak ada data guru'
                            : 'Pilih Guru Pengampu',
                      ),
                      items: _guruList
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedGuru = val;
                          selectedMapel = null;
                          if (val != null &&
                              _guruMapelConfig.containsKey(val)) {
                            currentMapelList = List.from(
                              _guruMapelConfig[val]!,
                            );
                          } else {
                            currentMapelList = List.from(_defaultMapelList);
                          }
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Guru Pengampu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedKelas,
                      hint: const Text('Pilih Kelas Target'),
                      items: _kelasList
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedKelas = val),
                      decoration: const InputDecoration(
                        labelText: 'Kelas Target',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedMapel,
                      hint: Text(
                        selectedGuru == null
                            ? 'Pilih Guru Terlebih Dahulu'
                            : 'Pilih Mata Pelajaran',
                      ),
                      items: selectedGuru == null
                          ? null
                          : currentMapelList
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                      onChanged: selectedGuru == null
                          ? null
                          : (val) => setDialogState(() => selectedMapel = val),
                      decoration: InputDecoration(
                        labelText: 'Mata Pelajaran',
                        border: const OutlineInputBorder(),
                        filled: selectedGuru == null,
                        fillColor: selectedGuru == null
                            ? Colors.grey.shade200
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade900,
                            ),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime:
                                    jamMulai ??
                                    const TimeOfDay(hour: 7, minute: 0),
                              );
                              if (time != null)
                                setDialogState(() => jamMulai = time);
                            },
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              jamMulai == null
                                  ? 'Jam Mulai'
                                  : '${jamMulai!.hour.toString().padLeft(2, '0')}:${jamMulai!.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              foregroundColor: Colors.orange.shade900,
                            ),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime:
                                    jamSelesai ??
                                    const TimeOfDay(hour: 8, minute: 30),
                              );
                              if (time != null)
                                setDialogState(() => jamSelesai = time);
                            },
                            icon: const Icon(Icons.access_time_filled),
                            label: Text(
                              jamSelesai == null
                                  ? 'Jam Selesai'
                                  : '${jamSelesai!.hour.toString().padLeft(2, '0')}:${jamSelesai!.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                  ),
                  onPressed: () async {
                    if (selectedHari == null ||
                        selectedKelas == null ||
                        selectedGuru == null ||
                        selectedMapel == null ||
                        jamMulai == null ||
                        jamSelesai == null) {
                      _showSnackBar(
                        'Harap lengkapi semua Pilihan dan Waktu!',
                        Colors.orange,
                      );
                      return;
                    }

                    final formatMulai =
                        '${jamMulai!.hour.toString().padLeft(2, '0')}:${jamMulai!.minute.toString().padLeft(2, '0')}:00';
                    final formatSelesai =
                        '${jamSelesai!.hour.toString().padLeft(2, '0')}:${jamSelesai!.minute.toString().padLeft(2, '0')}:00';

                    try {
                      final data = {
                        'hari': selectedHari,
                        'kelas': selectedKelas,
                        'mata_pelajaran': selectedMapel,
                        'guru_pengampu': selectedGuru,
                        'jam_mulai': formatMulai,
                        'jam_selesai': formatSelesai,
                      };

                      if (isEdit) {
                        await _supabase
                            .from('jadwal')
                            .update(data)
                            .eq('id', jadwal['id']);
                      } else {
                        await _supabase.from('jadwal').insert(data);
                      }

                      Navigator.pop(context);
                      _fetchJadwal();
                      _showSnackBar(
                        'Jadwal berhasil disimpan & disinkronkan!',
                        Colors.green,
                      );
                    } catch (e) {
                      _showSnackBar('Error: $e', Colors.red);
                    }
                  },
                  child: const Text(
                    'Simpan Jadwal',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _hapusJadwal(int id) async {
    try {
      await _supabase.from('jadwal').delete().eq('id', id);
      _fetchJadwal();
      _showSnackBar('Jadwal berhasil dihapus', Colors.green);
    } catch (e) {
      _showSnackBar('Gagal menghapus: $e', Colors.red);
    }
  }

  void _showSnackBar(String pesan, Color warna) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: warna,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildGroupedJadwalView() {
    if (_jadwalList.isEmpty) {
      return const Center(child: Text('Belum ada jadwal yang ditambahkan.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        String kelasTujuan = _kelasList[index];
        List<dynamic> jadwalKelasIni = _jadwalList
            .where((j) => j['kelas'] == kelasTujuan)
            .toList();

        if (jadwalKelasIni.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Text(
              kelasTujuan,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue.shade900,
              ),
            ),
            leading: Icon(
              Icons.folder_shared_rounded,
              color: Colors.blue.shade700,
              size: 32,
            ),
            children: _hariList.map((hariTujuan) {
              List<dynamic> jadwalHariIni = jadwalKelasIni
                  .where((j) => j['hari'] == hariTujuan)
                  .toList();
              if (jadwalHariIni.isEmpty) return const SizedBox.shrink();

              return ExpansionTile(
                title: Text(
                  hariTujuan,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                leading: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.orange,
                ),
                backgroundColor: Colors.grey.shade50,
                children: jadwalHariIni.map((jadwal) {
                  final jamMulai = _formatTime(jadwal['jam_mulai'] ?? '');
                  final jamSelesai = _formatTime(jadwal['jam_selesai'] ?? '');

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Colors.blue.shade900, width: 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      title: Text(
                        '${jadwal['mata_pelajaran']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Guru: ${jadwal['guru_pengampu']}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Waktu: $jamMulai - $jamSelesai',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.orange,
                              size: 20,
                            ),
                            onPressed: () => _showFormDialog(jadwal: jadwal),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _hapusJadwal(jadwal['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
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
          'Manajemen Jadwal Real-Time',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildGroupedJadwalView(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade900,
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tambah Jadwal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
