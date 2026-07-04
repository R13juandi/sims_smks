import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAdministrasiScreen extends StatefulWidget {
  const AdminAdministrasiScreen({super.key});

  @override
  State<AdminAdministrasiScreen> createState() => _AdminAdministrasiScreenState();
}

class _AdminAdministrasiScreenState extends State<AdminAdministrasiScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _listSiswa = [];
  List<Map<String, dynamic>> _filteredSiswa = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDaftarSiswa();
  }

  Future<void> _fetchDaftarSiswa() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, nisn, kelas')
          .eq('role', 'siswa')
          .order('kelas', ascending: true)
          .order('full_name', ascending: true);

      setState(() {
        _listSiswa = List<Map<String, dynamic>>.from(res);
        _filteredSiswa = _listSiswa;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterPencarian(String query) {
    if (query.isEmpty) {
      setState(() => _filteredSiswa = _listSiswa);
      return;
    }
    setState(() {
      _filteredSiswa = _listSiswa.where((siswa) {
        final nama = (siswa['full_name'] ?? '').toLowerCase();
        final kelas = (siswa['kelas'] ?? '').toLowerCase();
        final nisn = (siswa['nisn'] ?? '').toLowerCase();
        return nama.contains(query.toLowerCase()) || kelas.contains(query.toLowerCase()) || nisn.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showFormInputPembayaran(Map<String, dynamic> siswa) {
    final _formKey = GlobalKey<FormState>();
    final _nominalController = TextEditingController();
    final _keteranganController = TextEditingController();
    
    String _jenisSelected = 'SPP Bulanan';
    String? _bulanSelected = 'Juli';

    final List<String> jenisPembayaran = ['SPP Bulanan', 'Daftar Ulang', 'PTS-1', 'PAS-1', 'PTS-2', 'PAS-2', 'LKS', 'Seragam', 'Kegiatan PKL', 'Lainnya'];
    final List<String> bulan = ['Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Input Pembayaran: ${siswa['full_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    Text('Kelas: ${siswa['kelas']} | NISN: ${siswa['nisn']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      value: _jenisSelected,
                      decoration: const InputDecoration(labelText: 'Jenis Pembayaran', border: OutlineInputBorder()),
                      items: jenisPembayaran.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          _jenisSelected = val!;
                          if (_jenisSelected != 'SPP Bulanan') _bulanSelected = null;
                          if (_jenisSelected == 'SPP Bulanan') _bulanSelected = 'Juli';
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_jenisSelected == 'SPP Bulanan') ...[
                      DropdownButtonFormField<String>(
                        value: _bulanSelected,
                        decoration: const InputDecoration(labelText: 'Bulan Tagihan', border: OutlineInputBorder()),
                        items: bulan.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setModalState(() => _bulanSelected = val),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Nominal Rupiah (Rp)', border: OutlineInputBorder(), hintText: 'Contoh: 250000', prefixText: 'Rp '),
                      validator: (val) => val == null || val.isEmpty ? 'Nominal wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _keteranganController,
                      decoration: const InputDecoration(labelText: 'Keterangan Tambahan (Opsional)', border: OutlineInputBorder(), hintText: 'Cth: Lunas / Cicil 1'),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(context); 
                            _prosesSimpanPembayaran(siswa['id'], _jenisSelected, _bulanSelected, _nominalController.text, _keteranganController.text);
                          }
                        },
                        child: const Text('SIMPAN TRANSAKSI', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _prosesSimpanPembayaran(String siswaId, String jenis, String? bulan, String nominalStr, String keterangan) async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      final tuProfile = await _supabase.from('profiles').select('full_name').eq('id', user!.id).single();
      
      final tanggalNow = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());

      await _supabase.from('pembayaran').insert({
        'siswa_id': siswaId,
        'tanggal_bayar': tanggalNow,
        'jenis_pembayaran': jenis,
        'bulan_tagihan': bulan,
        'nominal': int.parse(nominalStr.replaceAll(RegExp(r'[^0-9]'), '')),
        'keterangan': keterangan,
        'penerima': tuProfile['full_name'] ?? 'Staff TU',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi pembayaran berhasil disimpan.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan transaksi: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Administrasi & Keuangan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0.5,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau kelas siswa...', prefixIcon: const Icon(Icons.search_rounded),
                filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _filterPencarian,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSiswa.length,
                    itemBuilder: (context, index) {
                      final s = _filteredSiswa[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2FE), child: Icon(Icons.person, color: Color(0xFF0284C7))),
                          title: Text(s['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text('Kelas: ${s['kelas']} | NISN: ${s['nisn']}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            onPressed: () => _showFormInputPembayaran(s),
                            child: const Text('Input Bayar'),
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