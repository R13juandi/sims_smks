import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  String _namaGuruPengampu = '';
  Map<String, dynamic>? _selectedJadwal;

  List<Map<String, dynamic>> _jadwalHariIni = [];
  List<Map<String, dynamic>> _listSiswa = [];

  final Map<String, String> _statusAbsensi = {};
  final Map<String, TextEditingController> _keteranganControllers = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String _getNamaHariIni() {
    final now = DateTime.now();
    switch (now.weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      default:
        return 'Minggu';
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();
      _namaGuruPengampu = profile['full_name'].toString().trim();

      String hariIni = _getNamaHariIni();

      final jadwal = await _supabase
          .from('jadwal')
          .select('*')
          .ilike('guru_pengampu', '%$_namaGuruPengampu%')
          .eq('hari', hariIni)
          .order('jam_mulai', ascending: true);

      setState(() {
        _jadwalHariIni = List<Map<String, dynamic>>.from(jadwal);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error load data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _panggilDaftarSiswa(Map<String, dynamic> jadwal) async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, nisn')
          .eq('role', 'siswa')
          .eq('kelas', jadwal['kelas'])
          .order('full_name', ascending: true);

      _listSiswa = List<Map<String, dynamic>>.from(res);

      _statusAbsensi.clear();
      _keteranganControllers.clear();
      for (var s in _listSiswa) {
        String sId = s['id'].toString();
        _statusAbsensi[sId] = 'Hadir';
        _keteranganControllers[sId] = TextEditingController();
      }

      setState(() {
        _selectedJadwal = jadwal;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error Fetch Siswa: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simpanAbsensiKeCloud() async {
    if (_selectedJadwal == null || _listSiswa.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final String tanggalFormat = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
      List<Map<String, dynamic>> dataInsertBatch = [];

      for (var s in _listSiswa) {
        String sId = s['id'].toString();
        String statusSaatIni = _statusAbsensi[sId] ?? 'Hadir';
        String catatanInput = _keteranganControllers[sId]!.text.trim();

        String keteranganFix = statusSaatIni == 'Izin'
            ? (catatanInput.isEmpty ? 'Izin (Tanpa Ket)' : catatanInput)
            : 'Hadir Tepat Waktu';

        String dbStatusKode = 'H';
        if (statusSaatIni == 'Izin') dbStatusKode = 'I';
        if (statusSaatIni == 'Alfa') dbStatusKode = 'A';

        dataInsertBatch.add({
          'siswa_id': sId,
          'tanggal': tanggalFormat,
          'mapel': _selectedJadwal!['mata_pelajaran'],
          'status': dbStatusKode,
          'keterangan': keteranganFix,
          'kelas': _selectedJadwal!['kelas'],
          'guru_pengampu': _namaGuruPengampu,
        });
      }

      await _supabase
          .from('absensi')
          .upsert(dataInsertBatch, onConflict: 'siswa_id, tanggal, mapel');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selesai! Absensi kelas hari ini berhasil dikunci dan diunggah.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan absensi: $e'),
          backgroundColor: Colors.red,
        ),
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
          'Input Absensi Harian',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedJadwal == null
          ? _buildPilihJadwal()
          : _buildFormAbsensi(),
    );
  }

  Widget _buildPilihJadwal() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, color: Color(0xFF1E40AF)),
            const SizedBox(width: 8),
            Text(
              'Jadwal Anda Hari Ini (${_getNamaHariIni()})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E40AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _jadwalHariIni.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Anda tidak memiliki jadwal mengajar di hari ini, atau jadwal belum dibuat oleh Admin.',
                  style: TextStyle(color: Colors.grey, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                children: _jadwalHariIni
                    .map(
                      (j) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.blue.shade100),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(Icons.class_, color: Color(0xFF1E40AF)),
                          ),
                          title: Text(
                            '${j['mata_pelajaran']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Kelas ${j['kelas']} | Pukul: ${j['jam_mulai']} - ${j['jam_selesai']}',
                          ),
                          trailing: const Icon(
                            Icons.how_to_reg,
                            color: Colors.blue,
                          ),
                          onTap: () => _panggilDaftarSiswa(j),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildFormAbsensi() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Form Absensi: Kelas ${_selectedJadwal!['kelas']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mata Pelajaran: ${_selectedJadwal!['mata_pelajaran']}',
                style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _listSiswa.length,
            itemBuilder: (context, index) {
              final s = _listSiswa[index];
              final sId = s['id'].toString();
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['full_name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'NISN: ${s['nisn'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['Hadir', 'Izin', 'Alfa']
                            .map(
                              (st) => Row(
                                children: [
                                  Radio(
                                    value: st,
                                    groupValue: _statusAbsensi[sId],
                                    activeColor: st == 'Hadir'
                                        ? Colors.green
                                        : (st == 'Izin'
                                              ? Colors.orange
                                              : Colors.red),
                                    onChanged: (v) => setState(
                                      () => _statusAbsensi[sId] = v!,
                                    ),
                                  ),
                                  Text(
                                    st,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                      if (_statusAbsensi[sId] == 'Izin')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextField(
                            controller: _keteranganControllers[sId],
                            decoration: const InputDecoration(
                              hintText:
                                  'Masukkan alasan izin (Sakit/Surat Dokter/dll)...',
                              hintStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _simpanAbsensiKeCloud,
            child: const Text(
              'KUNCI & SIMPAN ABSENSI HARI INI',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}
