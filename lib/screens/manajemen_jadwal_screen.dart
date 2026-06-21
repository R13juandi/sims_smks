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

  // Daftar Pilihan Kelas Tetap (Hanya TKJ)
  final List<String> _kelasList = ['X TKJ', 'XI TKJ', 'XII TKJ'];

  // Daftar Pilihan Mata Pelajaran Tetap (Disesuaikan untuk TKJ)
  final List<String> _mapelList = [
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

  // MENGAMBIL DAFTAR GURU DARI DATABASE
  Future<void> _fetchGurus() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('nama')
          .eq('role', 'Guru')
          .order('nama', ascending: true);

      if (mounted) {
        setState(() {
          _guruList = (response as List)
              .map((g) => g['nama'].toString())
              .toList();
        });
      }
    } catch (e) {
      print('Error fetch guru: $e');
    }
  }

  // MENGAMBIL DAFTAR JADWAL
  Future<void> _fetchJadwal() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('jadwal')
          .select()
          .order('hari')
          .order('jam_mulai');
      if (mounted) {
        setState(() {
          _jadwalList = data;
        });
      }
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

  // DIALOG TAMBAH / EDIT JADWAL DENGAN DROPDOWN
  void _showFormDialog({Map<String, dynamic>? jadwal}) {
    final isEdit = jadwal != null;

    String? selectedHari = isEdit ? jadwal['hari'] : 'Senin';
    String? selectedKelas = isEdit ? jadwal['kelas'] : null;
    String? selectedMapel = isEdit ? jadwal['mata_pelajaran'] : null;
    String? selectedGuru = isEdit ? jadwal['guru_pengampu'] : null;

    if (isEdit) {
      if (selectedKelas != null && !_kelasList.contains(selectedKelas))
        _kelasList.add(selectedKelas!);
      if (selectedMapel != null && !_mapelList.contains(selectedMapel))
        _mapelList.add(selectedMapel!);
      if (selectedGuru != null && !_guruList.contains(selectedGuru))
        _guruList.add(selectedGuru!);
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
                    // DROPDOWN HARI
                    DropdownButtonFormField<String>(
                      value: selectedHari,
                      items:
                          ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']
                              .map(
                                (h) =>
                                    DropdownMenuItem(value: h, child: Text(h)),
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

                    // DROPDOWN KELAS
                    DropdownButtonFormField<String>(
                      value: selectedKelas,
                      hint: const Text('Pilih Kelas'),
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

                    // DROPDOWN GURU (Dinamic dari Database)
                    DropdownButtonFormField<String>(
                      value: selectedGuru,
                      hint: Text(
                        _guruList.isEmpty
                            ? 'Memuat guru...'
                            : 'Pilih Guru Pengampu',
                      ),
                      items: _guruList
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedGuru = val),
                      decoration: const InputDecoration(
                        labelText: 'Guru Pengampu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // DROPDOWN MATA PELAJARAN
                    DropdownButtonFormField<String>(
                      value: selectedMapel,
                      hint: const Text('Pilih Mata Pelajaran'),
                      items: _mapelList
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedMapel = val),
                      decoration: const InputDecoration(
                        labelText: 'Mata Pelajaran',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // WAKTU MULAI & SELESAI
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
                        'Harap pilih semua Dropdown dan Waktu!',
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
          : _jadwalList.isEmpty
          ? const Center(child: Text('Belum ada jadwal yang ditambahkan.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _jadwalList.length,
              itemBuilder: (context, index) {
                final jadwal = _jadwalList[index];
                final jamMulai = _formatTime(jadwal['jam_mulai'] ?? '');
                final jamSelesai = _formatTime(jadwal['jam_selesai'] ?? '');

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            jamMulai,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            jamSelesai,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      '${jadwal['mata_pelajaran']} (${jadwal['kelas']})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${jadwal['hari']} • Guru: ${jadwal['guru_pengampu']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () => _showFormDialog(jadwal: jadwal),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _hapusJadwal(jadwal['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
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
