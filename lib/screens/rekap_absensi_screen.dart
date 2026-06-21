import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RekapAbsensiScreen extends StatefulWidget {
  const RekapAbsensiScreen({super.key});

  @override
  State<RekapAbsensiScreen> createState() => _RekapAbsensiScreenState();
}

class _RekapAbsensiScreenState extends State<RekapAbsensiScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listAbsen = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRekapAbsen();
  }

  Future<void> _fetchRekapAbsen() async {
    try {
      final response = await _supabase
          .from('absensi')
          .select('*, profiles(full_name, role)')
          .order('tanggal', ascending: false);

      setState(() {
        _listAbsen = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat rekap: $e')));
    }
  }

  // Fungsi Edit Data Absensi
  void _editAbsen(Map<String, dynamic> data) {
    final keteranganController = TextEditingController(
      text: data['keterangan'] ?? '',
    );

    // Pastikan data status seragam lower-case dan tidak ada spasi berlebih
    String selectedStatus = (data['status'] ?? 'hadir')
        .toString()
        .toLowerCase()
        .trim();
    final List<String> statusOptions = ['hadir', 'sakit', 'izin', 'alpha'];

    // Amankan agar nilai status selalu ada di dalam list options
    if (!statusOptions.contains(selectedStatus)) {
      selectedStatus = 'hadir';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Data Absensi"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: "Status Kehadiran",
                      border: OutlineInputBorder(),
                    ),
                    items: statusOptions.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val[0].toUpperCase() + val.substring(1)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        selectedStatus = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keteranganController,
                    decoration: const InputDecoration(
                      labelText: "Keterangan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await _supabase
                          .from('absensi')
                          .update({
                            'status': selectedStatus,
                            'keterangan': keteranganController.text.trim(),
                          })
                          .eq('id', data['id']);

                      if (!mounted) return;
                      Navigator.pop(context);
                      _fetchRekapAbsen();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Berhasil mengubah data absensi.'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fungsi Konfirmasi Hapus Absensi
  void _konfirmasiHapus(String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Hapus Absensi"),
          content: const Text("Apakah Anda yakin ingin menghapus data ini?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                await _supabase.from('absensi').delete().eq('id', id);
                if (!mounted) return;
                Navigator.pop(context);
                _fetchRekapAbsen();
              },
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Rekap Absensi"),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listAbsen.isEmpty
          ? const Center(child: Text("Belum ada data absensi."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _listAbsen.length,
              itemBuilder: (context, index) {
                final item = _listAbsen[index];
                final profile = item['profiles'] ?? {};
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(
                      profile['full_name'] ?? 'Pengguna',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Tanggal: ${item['tanggal']} | Status: ${item['status']}\nKeterangan: ${item['keterangan'] ?? '-'}",
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editAbsen(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _konfirmasiHapus(item['id'].toString()),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
