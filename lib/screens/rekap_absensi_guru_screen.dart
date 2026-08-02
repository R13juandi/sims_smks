import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/popup_service.dart';
import '../login_screen.dart';
import 'rekap_nilai_admin_screen.dart';
import 'tambah_user_screen.dart';
import 'manajemen_user_screen.dart';
import 'seeder_database_screen.dart';
import 'manajemen_jadwal_screen.dart';
import 'nilai_rapor_screen.dart'; 

class RekapAbsensiGuruScreen extends StatefulWidget {
  const RekapAbsensiGuruScreen({super.key});

  @override
  State<RekapAbsensiGuruScreen> createState() => _RekapAbsensiGuruScreenState();
}

class _RekapAbsensiGuruScreenState extends State<RekapAbsensiGuruScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Data untuk Tab 1: Aksi Cepat / Verifikasi Harian
  List<Map<String, dynamic>> _dataAbsen = [];
  DateTime _selectedDate = DateTime.now();
  String _namaGuruLogin = '';

  // 🔥 FILTER REVISI DOSEN UNTUK TAB 1 (AKSI CEPAT)
  String _selectedKelasTab1 = 'Semua Kelas';
  String _selectedMapelTab1 = 'Semua Mapel';
  List<String> _listKelasTab1 = ['Semua Kelas'];
  List<String> _listMapelTab1 = ['Semua Mapel'];

  // Data untuk Tab 2: Rekap Akumulasi
  List<Map<String, dynamic>> _listRekapSiswa = [];
  String _selectedKelasFilter = 'Semua Kelas';
  List<String> _daftarKelas = ['Semua Kelas'];

  @override
  void initState() {
    super.initState();
    _fetchGuruDanRekap();
  }

  // =========================================================================
  // 🔥 MENGAMBIL DATA UNTUK KEDUA TAB SEKALIGUS
  // =========================================================================
  Future<void> _fetchGuruDanRekap() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final profile = await _supabase.from('profiles').select('full_name').eq('id', user.id).single();
      _namaGuruLogin = profile['full_name'].toString().trim();
      final tanggalFilter = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // 1. Tarik data Absensi Harian (Untuk Tab 1 - Aksi Cepat & Verifikasi)
      final res = await _supabase.from('absensi')
          .select('*, profiles!inner(full_name, nisn, kelas)')
          .eq('tanggal', tanggalFilter)
          .or('guru_pengampu.ilike.%$_namaGuruLogin%,mapel.eq.Pulang Sekolah')
          .order('waktu_absen', ascending: false);

      // Mengumpulkan daftar Kelas dan Mapel yang aktif HARI INI
      Set<String> setK1 = {'Semua Kelas'};
      Set<String> setM1 = {'Semua Mapel'};
      for (var a in res) {
        final p = a['profiles'] ?? {};
        final k = (p['kelas'] ?? '').toString().trim();
        final m = (a['mapel'] ?? '').toString().trim();
        if (k.isNotEmpty) setK1.add(k);
        if (m.isNotEmpty) setM1.add(m);
      }

      // 2. Tarik daftar Siswa & Rekap Keseluruhan (Untuk Tab 2 - Rekap Akumulasi)
      final resSiswa = await _supabase
          .from('profiles')
          .select('id, full_name, kelas, nisn')
          .eq('role', 'siswa')
          .order('full_name', ascending: true);

      final resSemuaAbsen = await _supabase
          .from('absensi')
          .select('siswa_id, status');

      // Bangun daftar kelas unik untuk dropdown filter Tab 2
      Set<String> setKelas = {'Semua Kelas'};
      for (var s in resSiswa) {
        if (s['kelas'] != null && s['kelas'].toString().trim().isNotEmpty) {
          setKelas.add(s['kelas'].toString());
        }
      }

      // Agregasi persentase rekap per siswa
      List<Map<String, dynamic>> rekapList = [];
      for (var s in resSiswa) {
        String sId = s['id'].toString();
        int hadir = 0;
        int izin = 0;
        int sakit = 0;
        int alfa = 0;

        for (var a in resSemuaAbsen) {
          if (a['siswa_id'].toString() == sId) {
            String st = (a['status'] ?? '').toString().toUpperCase();
            if (st == 'H' || st == 'HADIR') hadir++;
            else if (st == 'I' || st == 'IZIN') izin++;
            else if (st == 'S' || st == 'SAKIT') sakit++;
            else alfa++;
          }
        }

        int total = hadir + izin + sakit + alfa;
        double persentase = total > 0 ? (hadir / total) * 100 : 0.0;

        rekapList.add({
          'id': sId,
          'full_name': s['full_name'] ?? '-',
          'kelas': s['kelas'] ?? '-',
          'nisn': s['nisn'] ?? '-',
          'hadir': hadir,
          'izin': izin,
          'sakit': sakit,
          'alfa': alfa,
          'persentase': persentase,
        });
      }

      if (mounted) {
        setState(() { 
          _dataAbsen = List<Map<String, dynamic>>.from(res); 
          _listRekapSiswa = rekapList;
          _daftarKelas = setKelas.toList();
          
          // Set dropdown list Tab 1
          _listKelasTab1 = setK1.toList()..sort((a,b) => a == 'Semua Kelas' ? -1 : a.compareTo(b));
          _listMapelTab1 = setM1.toList()..sort((a,b) => a == 'Semua Mapel' ? -1 : a.compareTo(b));
          
          // Reset pilihan jika tidak ada di list
          if (!_listKelasTab1.contains(_selectedKelasTab1)) _selectedKelasTab1 = 'Semua Kelas';
          if (!_listMapelTab1.contains(_selectedMapelTab1)) _selectedMapelTab1 = 'Semua Mapel';

          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(context, 'Gagal memuat rekap: $e', isSuccess: false, judul: 'Error');
      }
    }
  }

  // Fungsi untuk update status oleh Guru
  Future<void> _updateStatusAbsen(dynamic id, String statusBaru, String verifikasi) async {
    try {
      await _supabase.from('absensi').update({
        'status': statusBaru, 
        'status_verifikasi': verifikasi
      }).eq('id', id);
      
      _fetchGuruDanRekap();
      if (!mounted) return;
      PopupService.show(context, 'Status absensi berhasil diperbarui menjadi "$verifikasi"!', isSuccess: true, judul: 'Berhasil');
    } catch (e) {
      PopupService.show(context, 'Gagal memperbarui: $e', isSuccess: false, judul: 'Gagal');
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime(2024), 
      lastDate: DateTime.now()
    );
    if (picked != null) { 
      setState(() => _selectedDate = picked); 
      _fetchGuruDanRekap(); 
    }
  }

  void _tampilkanDetailFoto(BuildContext context, String url, String namaSiswa) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Bukti Presensi: $namaSiswa', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)), 
              backgroundColor: Colors.white, 
              elevation: 0, 
              automaticallyImplyLeading: false, 
              actions: [IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))]
            ),
            InteractiveViewer(
              panEnabled: true, minScale: 0.5, maxScale: 4.0, 
              child: Image.network(url, fit: BoxFit.contain, loadingBuilder: (context, child, loadingProgress) { 
                if (loadingProgress == null) return child; 
                return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())); 
              }, errorBuilder: (context, error, stackTrace) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.red))))
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter untuk Tab 2 (Rekap Akumulasi)
    final filteredRekap = _selectedKelasFilter == 'Semua Kelas'
        ? _listRekapSiswa
        : _listRekapSiswa.where((item) => item['kelas'] == _selectedKelasFilter).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Presensi & Rekap Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          backgroundColor: const Color(0xFF1E40AF),
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.fact_check_rounded), text: 'Aksi Cepat & Verifikasi'),
              Tab(icon: Icon(Icons.analytics_rounded), text: 'Rekap Akumulasi'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
            : TabBarView(
                children: [
                  _buildTabAksiCepatHarian(),
                  _buildTabRekapAkumulasi(filteredRekap),
                ],
              ),
      ),
    );
  }

  // =========================================================================
  // WIDGET TAB 1 (REVISI DOSEN: FILTER & GROUPING KELAS + MAPEL)
  // =========================================================================
  Widget _buildTabAksiCepatHarian() {
    // 1. Filter Data Berdasarkan Dropdown
    final filteredTab1 = _dataAbsen.where((a) {
      final k = (a['profiles']?['kelas'] ?? '').toString().trim();
      final m = (a['mapel'] ?? '').toString().trim();
      bool matchK = _selectedKelasTab1 == 'Semua Kelas' || k == _selectedKelasTab1;
      bool matchM = _selectedMapelTab1 == 'Semua Mapel' || m == _selectedMapelTab1;
      return matchK && matchM;
    }).toList();

    // 2. Grouping Data yang Sudah Difilter Berdasarkan (Kelas | Mapel)
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var a in filteredTab1) {
      final k = (a['profiles']?['kelas'] ?? 'Tanpa Kelas').toString().trim();
      final m = (a['mapel'] ?? 'Tanpa Mapel').toString().trim();
      final key = '$k|$m'; // Kunci grup gabungan
      if (!groupedData.containsKey(key)) groupedData[key] = [];
      groupedData[key]!.add(a);
    }

    final sortedKeys = groupedData.keys.toList()..sort();

    return Column(
      children: [
        // HEADER: TANGGAL
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Text(
                    'Tanggal: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  side: const BorderSide(color: Color(0xFF1E40AF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pilihTanggal,
                icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF1E40AF)),
                label: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
              ),
            ],
          ),
        ),
        
        // FILTER DROPDOWN REVISI DOSEN
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedKelasTab1,
                  decoration: InputDecoration(
                    labelText: 'Filter Kelas',
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true, contentPadding: const EdgeInsets.all(10)
                  ),
                  items: _listKelasTab1.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _selectedKelasTab1 = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMapelTab1,
                  decoration: InputDecoration(
                    labelText: 'Filter Mapel',
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true, contentPadding: const EdgeInsets.all(10)
                  ),
                  items: _listMapelTab1.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _selectedMapelTab1 = v!),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // DAFTAR ABSENSI YANG SUDAH DIGRUPKAN PER KELAS & MAPEL
        Expanded(
          child: groupedData.isEmpty
              ? const Center(child: Text('Tidak ada data absensi mengajar pada filter ini.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16), 
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final key = sortedKeys[index];
                    final kelasGroup = key.split('|')[0];
                    final mapelGroup = key.split('|')[1];
                    final listSiswa = groupedData[key]!;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue.shade200, width: 1.5)),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        backgroundColor: Colors.white,
                        collapsedBackgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: const Icon(Icons.class_, color: Color(0xFF1E40AF))),
                        title: Text('Kelas $kelasGroup', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 16)),
                        subtitle: Text('📚 Mapel: $mapelGroup  •  👥 ${listSiswa.length} Siswa', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade800, fontSize: 12)),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                            child: Column(
                              children: listSiswa.map((a) {
                                final p = a['profiles'] ?? {};
                                final String? fotoUrl = a['foto_url'];
                                final String namaMurid = p['full_name'] ?? 'Nama Tidak Dikenal';
                                final String verifikasi = a['status_verifikasi'] ?? 'Pending';
                                final String jamAbsen = a['waktu_absen'] ?? '-'; 
                                
                                // SAFE PARSING UNTUK LAT/LNG DI LIST AGAR TIDAK SILENT CRASH
                                double? lat;
                                if (a['lat'] != null) lat = double.tryParse(a['lat'].toString());
                                double? lng;
                                if (a['lng'] != null) lng = double.tryParse(a['lng'].toString());

                                final String namaLokasi = (a['lokasi'] ?? a['nama_lokasi'] ?? '').toString();
                                final String jarak = (a['jarak'] ?? '').toString();
                                String infoLokasi = namaLokasi.isNotEmpty ? '📍 Area: $namaLokasi ${jarak.isNotEmpty ? "($jarak m)" : ""}\n' : '';
                                
                                String statusText = 'Hadir'; Color warnaStatus = Colors.green; String kodeTampil = a['status'] ?? 'H';
                                if (a['status'] == 'I') { statusText = 'Izin / Sakit'; warnaStatus = Colors.orange; } else if (a['status'] == 'A') { statusText = 'Alfa'; warnaStatus = Colors.red; } else if (a['status'] == 'T') { statusText = 'Terlambat'; warnaStatus = Colors.amber.shade700; }

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12), 
                                    side: BorderSide(color: verifikasi == 'Pending' ? Colors.orange : Colors.grey.shade300, width: verifikasi == 'Pending' ? 1.5 : 1.0)
                                  ),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  // HAPUS INKWELL ONTAP DETAIL DI SINI
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(radius: 20, backgroundColor: warnaStatus.withOpacity(0.15), child: Text(kodeTampil, style: TextStyle(color: warnaStatus, fontWeight: FontWeight.bold, fontSize: 16))),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(namaMurid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text('NISN: ${p['nisn'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.grey))])),
                                                      const SizedBox(width: 8),
                                                      if (a['status'] == 'I') Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_document, color: Colors.orange, size: 20))
                                                      else if (fotoUrl != null && fotoUrl.isNotEmpty) GestureDetector(onTap: () => _tampilkanDetailFoto(context, fotoUrl, namaMurid), child: MouseRegion(cursor: SystemMouseCursors.click, child: Tooltip(message: 'Klik untuk perbesar', child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.blue.shade200, width: 1.5), borderRadius: BorderRadius.circular(8)), child: Image.network(fotoUrl, width: 45, height: 45, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) { if (loadingProgress == null) return child; return const SizedBox(width: 45, height: 45, child: Center(child: CircularProgressIndicator(strokeWidth: 2))); }, errorBuilder: (context, error, stackTrace) => Container(width: 45, height: 45, color: Colors.red.shade50, child: const Icon(Icons.broken_image, color: Colors.red, size: 20))))))))
                                                      else Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, color: Colors.grey, size: 20)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Text('⏰ $jamAbsen', style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                                      const Spacer(),
                                                      if (lat != null && lng != null)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                                          child: Row(
                                                            children: [const Icon(Icons.location_on, size: 10, color: Colors.blue), const SizedBox(width: 2), Text('$lat, $lng', style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold))],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    width: double.infinity, padding: const EdgeInsets.all(8), 
                                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), 
                                                    child: Text('📌 Verifikasi: $verifikasi\n$infoLokasi📝 Ket: ${a['keterangan']}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black87, height: 1.4))
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        // 🔥 TOMBOL AKSI DIBUAT LEBIH RAPI & BESAR TANPA TOMBOL DETAIL
                                        if (verifikasi == 'Pending' || a['status'] != 'A') ...[
                                          const Divider(height: 24),
                                          Row(
                                            children: [
                                              if (verifikasi == 'Pending') 
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), padding: const EdgeInsets.symmetric(vertical: 10)), 
                                                    onPressed: () => _updateStatusAbsen(a['id'], a['status'], 'Disetujui'), 
                                                    icon: const Icon(Icons.check_circle, size: 16), 
                                                    label: Text(a['status'] == 'I' ? 'ACC IZIN' : 'ACC SAH')
                                                  ),
                                                ),
                                              if (verifikasi == 'Pending' && a['status'] != 'A') const SizedBox(width: 10),
                                              if (a['status'] != 'A') 
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), padding: const EdgeInsets.symmetric(vertical: 10)), 
                                                    onPressed: () => _updateStatusAbsen(a['id'], 'A', 'Ditolak'), 
                                                    icon: const Icon(Icons.cancel, size: 16), 
                                                    label: const Text('ALFA / TOLAK')
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // WIDGET TAB 2: REKAP AKUMULASI KESELURUHAN
  // =========================================================================
  Widget _buildTabRekapAkumulasi(List<Map<String, dynamic>> filteredRekap) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF1E40AF)),
              const SizedBox(width: 10),
              const Text('Filter Kelas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedKelasFilter,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: _daftarKelas.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedKelasFilter = val);
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredRekap.isEmpty
              ? const Center(child: Text('Tidak ada siswa pada kelas terpilih.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRekap.length,
                  itemBuilder: (context, index) {
                    final item = filteredRekap[index];
                    double persentase = item['persentase'] ?? 0.0;
                    bool isRajin = persentase >= 80.0;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade300)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(item['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: isRajin ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '${persentase.toStringAsFixed(1)}%',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isRajin ? Colors.green.shade700 : Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Kelas: ${item['kelas']} | NISN: ${item['nisn']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _itemStat('Hadir', item['hadir'].toString(), Colors.green.shade700),
                                _itemStat('Izin', item['izin'].toString(), Colors.orange.shade700),
                                _itemStat('Sakit', item['sakit'].toString(), Colors.blue.shade700),
                                _itemStat('Alfa', item['alfa'].toString(), Colors.red.shade700),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _itemStat(String label, String count, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(count, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}