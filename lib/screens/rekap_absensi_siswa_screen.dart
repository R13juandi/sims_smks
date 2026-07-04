import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RekapAbsensiSiswaScreen extends StatefulWidget {
  const RekapAbsensiSiswaScreen({super.key});

  @override
  State<RekapAbsensiSiswaScreen> createState() => _RekapAbsensiSiswaScreenState();
}

class _RekapAbsensiSiswaScreenState extends State<RekapAbsensiSiswaScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  String _selectedSemester = 'Semester 1 (Ganjil)';
  final List<String> _listSemester = ['Semester 1 (Ganjil)', 'Semester 2 (Genap)'];

  List<Map<String, dynamic>> _semuaAbsen = [];
  List<Map<String, dynamic>> _absenDitampilkan = [];

  @override
  void initState() {
    super.initState();
    _fetchDataAbsensiSiswa();
  }

  Future<void> _fetchDataAbsensiSiswa() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final res = await _supabase.from('absensi').select('*').eq('siswa_id', user.id).order('tanggal', ascending: false);
      _semuaAbsen = List<Map<String, dynamic>>.from(res);
      _filterBerdasarkanSemester(); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat rekap absensi: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterBerdasarkanSemester() {
    _absenDitampilkan.clear();
    for (var absen in _semuaAbsen) {
      if (absen['tanggal'] != null) {
        DateTime dateParsed = DateTime.parse(absen['tanggal'].toString());
        bool isGanjil = dateParsed.month >= 7 && dateParsed.month <= 12;
        if (_selectedSemester == 'Semester 1 (Ganjil)' && isGanjil) {
          _absenDitampilkan.add(absen);
        } else if (_selectedSemester == 'Semester 2 (Genap)' && !isGanjil) {
          _absenDitampilkan.add(absen);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rekap Absensi Saya', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1))),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, color: Color(0xFF1E40AF)),
                const SizedBox(width: 12),
                const Text("Pilih Semester: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSemester, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        items: _listSemester.map((String semester) {
                          return DropdownMenuItem<String>(value: semester, child: Text(semester, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)));
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() { _selectedSemester = newValue; _filterBerdasarkanSemester(); });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _absenDitampilkan.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('Belum ada data absensi tercatat di $_selectedSemester.', style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5), textAlign: TextAlign.center)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blue.shade50), columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                              DataColumn(label: Text('Jam', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                              DataColumn(label: Text('Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                              DataColumn(label: Text('Verifikasi Guru', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)))),
                            ],
                            rows: _absenDitampilkan.map((item) {
                              String tanggalTampil = item['tanggal'] ?? '-';
                              if (item['tanggal'] != null) {
                                try {
                                  DateTime dt = DateTime.parse(item['tanggal'].toString());
                                  tanggalTampil = DateFormat('dd MMM yyyy').format(dt);
                                } catch (_) {}
                              }
                              final String jamTampil = item['waktu_absen'] ?? '-';
                              final String statusKode = item['status']?.toString() ?? 'H';
                              String textStatus = 'Hadir'; Color warnaStatus = Colors.green;
                              if (statusKode == 'I') { textStatus = 'Izin / Sakit'; warnaStatus = Colors.orange; } else if (statusKode == 'A') { textStatus = 'Alfa'; warnaStatus = Colors.red; } else if (statusKode == 'T') { textStatus = 'Terlambat'; warnaStatus = Colors.amber.shade700; }
                              
                              String verifikasi = item['status_verifikasi'] ?? 'Disetujui';
                              Color verifikasiColor = verifikasi == 'Pending' ? Colors.orange.shade700 : Colors.green;
                              
                              return DataRow(
                                cells: [
                                  DataCell(Text(tanggalTampil, style: const TextStyle(fontSize: 13))),
                                  DataCell(Text(jamTampil, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                                  DataCell(Text(item['mapel'] ?? 'Mata Pelajaran', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                  DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: warnaStatus.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(textStatus, style: TextStyle(color: warnaStatus, fontWeight: FontWeight.bold, fontSize: 12)))),
                                  DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: verifikasiColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(verifikasi, style: TextStyle(color: verifikasiColor, fontWeight: FontWeight.bold, fontSize: 12)))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}