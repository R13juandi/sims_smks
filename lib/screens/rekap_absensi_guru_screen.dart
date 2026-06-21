import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RekapAbsensiGuruScreen extends StatefulWidget {
  const RekapAbsensiGuruScreen({super.key});

  @override
  State<RekapAbsensiGuruScreen> createState() => _RekapAbsensiGuruScreenState();
}

class _RekapAbsensiGuruScreenState extends State<RekapAbsensiGuruScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _dataAbsen = [];
  DateTime _selectedDate = DateTime.now();
  String _namaGuruLogin = '';

  @override
  void initState() {
    super.initState();
    _fetchGuruDanRekap();
  }

  Future<void> _fetchGuruDanRekap() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Ambil nama guru yang sedang login untuk memfilter rekapnya sendiri
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();
      _namaGuruLogin = profile['full_name'].toString().trim();

      // 2. Ambil data rekap absen berdasarkan tanggal dan nama guru
      final tanggalFilter = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final res = await _supabase
          .from('absensi')
          .select('*, profiles!inner(full_name, nisn)')
          .eq('tanggal', tanggalFilter)
          .ilike(
            'guru_pengampu',
            '%$_namaGuruLogin%',
          ); // Mengunci agar guru hanya melihat rekap mengajar mereka sendiri

      if (mounted) {
        setState(() {
          _dataAbsen = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error rekap guru: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchGuruDanRekap();
    }
  }

  // 🔥 FUNGSI BARU: MENAMPILKAN DETAIL FOTO JIKA DI-KLIK (BISA DI-ZOOM)
  void _tampilkanDetailFoto(
    BuildContext context,
    String url,
    String namaSiswa,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                'Bukti Presensi: $namaSiswa',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            // Menggunakan InteractiveViewer agar foto bisa dicubit/di-zoom oleh guru
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 50,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Rekap Absensi Harian',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pilihTanggal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Ganti'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dataAbsen.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada data absensi mengajar Anda di tanggal ini.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _dataAbsen.length,
                    itemBuilder: (context, index) {
                      final a = _dataAbsen[index];
                      final p = a['profiles'] ?? {};
                      final String? fotoUrl = a['foto_url'];
                      final String namaMurid =
                          p['full_name'] ?? 'Nama Tidak Dikenal';

                      // PEMETAAN STATUS
                      String statusText = 'Hadir';
                      Color warnaStatus = Colors.green;
                      String kodeTampil = a['status'] ?? 'H';

                      if (a['status'] == 'I') {
                        statusText = 'Izin';
                        warnaStatus = Colors.orange;
                      } else if (a['status'] == 'A') {
                        statusText = 'Alfa';
                        warnaStatus = Colors.red;
                      } else if (a['status'] == 'T') {
                        statusText = 'Terlambat';
                        warnaStatus = Colors.amber.shade700;
                      }

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: warnaStatus.withOpacity(0.15),
                                child: Text(
                                  kodeTampil,
                                  style: TextStyle(
                                    color: warnaStatus,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                namaMurid,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                'NISN: ${p['nisn'] ?? '-'}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // 🔥 BAGIAN FOTO DIBERI TOOL GESTURE DETECTOR AGAR BISA DI-KLIK
                                        if (a['status'] == 'I')
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.edit_document,
                                              color: Colors.orange,
                                            ),
                                          )
                                        else if (fotoUrl != null &&
                                            fotoUrl.isNotEmpty)
                                          GestureDetector(
                                            onTap: () => _tampilkanDetailFoto(
                                              context,
                                              fotoUrl,
                                              namaMurid,
                                            ),
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: Tooltip(
                                                message: 'Klik untuk perbesar',
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Colors
                                                            .blue
                                                            .shade200,
                                                        width: 1.5,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Image.network(
                                                      fotoUrl,
                                                      width: 50,
                                                      height: 50,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder:
                                                          (
                                                            context,
                                                            child,
                                                            loadingProgress,
                                                          ) {
                                                            if (loadingProgress ==
                                                                null)
                                                              return child;
                                                            return const SizedBox(
                                                              width: 50,
                                                              height: 50,
                                                              child: Center(
                                                                child:
                                                                    CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                              ),
                                                            );
                                                          },
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => Container(
                                                            width: 50,
                                                            height: 50,
                                                            color: Colors
                                                                .red
                                                                .shade50,
                                                            child: const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color: Colors.red,
                                                              size: 20,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Divider(height: 16),

                                    Text(
                                      '👨‍🏫 Guru Pengampu : ${a['guru_pengampu'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF334155),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '🏫 Kelas : ${a['kelas'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📚 Mapel: ${a['mapel'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '📌 Status: $statusText\n📝 Keterangan: ${a['keterangan']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
