import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import '../services/popup_service.dart';

class AdminGuruPenggantiScreen extends StatefulWidget {
  const AdminGuruPenggantiScreen({super.key});

  @override
  State<AdminGuruPenggantiScreen> createState() => _AdminGuruPenggantiScreenState();
}

class _AdminGuruPenggantiScreenState extends State<AdminGuruPenggantiScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Data Master
  List<Map<String, dynamic>> _jadwalList = [];
  List<Map<String, dynamic>> _penggantiListAktif = [];
  List<Map<String, dynamic>> _penggantiListHistori = [];
  List<Map<String, dynamic>> _guruList = [];
  Map<String, String> _mapNamaGuru = {}; 

  // Filter Tab Penugasan
  String _selectedHari = 'Senin';
  String _selectedKelas = 'Semua Kelas';
  List<String> _daftarKelas = ['Semua Kelas'];
  final List<String> _daftarHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  // Info Semester Aktif
  String _infoSemesterAktif = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null); 
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil Kamus Nama Guru
      final resProfiles = await _supabase.from('profiles').select('id, full_name, role');
      List<Map<String, dynamic>> tempGuruList = [];
      
      for (var p in resProfiles) {
        _mapNamaGuru[p['id'].toString()] = p['full_name'].toString();
        if ((p['role'] ?? '').toString().toLowerCase() == 'guru') {
          tempGuruList.add(p);
        }
      }
      
      tempGuruList.sort((a, b) => (a['full_name'] ?? '').toString().compareTo((b['full_name'] ?? '').toString()));
      _guruList = tempGuruList;

      // 2. Deteksi Semester Aktif
      DateTime now = DateTime.now();
      int currentStartYear = now.month >= 7 ? now.year : now.year - 1;
      String currentTa = "$currentStartYear/${currentStartYear + 1}";
      String currentSmtStr = now.month >= 7 ? "Ganjil" : "Genap";
      _infoSemesterAktif = 'Semester $currentSmtStr ($currentTa)';

      // 3. Ambil Jadwal Master Semester Ini
      final resJadwal = await _supabase
          .from('jadwal')
          .select()
          .eq('semester', currentSmtStr)
          .eq('tahun_ajaran', currentTa)
          .order('jam_mulai', ascending: true);
          
      _jadwalList = List<Map<String, dynamic>>.from(resJadwal);

      Set<String> setKelas = {'Semua Kelas'};
      for (var j in _jadwalList) {
        if (j['kelas'] != null) setKelas.add(j['kelas'].toString().trim());
      }
      _daftarKelas = setKelas.toList()..sort((a, b) => a == 'Semua Kelas' ? -1 : a.compareTo(b));

      // 4. Ambil Jadwal Pengganti (Bagi jadi Aktif & Histori)
      final resPengganti = await _supabase.from('jadwal_pengganti').select().order('tanggal', ascending: false);
      
      List<Map<String, dynamic>> allPengganti = List<Map<String, dynamic>>.from(resPengganti);
      _penggantiListAktif.clear();
      _penggantiListHistori.clear();
      
      // Tanggal hari ini jam 00:00 untuk perbandingan akurat
      DateTime todayStart = DateTime(now.year, now.month, now.day);

      for (var p in allPengganti) {
        DateTime tglInfal = DateTime.parse(p['tanggal']);
        if (tglInfal.isBefore(todayStart)) {
          _penggantiListHistori.add(p); // Sudah lewat (Histori)
        } else {
          _penggantiListAktif.add(p); // Hari ini atau akan datang (Aktif)
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(context, 'Gagal memuat data: $e', isSuccess: false, judul: 'Error');
      }
    }
  }

  void _bukaDialogSetPengganti(Map<String, dynamic> jadwal) {
    DateTime selectedDate = DateTime.now();
    String? selectedGuruId;
    final keteranganCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.person_pin_circle_rounded, color: Color(0xFF1E40AF)),
                  SizedBox(width: 8),
                  Text('Set Guru Pengganti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${jadwal['mata_pelajaran']} - Kelas ${jadwal['kelas']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          const SizedBox(height: 6),
                          Text('Guru Asli: ${_mapNamaGuru[jadwal['guru_id'].toString()] ?? jadwal['guru_pengampu'] ?? 'Tidak Diketahui'}', style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                          const SizedBox(height: 2),
                          Text('Waktu: ${jadwal['hari']}, ${jadwal['jam_mulai'].toString().substring(0,5)} - ${jadwal['jam_selesai'].toString().substring(0,5)}', style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Tanggal Berhalangan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 7)), lastDate: DateTime.now().add(const Duration(days: 60)));
                        if (picked != null) setStateDialog(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const Icon(Icons.calendar_month_rounded, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Pilih Guru Pengganti (Infal):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedGuruId,
                      isExpanded: true,
                      decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                      hint: const Text('Pilih Guru...'),
                      items: _guruList.map((g) => DropdownMenuItem(value: g['id'].toString(), child: Text(g['full_name'], style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedGuruId = val),
                    ),
                    const SizedBox(height: 16),

                    const Text('Keterangan / Alasan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: keteranganCtrl,
                      decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), hintText: 'Cth: Guru asli izin sakit', hintStyle: const TextStyle(fontSize: 13), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: isSubmitting ? null : () async {
                    if (selectedGuruId == null) {
                      PopupService.show(context, 'Silakan pilih guru pengganti terlebih dahulu!', isSuccess: false, judul: 'Peringatan'); return;
                    }

                    setStateDialog(() => isSubmitting = true);
                    try {
                      final tglFormat = DateFormat('yyyy-MM-dd').format(selectedDate);
                      await _supabase.from('jadwal_pengganti').insert({
                        'jadwal_id': jadwal['id'],
                        'tanggal': tglFormat,
                        'guru_pengganti_id': selectedGuruId,
                        'keterangan': keteranganCtrl.text.trim().isEmpty ? '-' : keteranganCtrl.text.trim(),
                      });

                      if (!mounted) return;
                      Navigator.pop(context);
                      _fetchData();
                      PopupService.show(context, 'Guru pengganti berhasil ditetapkan untuk tanggal tersebut!', isSuccess: true, judul: 'Berhasil');
                    } catch (e) {
                      setStateDialog(() => isSubmitting = false);
                      if (e.toString().contains('unique') || e.toString().contains('duplicate') || e.toString().contains('23505')) {
                        PopupService.show(context, 'Jadwal ini sudah memiliki guru pengganti pada tanggal tersebut!', isSuccess: false, judul: 'Bentrok Jadwal');
                      } else {
                        PopupService.show(context, 'Gagal menyimpan: $e', isSuccess: false, judul: 'Error');
                      }
                    }
                  },
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Tetapkan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _batalkanPengganti(String idPengganti) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pengganti?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin membatalkan guru pengganti ini? Jadwal akan otomatis kembali normal ke guru asli pada tanggal tersebut.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _supabase.from('jadwal_pengganti').delete().eq('id', idPengganti);
                _fetchData();
                if (mounted) PopupService.show(context, 'Jadwal pengganti berhasil dibatalkan.', isSuccess: true);
              } catch (e) {
                if (mounted) PopupService.show(context, 'Gagal membatalkan: $e', isSuccess: false);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredJadwal = _jadwalList.where((j) {
      bool mHari = j['hari'].toString().toLowerCase() == _selectedHari.toLowerCase();
      bool mKelas = _selectedKelas == 'Semua Kelas' || j['kelas'].toString().trim() == _selectedKelas;
      return mHari && mKelas;
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Manajemen Guru Pengganti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          backgroundColor: const Color(0xFF1E40AF),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.amber, indicatorWeight: 3, isScrollable: true, tabAlignment: TabAlignment.center,
            tabs: [
              Tab(icon: Icon(Icons.assignment_ind_rounded), text: 'Penugasan Baru'),
              Tab(icon: Icon(Icons.notifications_active_rounded), text: 'Daftar Aktif'),
              Tab(icon: Icon(Icons.history_rounded), text: 'Histori Selesai'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)))
            : TabBarView(
                children: [
                  // =================== TAB 1: PENUGASAN BARU ===================
                  Column(
                    children: [
                      Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), color: Colors.blue.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade900), const SizedBox(width: 8),
                            Text('Hanya menampilkan jadwal: $_infoSemesterAktif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16), color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedHari,
                                decoration: InputDecoration(labelText: 'Pilih Hari', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                items: _daftarHari.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                                onChanged: (v) => setState(() => _selectedHari = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedKelas,
                                decoration: InputDecoration(labelText: 'Pilih Kelas', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                items: _daftarKelas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                                onChanged: (v) => setState(() => _selectedKelas = v!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Expanded(
                        child: filteredJadwal.isEmpty
                            ? const Center(child: Text('Tidak ada jadwal pada hari & kelas ini.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredJadwal.length,
                                itemBuilder: (context, index) {
                                  final j = filteredJadwal[index];
                                  final guruAsli = _mapNamaGuru[j['guru_id'].toString()] ?? j['guru_pengampu'] ?? 'Belum Diatur';

                                  return Card(
                                    elevation: 0, margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(child: Text(j['mata_pelajaran'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)))),
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Text('Kelas ${j['kelas']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900))),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.grey), const SizedBox(width: 6),
                                              Text('${j['jam_mulai'].toString().substring(0,5)} - ${j['jam_selesai'].toString().substring(0,5)} WIB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.person, size: 14, color: Colors.grey), const SizedBox(width: 6),
                                              Text('Guru Asli: $guruAsli', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade50, foregroundColor: Colors.orange.shade900, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.orange.shade200))),
                                              onPressed: () => _bukaDialogSetPengganti(j),
                                              icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                              label: const Text('Tugaskan Guru Pengganti', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // =================== TAB 2: DAFTAR AKTIF (HARI INI / MENDATANG) ===================
                  _buildListPengganti(_penggantiListAktif, isHistoriTab: false),

                  // =================== TAB 3: HISTORI SELESAI ===================
                  _buildListPengganti(_penggantiListHistori, isHistoriTab: true),
                ],
              ),
      ),
    );
  }

  Widget _buildListPengganti(List<Map<String, dynamic>> dataList, {required bool isHistoriTab}) {
    if (dataList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isHistoriTab ? Icons.history_edu_rounded : Icons.notifications_none_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isHistoriTab ? 'Belum ada riwayat guru pengganti yang selesai.' : 'Tidak ada penugasan guru pengganti aktif.', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final p = dataList[index];
        final targetJadwal = _jadwalList.firstWhere((j) => j['id'].toString() == p['jadwal_id'].toString(), orElse: () => {});
        
        if (targetJadwal.isEmpty) return const SizedBox.shrink(); 
        
        final tglOverride = DateFormat('dd MMM yyyy').format(DateTime.parse(p['tanggal']));
        final guruPengganti = _mapNamaGuru[p['guru_pengganti_id'].toString()] ?? '-';
        final guruAsli = _mapNamaGuru[targetJadwal['guru_id'].toString()] ?? targetJadwal['guru_pengampu'] ?? '-';

        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isHistoriTab ? Colors.grey.shade300 : Colors.green.shade300, width: 1.5)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(8)), child: Text(tglOverride, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))),
                    if (isHistoriTab)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)), child: const Text('SELESAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)))
                    else
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)), child: Text('AKTIF TUGAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.green.shade700))),
                  ],
                ),
                const SizedBox(height: 16),
                Text('${targetJadwal['mata_pelajaran']} (Kelas ${targetJadwal['kelas']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Guru Asli:', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(guruAsli, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 18)),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Guru Pengganti:', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(guruPengganti, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 16, color: Colors.grey), const SizedBox(width: 6),
                    Expanded(child: Text('Keterangan: ${p['keterangan']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey))),
                  ],
                ),
                
                if (!isHistoriTab) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _batalkanPengganti(p['id'].toString()),
                      icon: const Icon(Icons.cancel_rounded, size: 20),
                      label: const Text('Batalkan Penugasan Ini', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}