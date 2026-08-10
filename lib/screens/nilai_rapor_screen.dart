import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/popup_service.dart';

class NilaiRaporScreen extends StatefulWidget {
  final String siswaId;
  final String? initialSemester;
  final String? initialTahunAjaran;

  const NilaiRaporScreen({
    super.key,
    required this.siswaId,
    this.initialSemester,
    this.initialTahunAjaran,
  });

  @override
  State<NilaiRaporScreen> createState() => _NilaiRaporScreenState();
}

class _NilaiRaporScreenState extends State<NilaiRaporScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  Map<String, dynamic> _biodata = {};
  List<Map<String, dynamic>> _rekapMapel = [];

  // 🔥 Filter Histori Rapor
  String _selectedSmt = 'Ganjil';
  String _selectedTa = '';
  final List<String> _listTahunAjaran = ['2024/2025', '2025/2026', '2026/2027', '2027/2028'];

  @override
  void initState() {
    super.initState();
    
    // Otomatis deteksi semester atau gunakan parameter dari Admin Dashboard
    DateTime now = DateTime.now();
    int currentYear = now.month >= 7 ? now.year : now.year - 1;
    
    _selectedTa = widget.initialTahunAjaran ?? '$currentYear/${currentYear + 1}';
    _selectedSmt = widget.initialSemester ?? (now.month >= 7 ? 'Ganjil' : 'Genap');

    _fetchDataRapor();
  }

  Future<void> _fetchDataRapor() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil Biodata Siswa
      final resProfile = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', widget.siswaId)
          .maybeSingle();
      
      _biodata = resProfile ?? {};

      // 2. Ambil Nilai berdasarkan Filter Histori
      String smtDb = _selectedSmt == 'Ganjil' ? 'Semester 1 (Ganjil)' : 'Semester 2 (Genap)';
      final resNilai = await _supabase
          .from('nilai')
          .select('*')
          .eq('siswa_id', widget.siswaId)
          .eq('semester', smtDb)
          .eq('tahun_ajaran', _selectedTa);

      // 3. Kelompokkan Nilai per Mata Pelajaran & Hitung Rata-rata
      Map<String, Map<String, double>> grouped = {};
      
      for(var n in resNilai) {
         String mapel = (n['mapel'] ?? n['mata_pelajaran'] ?? 'Tidak Diketahui').toString();
         String kat = (n['kategori'] ?? '').toString().toLowerCase();
         double val = double.tryParse(n['nilai'].toString()) ?? 0.0;
         
         if(!grouped.containsKey(mapel)) {
            grouped[mapel] = {
              'harian': 0, 'tugas': 0, 'praktek': 0, 'pts': 0, 'pas': 0, 
              'count_harian': 0, 'count_tugas': 0
            };
         }
         
         if (kat.contains('harian') || kat.contains('ulangan')) { 
           grouped[mapel]!['harian'] = grouped[mapel]!['harian']! + val; 
           grouped[mapel]!['count_harian'] = grouped[mapel]!['count_harian']! + 1; 
         }
         else if (kat.contains('tugas')) { 
           grouped[mapel]!['tugas'] = grouped[mapel]!['tugas']! + val; 
           grouped[mapel]!['count_tugas'] = grouped[mapel]!['count_tugas']! + 1; 
         }
         else if (kat.contains('praktek')) { 
           grouped[mapel]!['praktek'] = val; 
         }
         else if (kat.contains('pts') || kat.contains('uts')) { 
           grouped[mapel]!['pts'] = val; 
         }
         else if (kat.contains('pas') || kat.contains('uas')) { 
           grouped[mapel]!['pas'] = val; 
         }
      }

      List<Map<String, dynamic>> finalRekap = [];
      grouped.forEach((mapel, data) {
         double avgHarian = data['count_harian']! > 0 ? data['harian']! / data['count_harian']! : 0;
         double avgTugas = data['count_tugas']! > 0 ? data['tugas']! / data['count_tugas']! : 0;
         
         double rataHarianTugas = (avgHarian + avgTugas) / ((avgHarian > 0 && avgTugas > 0) ? 2 : 1);
         if(avgHarian == 0 && avgTugas == 0) rataHarianTugas = 0;

         double praktek = data['praktek']!;
         double pts = data['pts']!;
         double pas = data['pas']!;

         // 🔥 FORMULA NILAI AKHIR (30% Harian, 20% Praktek, 20% PTS, 30% PAS)
         double akhir = (rataHarianTugas * 0.3) + (praktek * 0.2) + (pts * 0.2) + (pas * 0.3);
         
         String mutu = 'D';
         if(akhir >= 90) mutu = 'A';
         else if(akhir >= 80) mutu = 'B';
         else if(akhir >= 70) mutu = 'C';

         finalRekap.add({
            'mapel': mapel,
            'rata_harian': rataHarianTugas,
            'praktek': praktek,
            'pts': pts,
            'pas': pas,
            'akhir': akhir,
            'mutu': mutu
         });
      });

      // Urutkan abjad mata pelajaran
      finalRekap.sort((a, b) => a['mapel'].toString().compareTo(b['mapel'].toString()));

      if (mounted) {
        setState(() {
          _rekapMapel = finalRekap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupService.show(context, 'Gagal memuat e-Rapor: $e', isSuccess: false);
      }
    }
  }

  Color _getMutuColor(String mutu) {
    switch (mutu) {
      case 'A': return Colors.green.shade700;
      case 'B': return Colors.blue.shade700;
      case 'C': return Colors.orange.shade700;
      default: return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    String fotoProfil = _biodata['foto_profil'] ?? '';
    String nama = _biodata['full_name'] ?? 'Siswa Tidak Diketahui';
    String nisn = _biodata['nisn'] ?? '-';
    String kelas = _biodata['kelas'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('E-Rapor Siswa', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // 🔥 HEADER PROFIL SISWA
          Container(
            padding: const EdgeInsets.all(20), width: double.infinity, decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))), 
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30, backgroundColor: const Color(0xFFE6FFFA), 
                  backgroundImage: fotoProfil.isNotEmpty ? NetworkImage(fotoProfil) : null, 
                  child: fotoProfil.isEmpty ? const Icon(Icons.person, color: Colors.teal, size: 30) : null
                ), 
                const SizedBox(width: 16), 
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(nama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), 
                      const SizedBox(height: 4), 
                      Text('NISN: $nisn | Kelas: $kelas', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500))
                    ]
                  )
                )
              ]
            )
          ),
          
          // 🔥 FILTER HISTORI SEMESTER
          Container(
            padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              children: [
                Expanded(
                  flex: 1, 
                  child: DropdownButtonFormField<String>(
                    value: _selectedSmt, 
                    decoration: InputDecoration(labelText: 'Semester', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), 
                    items: ['Ganjil', 'Genap'].map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(), 
                    onChanged: (val) { if (val != null) { setState(() => _selectedSmt = val); _fetchDataRapor(); } }
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1, 
                  child: DropdownButtonFormField<String>(
                    value: _selectedTa, 
                    decoration: InputDecoration(labelText: 'Tahun Ajaran', filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), 
                    items: _listTahunAjaran.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(), 
                    onChanged: (val) { if (val != null) { setState(() => _selectedTa = val); _fetchDataRapor(); } }
                  )
                ),
              ],
            ),
          ),

          // 🔥 DAFTAR NILAI MAPEL
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF))) 
              : _rekapMapel.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_late_rounded, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Belum ada nilai yang diinputkan\npada periode $_selectedSmt $_selectedTa.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.5)),
                      ],
                    ),
                  ) 
                : ListView.builder(
                    padding: const EdgeInsets.all(20), 
                    itemCount: _rekapMapel.length,
                    itemBuilder: (context, index) {
                      final n = _rekapMapel[index];
                      final mapel = n['mapel'];
                      final rataHarian = (n['rata_harian'] as double).toStringAsFixed(1);
                      final praktek = (n['praktek'] as double).toStringAsFixed(1);
                      final pts = (n['pts'] as double).toStringAsFixed(1);
                      final pas = (n['pas'] as double).toStringAsFixed(1);
                      final akhir = (n['akhir'] as double).toStringAsFixed(1);
                      final mutu = n['mutu'];
                      final warnaMutu = _getMutuColor(mutu);

                      return Card(
                        elevation: 0, margin: const EdgeInsets.only(bottom: 16), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(mapel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                                    decoration: BoxDecoration(color: warnaMutu.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: warnaMutu.withOpacity(0.5))), 
                                    child: Text('Predikat $mutu', style: TextStyle(fontWeight: FontWeight.bold, color: warnaMutu, fontSize: 11))
                                  )
                                ],
                              ),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildKomponenNilai('Harian/Tugas', rataHarian),
                                  _buildKomponenNilai('Praktek', praktek),
                                  _buildKomponenNilai('PTS', pts),
                                  _buildKomponenNilai('PAS', pas),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(16), 
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)), 
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('NILAI AKHIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900)),
                                    Text(akhir, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blue.shade900)),
                                  ],
                                )
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      )
    );
  }

  Widget _buildKomponenNilai(String label, String nilai) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 4),
        Text(nilai, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
      ],
    );
  }
}