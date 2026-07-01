import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class AbsensiSiswaScreen extends StatefulWidget {
  const AbsensiSiswaScreen({super.key});

  @override
  State<AbsensiSiswaScreen> createState() => _AbsensiSiswaScreenState();
}

class _AbsensiSiswaScreenState extends State<AbsensiSiswaScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isProcessingAbsen = false;

  Map<String, dynamic> _biodataSiswa = {};
  List<Map<String, dynamic>> _jadwalHariIni = [];
  Map<String, dynamic>? _selectedJadwal;

  String _tipeAbsen = 'Masuk'; // Default opsi absen

  // ==========================================
  // VALIDASI LAPIS 1: GEOFENCING (LOKASI)
  // Diubah ke 50.0 Meter sesuai instruksi Dosen
  // ==========================================
  final double _toleransiMeter = 50.0;
  final List<Map<String, dynamic>> _lokasiDiizinkan = [
    {'nama': 'Rumah Tomang', 'lat': -6.1595261, 'lng': 106.5820671},
    {'nama': 'Kampus Bina Sarana Global', 'lat': -6.179190, 'lng': 106.608069},
    {'nama': 'SMK Islam YIA', 'lat': -6.161616, 'lng': 106.675552},
    {'nama': 'Rumah Rajeg', 'lat': -6.116251, 'lng': 106.506694},
  ];

  // ==========================================
  // VALIDASI LAPIS 2: JADWAL & WAKTU
  // ==========================================
  bool _isWaktuValid = false;
  String _pesanValidasiWaktu = "Memeriksa jadwal...";

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadDataAwal();
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  String _getHariIni() {
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

  Future<void> _loadDataAwal() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prof = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();

      _biodataSiswa = prof;
      String kelasSiswa = prof['kelas'] ?? '';

      String hariIni = _getHariIni();
      if (hariIni == 'Sabtu' || hariIni == 'Minggu') hariIni = 'Senin';

      // PERBAIKAN: Menggunakan .ilike untuk menghindari error huruf besar/kecil dan spasi
      final jadwalRes = await _supabase
          .from('jadwal')
          .select('*')
          .ilike('kelas', '%$kelasSiswa%')
          .ilike('hari', hariIni)
          .order('jam_mulai', ascending: true);

      if (mounted) {
        setState(() {
          _jadwalHariIni = List<Map<String, dynamic>>.from(jadwalRes);
          _isLoading = false;
        });

        // Panggil validasi waktu setelah data jadwal berhasil didapatkan
        _validasiJadwalDanWaktu();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FUNGSI Memvalidasi Jam Operasional Sekolah
  void _validasiJadwalDanWaktu() {
    DateTime now = DateTime.now();
    int menitSekarang = (now.hour * 60) + now.minute;

    // Konfigurasi Jam Operasional (06:00 Pagi s/d 15:00 Sore)
    int batasMulai = (6 * 60) + 0;
    int batasSelesai = (23 * 60) + 0;

    if (_jadwalHariIni.isEmpty) {
      setState(() {
        _isWaktuValid = false;
        _pesanValidasiWaktu =
            "Tombol Terkunci: Hari ini tidak ada jadwal pelajaran Anda.";
      });
    } else if (menitSekarang < batasMulai || menitSekarang > batasSelesai) {
      setState(() {
        _isWaktuValid = false;
        _pesanValidasiWaktu =
            "Tombol Terkunci: Di luar jam operasional sekolah (06:00 - 23:00).";
      });
    } else {
      setState(() {
        _isWaktuValid = true;
        _pesanValidasiWaktu = "Waktu valid. Silakan lakukan absensi.";
      });
    }
  }

  // DIALOG UNTUK MENGISI ALASAN IZIN
  void _tampilkanDialogIzin() {
    final TextEditingController alasanController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Pengajuan Izin / Sakit',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Silakan masukkan alasan izin atau sakit Anda di bawah ini:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: alasanController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Cth: Sakit demam / Izin acara keluarga',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
              ),
              onPressed: () {
                if (alasanController.text.trim().isEmpty) {
                  _showSnackBar('Alasan tidak boleh kosong!', Colors.orange);
                  return;
                }
                Navigator.pop(context);
                _prosesSimpanIzin(alasanController.text.trim());
              },
              child: const Text(
                'Kirim Pengajuan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // MENYIMPAN STATUS IZIN (Tanpa Foto)
  Future<void> _prosesSimpanIzin(String alasan) async {
    setState(() => _isProcessingAbsen = true);
    try {
      final user = _supabase.auth.currentUser;
      final String tanggalFormat = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());

      await _supabase.from('absensi').upsert({
        'siswa_id': user!.id,
        'tanggal': tanggalFormat,
        'mapel': _selectedJadwal!['mata_pelajaran'],
        'kelas': _biodataSiswa['kelas'],
        'status': 'I',
        'keterangan': 'Izin/Sakit: $alasan',
        'guru_pengampu': _selectedJadwal!['guru_pengampu'] ?? 'Sistem Otomatis',
        'lat': null,
        'lng': null,
        'foto_url': null, // Izin tidak menyertakan foto selfie
      }, onConflict: 'siswa_id, tanggal, mapel');

      if (!mounted) return;
      _showSuccessDialog(
        'Pengajuan Izin Berhasil!',
        'Data izin Anda telah tercatat di sistem.',
        Icons.info_rounded,
        Colors.orange,
      );
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessingAbsen = false);
    }
  }

  Future<void> _prosesAbsenLengkap() async {
    if (_selectedJadwal == null) {
      _showSnackBar(
        'Mohon pilih Mata Pelajaran terlebih dahulu!',
        Colors.orange,
      );
      return;
    }

    if (_tipeAbsen == 'Izin / Sakit') {
      _tampilkanDialogIzin();
      return;
    }

    setState(() => _isProcessingAbsen = true);

    try {
      // ==========================================
      // 1. GEOFENCING LOKASI (Algoritma Haversine)
      // ==========================================
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin lokasi (GPS) ditolak!';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi diblokir permanen oleh HP Anda.';
      }

      Position posisiSekarang = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      bool isLokasiValid = false;
      double jarakTerdekat = double.infinity;
      String namaLokasiTerdekat = '';

      for (var lokasi in _lokasiDiizinkan) {
        double jarak = Geolocator.distanceBetween(
          lokasi['lat'],
          lokasi['lng'],
          posisiSekarang.latitude,
          posisiSekarang.longitude,
        );
        if (jarak < jarakTerdekat) {
          jarakTerdekat = jarak;
          namaLokasiTerdekat = lokasi['nama'];
        }
        if (jarak <= _toleransiMeter) {
          isLokasiValid = true;
          break;
        }
      }

      if (!isLokasiValid) {
        throw 'Absen Ditolak!\nAnda berada di luar area. Jarak Anda ${jarakTerdekat.toInt()} meter dari lokasi terdekat ($namaLokasiTerdekat). Maksimal $_toleransiMeter m.';
      }

      // ==========================================
      // VALIDASI KETERLAMBATAN
      // ==========================================
      final String jamMulaiStr = _selectedJadwal!['jam_mulai'] ?? "07:00";
      final List<String> waktuSplit = jamMulaiStr.split(':');
      final int jamMulai = int.parse(waktuSplit[0]);
      final int menitMulai = int.parse(waktuSplit[1]);

      final DateTime now = DateTime.now();
      final DateTime waktuMulaiPelajaran = DateTime(
        now.year,
        now.month,
        now.day,
        jamMulai,
        menitMulai,
      );

      final int toleransiMenit = 15;
      final DateTime batasToleransi = waktuMulaiPelajaran.add(
        Duration(minutes: toleransiMenit),
      );

      String statusAbsenDb = 'H';
      String catatanWaktu = 'Tepat Waktu';

      if (_tipeAbsen == 'Masuk' && now.isAfter(batasToleransi)) {
        statusAbsenDb = 'T';
        catatanWaktu = 'Terlambat';
      }

      // ==========================================
      // 3. SCAN WAJAH (Algoritma CNN via ML Kit)
      // ==========================================
      final ImagePicker picker = ImagePicker();
      final XFile? foto = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 30,
      );

      if (foto == null) throw 'Pengambilan foto dibatalkan.';

      final inputImage = InputImage.fromFilePath(foto.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        throw 'Verifikasi Gagal!\nWajah manusia tidak ditemukan dalam foto.';
      }
      if (faces.length > 1) {
        throw 'Verifikasi Gagal!\nTerdeteksi lebih dari satu wajah. Pastikan hanya ada Anda di dalam kamera.';
      }

      final Face face = faces.first;

      if (face.headEulerAngleY! > 12 || face.headEulerAngleY! < -12) {
        throw 'Verifikasi Gagal!\nWajah harus lurus menghadap kamera. Jangan menoleh ke samping.';
      }
      if (face.headEulerAngleZ! > 12 || face.headEulerAngleZ! < -12) {
        throw 'Verifikasi Gagal!\nPosisi kepala miring. Harap tegakkan kepala Anda menghadap kamera.';
      }

      if (face.leftEyeOpenProbability != null &&
          face.rightEyeOpenProbability != null) {
        if (face.leftEyeOpenProbability! < 0.3 ||
            face.rightEyeOpenProbability! < 0.3) {
          throw 'Verifikasi Gagal!\nMata tidak terlihat jelas atau tertutup. Pastikan tidak menutupi wajah dengan tangan/kacamata pekat.';
        }
      }

      final hidung = face.landmarks[FaceLandmarkType.noseBase];
      final mulutBawah = face.landmarks[FaceLandmarkType.bottomMouth];
      final pipiKiri = face.landmarks[FaceLandmarkType.leftCheek];
      final pipiKanan = face.landmarks[FaceLandmarkType.rightCheek];

      if (hidung == null ||
          mulutBawah == null ||
          pipiKiri == null ||
          pipiKanan == null) {
        throw 'Verifikasi Gagal!\nBagian hidung, mulut, atau pipi tidak terdeteksi bersih. Jangan menutupi wajah dengan tangan!';
      }

      // ==========================================
      // 4. UPLOAD FOTO KE SUPABASE STORAGE
      // ==========================================
      _showSnackBar('Mengunggah foto dan menyimpan data...', Colors.blue);
      final user = _supabase.auth.currentUser;
      final String ekstensiFile = foto.path.split('.').last;
      final String namaFileUnik =
          '${user!.id}_${DateTime.now().millisecondsSinceEpoch}.$ekstensiFile';
      final fileFoto = File(foto.path);

      await _supabase.storage
          .from('foto_absensi')
          .upload(namaFileUnik, fileFoto);

      final String linkFotoPublik = _supabase.storage
          .from('foto_absensi')
          .getPublicUrl(namaFileUnik);

      // ==========================================
      // 5. SIMPAN DATA ABSEN KE TABEL
      // ==========================================
      final String tanggalFormat = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());

      await _supabase.from('absensi').upsert({
        'siswa_id': user.id,
        'tanggal': tanggalFormat,
        'mapel': _selectedJadwal!['mata_pelajaran'],
        'kelas': _biodataSiswa['kelas'],
        'status': statusAbsenDb,
        'keterangan':
            '$_tipeAbsen ($catatanWaktu) - Jarak: ${jarakTerdekat.toInt()}m dari $namaLokasiTerdekat',
        'guru_pengampu': _selectedJadwal!['guru_pengampu'] ?? 'Sistem Otomatis',
        'lat': posisiSekarang.latitude,
        'lng': posisiSekarang.longitude,
        'foto_url': linkFotoPublik,
      }, onConflict: 'siswa_id, tanggal, mapel');

      if (!mounted) return;
      _showSuccessDialog(
        'Absensi Berhasil!',
        'Lokasi dan Wajah Anda telah diverifikasi.\nStatus: ${_tipeAbsen == 'Masuk' ? (statusAbsenDb == 'T' ? 'TERLAMBAT' : 'TEPAT WAKTU') : 'IZIN / SAKIT'}',
        Icons.check_circle,
        Colors.green,
      );
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessingAbsen = false);
    }
  }

  void _showSnackBar(String pesan, Color warna) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: warna,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(
    String judul,
    String pesan,
    IconData iconTampil,
    Color warnaIcon,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(iconTampil, color: warnaIcon, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              judul,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                Navigator.pop(context); // Kembali ke Beranda
              },
              child: const Text(
                'KEMBALI KE BERANDA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Presensi Smart Scan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue.shade200, width: 3),
                    ),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 70,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  '1. Pilih Mata Pelajaran:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 8),
                _jadwalHariIni.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Tidak ada jadwal untuk hari ini.',
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    : DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedJadwal,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        hint: const Text('Pilih Pelajaran Saat Ini...'),
                        items: _jadwalHariIni.map((j) {
                          String jMulai =
                              j['jam_mulai'] != null &&
                                  j['jam_mulai'].length >= 5
                              ? j['jam_mulai'].substring(0, 5)
                              : '?';
                          String jSelesai =
                              j['jam_selesai'] != null &&
                                  j['jam_selesai'].length >= 5
                              ? j['jam_selesai'].substring(0, 5)
                              : '?';

                          return DropdownMenuItem(
                            value: j,
                            child: Text(
                              '${j['mata_pelajaran']} ($jMulai - $jSelesai)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedJadwal = val),
                      ),
                const SizedBox(height: 24),

                const Text(
                  '2. Tipe Absensi:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 8),

                // PERBAIKAN: Hapus Opsi Selesai, Susun Vertikal
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: RadioListTile<String>(
                        title: const Text(
                          'Masuk',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: 'Masuk',
                        groupValue: _tipeAbsen,
                        activeColor: const Color(0xFF1E40AF),
                        onChanged: (val) => setState(() => _tipeAbsen = val!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: RadioListTile<String>(
                        title: const Text(
                          'Izin / Sakit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        value: 'Izin / Sakit',
                        groupValue: _tipeAbsen,
                        activeColor: Colors.deepOrange,
                        onChanged: (val) => setState(() => _tipeAbsen = val!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // NOTIFIKASI JIKA WAKTU TIDAK VALID
                if (!_isWaktuValid && _tipeAbsen != 'Izin / Sakit')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _pesanValidasiWaktu,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // TOMBOL ABSEN YANG DIKUNCI SESUAI WAKTU
                _isProcessingAbsen
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (!_isWaktuValid && _tipeAbsen != 'Izin / Sakit')
                              ? Colors
                                    .grey // Warna abu-abu jika terkunci
                              : (_tipeAbsen == 'Izin / Sakit'
                                    ? Colors.orange.shade700
                                    : Colors.blue[900]),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        onPressed:
                            (!_isWaktuValid && _tipeAbsen != 'Izin / Sakit')
                            ? null
                            : _prosesAbsenLengkap,
                        icon: Icon(
                          _tipeAbsen == 'Izin / Sakit'
                              ? Icons.edit_document
                              : Icons.qr_code_scanner,
                          size: 28,
                        ),
                        label: Text(
                          _tipeAbsen == 'Izin / Sakit'
                              ? 'BUAT PENGAJUAN IZIN'
                              : 'SCAN WAJAH & VERIFIKASI',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                const SizedBox(height: 16),
                Text(
                  _tipeAbsen == 'Izin / Sakit'
                      ? '*Anda tidak perlu melakukan verifikasi Wajah & GPS untuk pengajuan izin.'
                      : '*Pastikan Anda mengizinkan akses Kamera & GPS. Arahkan kamera ke wajah Anda dengan jelas.',
                  style: TextStyle(
                    fontSize: 11,
                    color: _tipeAbsen == 'Izin / Sakit'
                        ? Colors.orange.shade700
                        : Colors.grey,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
