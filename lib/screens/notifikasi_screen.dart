import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  final _supabase = Supabase.instance.client;
  final _judulController = TextEditingController();
  final _pesanController = TextEditingController();
  String _selectedTipe = 'rapat';

  Future<void> _kirimPengumuman() async {
    if (_judulController.text.isEmpty || _pesanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan pesan wajib diisi!')),
      );
      return;
    }

    try {
      await _supabase.from('pengumuman').insert({
        'judul': _judulController.text.trim(),
        'pesan': _pesanController.text.trim(),
        'tipe': _selectedTipe,
      });

      _judulController.clear();
      _pesanController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi berhasil dikirim ke semua user')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kirim Pengumuman / Notif")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tipe Pengumuman:", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: _selectedTipe,
              items: ['rapat', 'libur'].map((t) {
                return DropdownMenuItem(value: t, child: Text(t.toUpperCase()));
              }).toList(),
              onChanged: (val) => setState(() => _selectedTipe = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _judulController,
              decoration: const InputDecoration(labelText: "Judul Pengumuman", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pesanController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Pesan/Informasi", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
                onPressed: _kirimPengumuman,
                child: const Text("Kirim Notifikasi"),
              ),
            )
          ],
        ),
      ),
    );
  }
}