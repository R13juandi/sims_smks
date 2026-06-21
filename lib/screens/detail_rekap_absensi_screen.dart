import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class DetailRekapAbsensiScreen extends StatefulWidget {
  final String siswaId;
  final String namaSiswa;

  const DetailRekapAbsensiScreen({
    super.key,
    required this.siswaId,
    required this.namaSiswa,
  });

  @override
  State<DetailRekapAbsensiScreen> createState() => _DetailRekapAbsensiScreenState();
}

class _DetailRekapAbsensiScreenState extends State<DetailRekapAbsensiScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listAbsen = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAbsenSiswa();
  }

  Future<void> _fetchAbsenSiswa() async {
    try {
      final response = await _supabase
          .from('absensi')
          .select('*')
          .eq('siswa_id', widget.siswaId)
          .order('tanggal', ascending: false);

      setState(() {
        _listAbsen = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data: $e')),
      );
    }
  }

  Future<void> _downloadPdf() async {
    final pdf = pw.Document();
    final image = await imageFromAssetBundle('assets/ttd_stempel.png');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "SMK Islam Al Ayaniah",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text("Laporan Riwayat Absensi Siswa"),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text("Nama Siswa: ${widget.namaSiswa}"),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                data: <List<String>>[
                  <String>['Tanggal', 'Status', 'Keterangan'],
                  ..._listAbsen.map((item) {
                    return <String>[
                      item['tanggal'].toString(),
                      item['status'].toString(),
                      item['keterangan']?.toString() ?? '-',
                    ];
                  }),
                ],
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text("Kepala Sekolah SMK Islam Al-Ayaniah"),
                      pw.SizedBox(height: 5),
                      pw.Image(image, width: 100, height: 100),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        "Agus Rahmadani, SE",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Riwayat Absensi: ${widget.namaSiswa}"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Unduh PDF",
            onPressed: _listAbsen.isEmpty ? null : _downloadPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listAbsen.isEmpty
              ? const Center(
                  child: Text("Tidak ada riwayat absensi untuk siswa ini."),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listAbsen.length,
                  itemBuilder: (context, index) {
                    final data = _listAbsen[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: data['status'] == 'HADIR'
                              ? Colors.green[100]
                              : Colors.orange[100],
                          child: Icon(
                            data['status'] == 'HADIR'
                                ? Icons.person
                                : Icons.person_off,
                            color: data['status'] == 'HADIR'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        title: Text(data['tanggal'] ?? ''),
                        subtitle: Text(
                            "Status: ${data['status']} | Keterangan: ${data['keterangan'] ?? '-'}"),
                      ),
                    );
                  },
                ),
    );
  }
}