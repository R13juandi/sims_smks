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
  final List<String> _hariList = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
  Map<String, List<String>> _dynamicGuruMapel = {};

  @override
  void initState() {
    super.initState();
    _fetchGurus();
    _fetchJadwal();
  }

  Future<void> _fetchGurus() async {
    try {
      final response = await _supabase.from('profiles').select('full_name, role, mapel, mata_pelajaran');
      List<String> daftarGuru = [];
      Map<String, List<String>> tempGuruMapel = {};

      for (var user in response) {
        if (user['role'] != null && user['role'].toString().toLowerCase() == 'guru') {
          if (user['full_name'] != null) {
            String namaGuru = user['full_name'].toString();
            daftarGuru.add(namaGuru);
            List<String> mapelDiampu = [];
            var dataMapel = user['mapel'] ?? user['mata_pelajaran'];
            if (dataMapel != null) {
              if (dataMapel is List) { mapelDiampu = List<String>.from(dataMapel); } 
              else if (dataMapel is String) { mapelDiampu = dataMapel.split(',').map((e) => e.trim()).toList(); }
            }
            tempGuruMapel[namaGuru] = mapelDiampu;
          }
        }
      }
      daftarGuru.sort((a, b) => a.compareTo(b));
      if (mounted) setState(() { _guruList = daftarGuru; _dynamicGuruMapel = tempGuruMapel; });
    } catch (e) {
      _showSnackBar('Gagal memuat daftar guru', Colors.red);
    }
  }

  Future<void> _fetchJadwal() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('jadwal').select().order('jam_mulai', ascending: true);
      if (mounted) setState(() => _jadwalList = data);
    } catch (e) {
      _showSnackBar('Gagal memuat jadwal', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFormDialog({Map<String, dynamic>? jadwal}) {
    final isEdit = jadwal != null;

    String? selectedHari = isEdit ? jadwal['hari'] : null;
    String? selectedKelas = isEdit ? jadwal['kelas'] : null;
    String? selectedGuru = isEdit ? jadwal['guru_pengampu'] : null;
    String? selectedMapel = isEdit ? jadwal['mata_pelajaran'] : null;
    
    // 🔥 DETEKSI APAKAH INI JAM ISTIRAHAT (Termasuk 2x Istirahat)
    bool isIstirahat = isEdit && (selectedMapel?.toLowerCase().contains('istirahat') ?? false) || (selectedMapel?.toLowerCase().contains('ishoma') ?? false);
    String typeIstirahat = isIstirahat ? (selectedMapel ?? 'Istirahat 1') : 'Istirahat 1';

    List<String> currentMapelList = [];
    if (selectedGuru != null && selectedGuru != '-') currentMapelList = List.from(_dynamicGuruMapel[selectedGuru] ?? []);

    if (isEdit) {
      if (selectedKelas != null && !_kelasList.contains(selectedKelas)) _kelasList.add(selectedKelas!);
      if (selectedGuru != null && selectedGuru != '-' && !_guruList.contains(selectedGuru)) _guruList.add(selectedGuru!);
      if (selectedMapel != null && !isIstirahat && !currentMapelList.contains(selectedMapel)) currentMapelList.add(selectedMapel!);
    }

    TimeOfDay? jamMulai = isEdit && jadwal['jam_mulai'] != null ? TimeOfDay(hour: int.parse(jadwal['jam_mulai'].split(':')[0]), minute: int.parse(jadwal['jam_mulai'].split(':')[1])) : null;
    TimeOfDay? jamSelesai = isEdit && jadwal['jam_selesai'] != null ? TimeOfDay(hour: int.parse(jadwal['jam_selesai'].split(':')[0]), minute: int.parse(jadwal['jam_selesai'].split(':')[1])) : null;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? 'Edit Jadwal' : 'Tambah Jadwal Baru', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 TOGGLE KHUSUS ISTIRAHAT
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isIstirahat ? Colors.orange.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: isIstirahat ? Colors.orange : Colors.grey.shade300)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [Icon(Icons.fastfood, color: isIstirahat ? Colors.orange : Colors.grey, size: 18), const SizedBox(width: 8), Text('Ini Jam Istirahat?', style: TextStyle(fontWeight: FontWeight.bold, color: isIstirahat ? Colors.orange.shade900 : Colors.grey.shade700))]),
                          Switch(
                            value: isIstirahat, activeColor: Colors.orange,
                            onChanged: (val) {
                              setDialogState(() {
                                isIstirahat = val;
                                if (val) { selectedGuru = '-'; selectedMapel = typeIstirahat; } 
                                else { selectedGuru = null; selectedMapel = null; }
                              });
                            }
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(value: selectedHari, items: _hariList.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(), onChanged: (val) => setDialogState(() => selectedHari = val), decoration: const InputDecoration(labelText: 'Hari', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: DropdownButtonFormField<String>(value: selectedKelas, items: _kelasList.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (val) => setDialogState(() => selectedKelas = val), decoration: const InputDecoration(labelText: 'Kelas Target', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 🔥 JIKA ISTIRAHAT, TAMPILKAN 2x ISTIRAHAT & ISHOMA
                    if (isIstirahat)
                      DropdownButtonFormField<String>(
                        value: typeIstirahat, items: ['Istirahat 1', 'Istirahat 2', 'Ishoma'].map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                        onChanged: (val) => setDialogState(() { typeIstirahat = val!; selectedMapel = val; }), decoration: const InputDecoration(labelText: 'Pilih Sesi Istirahat', border: OutlineInputBorder()),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        value: selectedGuru, hint: Text(_guruList.isEmpty ? 'Tidak ada data guru' : 'Pilih Guru Pengampu'),
                        items: _guruList.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedGuru = val; selectedMapel = null; 
                            currentMapelList = (val != null && _dynamicGuruMapel.containsKey(val)) ? List.from(_dynamicGuruMapel[val]!) : [];
                          });
                        }, decoration: const InputDecoration(labelText: 'Guru Pengampu', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedMapel, hint: Text(selectedGuru == null ? 'Pilih Guru Dulu' : (currentMapelList.isEmpty ? 'Guru ini belum punya mapel' : 'Pilih Mata Pelajaran')),
                        items: (selectedGuru == null || currentMapelList.isEmpty) ? null : currentMapelList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (selectedGuru == null || currentMapelList.isEmpty) ? null : (val) => setDialogState(() => selectedMapel = val),
                        decoration: InputDecoration(labelText: 'Mata Pelajaran', border: const OutlineInputBorder(), filled: (selectedGuru == null || currentMapelList.isEmpty), fillColor: (selectedGuru == null || currentMapelList.isEmpty) ? Colors.grey.shade200 : Colors.white),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade900, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () async { final time = await showTimePicker(context: context, initialTime: jamMulai ?? const TimeOfDay(hour: 7, minute: 0)); if (time != null) setDialogState(() => jamMulai = time); }, icon: const Icon(Icons.access_time), label: Text(jamMulai == null ? 'Jam Mulai' : '${jamMulai!.hour.toString().padLeft(2, '0')}:${jamMulai!.minute.toString().padLeft(2, '0')}'))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade50, foregroundColor: Colors.orange.shade900, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: () async { final time = await showTimePicker(context: context, initialTime: jamSelesai ?? const TimeOfDay(hour: 8, minute: 30)); if (time != null) setDialogState(() => jamSelesai = time); }, icon: const Icon(Icons.access_time_filled), label: Text(jamSelesai == null ? 'Jam Selesai' : '${jamSelesai!.hour.toString().padLeft(2, '0')}:${jamSelesai!.minute.toString().padLeft(2, '0')}'))),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900),
                  onPressed: () async {
                    if (selectedHari == null || selectedKelas == null || selectedMapel == null || jamMulai == null || jamSelesai == null) {
                      _showSnackBar('Harap lengkapi semua Pilihan dan Waktu!', Colors.orange); return;
                    }
                    final formatMulai = '${jamMulai!.hour.toString().padLeft(2, '0')}:${jamMulai!.minute.toString().padLeft(2, '0')}:00';
                    final formatSelesai = '${jamSelesai!.hour.toString().padLeft(2, '0')}:${jamSelesai!.minute.toString().padLeft(2, '0')}:00';

                    try {
                      final data = {
                        'hari': selectedHari, 'kelas': selectedKelas, 'mata_pelajaran': selectedMapel, 'guru_pengampu': isIstirahat ? '-' : selectedGuru, 'jam_mulai': formatMulai, 'jam_selesai': formatSelesai,
                      };
                      if (isEdit) await _supabase.from('jadwal').update(data).eq('id', jadwal['id']);
                      else await _supabase.from('jadwal').insert(data);
                      
                      Navigator.pop(context); _fetchJadwal(); _showSnackBar('Jadwal berhasil disimpan!', Colors.green);
                    } catch (e) { _showSnackBar('Error: $e', Colors.red); }
                  },
                  child: const Text('Simpan Jadwal', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _hapusJadwal(dynamic id) async {
    try { await _supabase.from('jadwal').delete().eq('id', id); _fetchJadwal(); _showSnackBar('Jadwal berhasil dihapus', Colors.green); } 
    catch (e) { _showSnackBar('Gagal menghapus: $e', Colors.red); }
  }

  void _showSnackBar(String pesan, Color warna) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna, behavior: SnackBarBehavior.floating)); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Manajemen Jadwal Real-Time', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 1, iconTheme: const IconThemeData(color: Colors.black)),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) 
      : ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: _kelasList.length,
          itemBuilder: (context, index) {
            String kelasTujuan = _kelasList[index];
            List<dynamic> jadwalKelasIni = _jadwalList.where((j) => j['kelas'] == kelasTujuan).toList();
            if (jadwalKelasIni.isEmpty) return const SizedBox.shrink();

            return Card(
              elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text(kelasTujuan, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900)),
                leading: Icon(Icons.folder_shared_rounded, color: Colors.blue.shade700, size: 32),
                children: _hariList.map((hariTujuan) {
                  List<dynamic> jadwalHariIni = jadwalKelasIni.where((j) => j['hari'] == hariTujuan).toList();
                  if (jadwalHariIni.isEmpty) return const SizedBox.shrink();

                  return ExpansionTile(
                    title: Text(hariTujuan, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), leading: const Icon(Icons.calendar_today_rounded, color: Colors.orange), backgroundColor: Colors.grey.shade50,
                    children: jadwalHariIni.map((jadwal) {
                      final jamMulai = jadwal['jam_mulai'] != null && jadwal['jam_mulai'].toString().length >= 5 ? jadwal['jam_mulai'].toString().substring(0, 5) : '00:00';
                      final jamSelesai = jadwal['jam_selesai'] != null && jadwal['jam_selesai'].toString().length >= 5 ? jadwal['jam_selesai'].toString().substring(0, 5) : '00:00';
                      
                      // 🔥 DESAIN KHUSUS ISTIRAHAT (1, 2, atau Ishoma)
                      bool isIstirahat = jadwal['mata_pelajaran'].toString().toLowerCase().contains('istirahat') || jadwal['mata_pelajaran'].toString().toLowerCase().contains('ishoma');

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: isIstirahat ? Colors.orange.shade50 : Colors.white, border: Border(left: BorderSide(color: isIstirahat ? Colors.orange : Colors.blue.shade900, width: 4)), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 2, offset: const Offset(0, 1))]),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          title: Text('${jadwal['mata_pelajaran']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isIstirahat ? Colors.orange.shade900 : Colors.black)),
                          subtitle: isIstirahat ? Text('$jamMulai - $jamSelesai WIB', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 12)) : Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Guru: ${jadwal['guru_pengampu']}', style: TextStyle(color: Colors.grey.shade700)), const SizedBox(height: 2), Text('Waktu: $jamMulai - $jamSelesai WIB', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600))])),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _showFormDialog(jadwal: jadwal)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _hapusJadwal(jadwal['id']))]),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            );
          },
        ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade900, onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.add, color: Colors.white), label: const Text('Tambah Jadwal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}