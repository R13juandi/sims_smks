import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RekapAbsensiSiswaScreen extends StatefulWidget {
  const RekapAbsensiSiswaScreen({super.key});

  @override
  State<RekapAbsensiSiswaScreen> createState() =>
      _RekapAbsensiSiswaScreenState();
}

class _RekapAbsensiSiswaScreenState extends State<RekapAbsensiSiswaScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _absenGanjil = [];
  List<Map<String, dynamic>> _absenGenap = [];

  @override
  void initState() {
    super.initState();
    _fetchDataAbsensiSiswa();
  }

  Future<void> _fetchDataAbsensiSiswa() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final res = await _supabase
          .from('absensi')
          .select('*')
          .eq('siswa_id', user.id)
          .order('tanggal', ascending: false);

      final List<Map<String, dynamic>> allAbsen =
          List<Map<String, dynamic>>.from(res);

      List<Map<String, dynamic>> ganjilTemp = [];
      List<Map<String, dynamic>> genapTemp = [];

      for (var absen in allAbsen) {
        if (absen['tanggal'] != null) {
          DateTime dateParsed = DateTime.parse(absen['tanggal'].toString());

          // Bulan Juli (7) s.d Desember (12) -> Ganjil
          if (dateParsed.month >= 7 && dateParsed.month <= 12) {
            ganjilTemp.add(absen);
          }
          // Bulan Januari (1) s.d Juni (6) -> Genap
          else {
            genapTemp.add(absen);
          }
        }
      }

      if (mounted) {
        setState(() {
          _absenGanjil = ganjilTemp;
          _absenGenap = genapTemp;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error mengambil rekap absensi siswa: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat rekap absensi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Rekap Absensi Saya',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF1E40AF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1E40AF),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: 'Semester 1 (Ganjil)'),
              Tab(text: 'Semester 2 (Genap)'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAbsenListView(
                    _absenGanjil,
                    'Belum ada data absensi tercatat di Semester Ganjil.',
                  ),
                  _buildAbsenListView(
                    _absenGenap,
                    'Belum ada data absensi tercatat di Semester Genap.\n\n(Catatan: Jika Anda baru saja absen di bulan Januari-Juni, datanya ada di sini)',
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAbsenListView(
    List<Map<String, dynamic>> dataAbsen,
    String pesanKosong,
  ) {
    if (dataAbsen.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            pesanKosong,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dataAbsen.length,
      itemBuilder: (context, index) {
        final item = dataAbsen[index];
        final String statusKode = item['status']?.toString() ?? 'H';

        String textStatus = 'Hadir';
        Color warnaStatus = Colors.green;
        IconData iconStatus = Icons.check_circle_rounded;

        // 🔥 PEMETAAN KONDISI UNTUK STATUS STATUS BARU
        if (statusKode == 'I') {
          textStatus = 'Izin / Sakit';
          warnaStatus = Colors.orange;
          iconStatus = Icons.info_rounded;
        } else if (statusKode == 'A') {
          textStatus = 'Alfa';
          warnaStatus = Colors.red;
          iconStatus = Icons.cancel_rounded;
        } else if (statusKode == 'T') {
          textStatus = 'Terlambat';
          warnaStatus = Colors
              .amber
              .shade700; // Warna amber/kuning tua untuk penanda telat
          iconStatus = Icons.watch_later_rounded;
        }

        String tanggalTampil = item['tanggal'] ?? '-';
        if (item['tanggal'] != null) {
          try {
            DateTime dt = DateTime.parse(item['tanggal'].toString());
            tanggalTampil = DateFormat('dd MMMM yyyy', 'id').format(dt);
          } catch (_) {
            try {
              DateTime dt = DateTime.parse(item['tanggal'].toString());
              tanggalTampil = DateFormat('dd MMM yyyy').format(dt);
            } catch (_) {}
          }
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconStatus, color: warnaStatus, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['mapel'] ?? 'Mata Pelajaran',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kelas: ${item['kelas'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: warnaStatus.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              textStatus,
                              style: TextStyle(
                                color: warnaStatus,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tanggalTampil,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text(
                        'Keterangan Sistem:\n${item['keterangan'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
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
    );
  }
}
