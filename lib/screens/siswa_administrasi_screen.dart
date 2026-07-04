import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SiswaAdministrasiScreen extends StatefulWidget {
  final String siswaId;
  const SiswaAdministrasiScreen({super.key, required this.siswaId});

  @override
  State<SiswaAdministrasiScreen> createState() => _SiswaAdministrasiScreenState();
}

class _SiswaAdministrasiScreenState extends State<SiswaAdministrasiScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _riwayatPembayaran = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchRiwayatPembayaran();
  }

  Future<void> _fetchRiwayatPembayaran() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('pembayaran')
          .select('*')
          .eq('siswa_id', widget.siswaId)
          .order('created_at', ascending: false);

      setState(() {
        _riwayatPembayaran = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Administrasi & SPP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                // BANNER INFORMASI
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle), child: Icon(Icons.check_circle_rounded, color: Colors.teal.shade600, size: 28)),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Riwayat Pembayaran Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            SizedBox(height: 4),
                            Text('Data di bawah ini adalah bukti sah pembayaran yang telah diverifikasi oleh bagian Tata Usaha.', style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // TABEL RIWAYAT TRANSAKSI
                Expanded(
                  child: _riwayatPembayaran.isEmpty
                      ? const Center(child: Text("Belum ada riwayat transaksi pembayaran.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _riwayatPembayaran.length,
                          itemBuilder: (context, index) {
                            final trx = _riwayatPembayaran[index];
                            final nominalInt = int.tryParse(trx['nominal'].toString()) ?? 0;
                            final bulanTagihan = trx['bulan_tagihan'] != null && trx['bulan_tagihan'].toString().isNotEmpty ? ' (${trx['bulan_tagihan']})' : '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                                          child: Text(trx['jenis_pembayaran'] + bulanTagihan, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700, fontSize: 12)),
                                        ),
                                        Text(trx['tanggal_bayar'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Nominal Dibayar:', style: TextStyle(fontSize: 13, color: Colors.black54)),
                                        Text(_currencyFormat.format(nominalInt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Penerima (TU): ${trx['penerima']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                    if (trx['keterangan'] != null && trx['keterangan'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Keterangan: ${trx['keterangan']}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                                    ]
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