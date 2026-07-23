import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/face_recognition_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'rekap_absensi_siswa_screen.dart';

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

  String _tipeAbsen = 'Masuk';

  String _infoLokasiUI = "Mencari lokasi...";
  Color _warnaLokasiUI = Colors.grey;
  bool _isLokasiValid = false;

  // Toleransi keterlambatan absen masuk (menit)
  static const int _toleransiMenitTerlambat = 15;
  final double _toleransiMeter = 50.0;

  final List<Map<String, dynamic>> _lokasiDiizinkan = [
    {'nama': 'Rumah Tomang', 'lat': -6.1595261, 'lng': 106.5820671},
    {'nama': 'Kampus Bina Sarana Global', 'lat': -6.179190, 'lng': 106.608069},
    {'nama': 'SMK Islam YIA', 'lat': -6.161616, 'lng': 106.675552},
    {'nama': 'Rumah Rajeg', 'lat': -6.116251, 'lng': 106.506694},
    {'nama': 'toko', 'lat': -6.153981, 'lng': 106.577925},
  ];

  FaceDetector? _faceDetector;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _initFaceRecognition();
    _loadDataAwal();
    _cekLokasiSekarang();
  }

  Future<void> _initFaceRecognition() async {
    try {
      await FaceRecognitionService.instance.init();
    } catch (e) {
      debugPrint('Gagal memuat model CNN: $e');
      // Tidak menghentikan halaman; validasi CNN akan menolak dengan
      // pesan jelas saat tombol presensi ditekan jika model gagal dimuat.
    }
  }

  @override
  void dispose() {
    _faceDetector?.close();
    super.dispose();
  }

  // ==============================================================
  // HELPER: parsing "HH:mm" atau "HH:mm:ss" ke total menit, aman null
  // ==============================================================
  int? _jamKeMenit(dynamic jamStr) {
    if (jamStr == null) return null;
    try {
      final parts = jamStr.toString().split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return (h * 60) + m;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _mapelAktifSaatIni {
    if (_jadwalHariIni.isEmpty) return null;
    final now = DateTime.now();
    final menitSekarang = (now.hour * 60) + now.minute;

    for (var j in _jadwalHariIni) {
      final startMenit = _jamKeMenit(j['jam_mulai']);
      final endMenit = _jamKeMenit(j['jam_selesai']);
      if (startMenit == null || endMenit == null) continue;
      if (menitSekarang >= startMenit && menitSekarang <= endMenit) {
        return j;
      }
    }
    return null;
  }

  DateTime? get _waktuPulangSekolah {
    if (_jadwalHariIni.isEmpty) return null;
    String jamPalingAkhir = "00:00";
    for (var j in _jadwalHariIni) {
      final jamSelesai = (j['jam_selesai'] ?? "00:00").toString();
      if (jamSelesai.compareTo(jamPalingAkhir) > 0) {
        jamPalingAkhir = jamSelesai;
      }
    }
    if (jamPalingAkhir == "00:00") return null;

    try {
      final now = DateTime.now();
      final split = jamPalingAkhir.split(':');
      final h = int.tryParse(split[0]) ?? 0;
      final m = int.tryParse(split.length > 1 ? split[1] : '0') ?? 0;
      return DateTime(now.year, now.month, now.day, h, m);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cekLokasiSekarang() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _infoLokasiUI = "Izin lokasi ditolak";
            _warnaLokasiUI = Colors.red;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _infoLokasiUI =
              "Izin lokasi ditolak permanen. Aktifkan di Pengaturan.";
          _warnaLokasiUI = Colors.red;
        });
        return;
      }

      final posisiSekarang = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double jarakTerdekat = double.infinity;
      String namaLokasiTerdekat = '';
      bool valid = false;

      for (var lokasi in _lokasiDiizinkan) {
        final lat = lokasi['lat'] as double? ?? 0.0;
        final lng = lokasi['lng'] as double? ?? 0.0;
        final jarak = Geolocator.distanceBetween(
          lat,
          lng,
          posisiSekarang.latitude,
          posisiSekarang.longitude,
        );
        if (jarak < jarakTerdekat) {
          jarakTerdekat = jarak;
          namaLokasiTerdekat = (lokasi['nama'] ?? '-').toString();
        }
        if (jarak <= _toleransiMeter) valid = true;
      }

      if (!mounted) return;
      setState(() {
        _isLokasiValid = valid;
        if (valid) {
          _infoLokasiUI = "$namaLokasiTerdekat (${jarakTerdekat.toInt()} m)";
          _warnaLokasiUI = Colors.green;
        } else {
          final jarakTampil = jarakTerdekat > 1000
              ? "${(jarakTerdekat / 1000).toStringAsFixed(2)} km"
              : "${jarakTerdekat.toInt()} meter";
          _infoLokasiUI = "Luar Area: $jarakTampil";
          _warnaLokasiUI = Colors.red;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _infoLokasiUI = "GPS Gagal Diakses";
        _warnaLokasiUI = Colors.orange;
      });
    }
  }

  String _getHariIni() {
    final now = DateTime.now();
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return hari[now.weekday - 1];
  }

  Future<void> _loadDataAwal() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final prof = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      _biodataSiswa = prof ?? {};
      final kelasSiswa = (_biodataSiswa['kelas'] ?? '').toString();

      String hariIni = _getHariIni();
      if (hariIni == 'Sabtu' || hariIni == 'Minggu') hariIni = 'Senin';

      final jadwalRes = await _supabase
          .from('jadwal')
          .select('*')
          .ilike('kelas', '%$kelasSiswa%')
          .ilike('hari', hariIni)
          .order('jam_mulai', ascending: true);

      if (mounted) {
        setState(() {
          _jadwalHariIni = List<Map<String, dynamic>>.from(jadwalRes as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error _loadDataAwal: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          'Gagal memuat data jadwal. Periksa koneksi internet.',
          Colors.red,
        );
      }
    }
  }

  void _tampilkanDialogIzin() {
    String jenisKeterangan = 'Izin';
    final TextEditingController alasanController = TextEditingController();
    XFile? fileSuratDokter;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Buat Pengajuan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Izin',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: 'Izin',
                          groupValue: jenisKeterangan,
                          activeColor: Colors.orange,
                          onChanged: (val) => setStateDialog(
                            () => jenisKeterangan = val ?? 'Izin',
                          ),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Sakit',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: 'Sakit',
                          groupValue: jenisKeterangan,
                          activeColor: Colors.blue,
                          onChanged: (val) => setStateDialog(() {
                            jenisKeterangan = val ?? 'Sakit';
                            fileSuratDokter = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: alasanController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: jenisKeterangan == 'Sakit'
                          ? 'Sakit apa?'
                          : 'Alasan Izin...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  if (jenisKeterangan == 'Sakit') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Lampiran Surat Dokter:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        try {
                          final picker = ImagePicker();
                          final foto = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 50,
                          );
                          if (foto != null)
                            setStateDialog(() => fileSuratDokter = foto);
                        } catch (e) {
                          _showSnackBar('Gagal mengambil foto: $e', Colors.red);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Center(
                          child: fileSuratDokter == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ambil Foto Surat',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Foto Tersimpan',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                  ),
                  onPressed: () {
                    if (alasanController.text.trim().isEmpty) {
                      _showSnackBar(
                        'Keterangan tidak boleh kosong!',
                        Colors.orange,
                      );
                      return;
                    }
                    if (jenisKeterangan == 'Sakit' && fileSuratDokter == null) {
                      _showSnackBar(
                        'Sakit wajib melampirkan surat dokter!',
                        Colors.red,
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _prosesSimpanIzin(
                      jenisKeterangan,
                      alasanController.text.trim(),
                      fileSuratDokter,
                    );
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
      },
    );
  }

  Future<void> _prosesSimpanIzin(
    String jenisKeterangan,
    String alasan,
    XFile? fotoSakit,
  ) async {
    if (!mounted) return;
    setState(() => _isProcessingAbsen = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null)
        throw 'Sesi login tidak ditemukan, silakan login ulang.';

      String? urlSurat;
      if (fotoSakit != null) {
        _showSnackBar('Mengunggah surat...', Colors.blue);
        try {
          final ekstensiFile = fotoSakit.path.split('.').last;
          final namaFileUnik =
              'SURAT_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ekstensiFile';
          await _supabase.storage
              .from('foto_absensi')
              .upload(namaFileUnik, File(fotoSakit.path));
          urlSurat = _supabase.storage
              .from('foto_absensi')
              .getPublicUrl(namaFileUnik);
        } catch (e) {
          throw 'Gagal mengunggah surat: $e';
        }
      }

      final tanggalFormat = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final jamFormat = DateFormat('HH:mm').format(DateTime.now());
      final mapelPilihan = _mapelAktifSaatIni;

      await _supabase.from('absensi').upsert({
        'siswa_id': user.id,
        'tanggal': tanggalFormat,
        'waktu_absen': jamFormat,
        'mapel': mapelPilihan != null
            ? (mapelPilihan['mata_pelajaran'] ?? '-')
            : 'Seluruh Mapel Hari Ini',
        'kelas': _biodataSiswa['kelas'] ?? '-',
        'status': jenisKeterangan == 'Izin' ? 'I' : 'S',
        'status_verifikasi': 'Pending',
        'keterangan': '$jenisKeterangan: $alasan',
        'guru_pengampu': mapelPilihan != null
            ? (mapelPilihan['guru_pengampu'] ?? 'Semua Guru')
            : 'Semua Guru',
        if (urlSurat != null) 'foto_url': urlSurat,
      }, onConflict: 'siswa_id, tanggal, mapel');

      if (!mounted) return;
      _showSuccessDialog(
        'Pengajuan Berhasil!',
        'Terkirim pada $jamFormat WIB\nMenunggu verifikasi guru.\nStatus: $jenisKeterangan Diajukan',
        Icons.assignment_turned_in,
        Colors.orange,
      );
    } catch (e) {
      _showSnackBar('Gagal mengirim pengajuan: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessingAbsen = false);
    }
  }

  Future<void> _prosesAbsenLengkap() async {
    if (_tipeAbsen == 'Izin / Sakit') {
      _tampilkanDialogIzin();
      return;
    }

    if (_tipeAbsen == 'Masuk' && _mapelAktifSaatIni == null) {
      _showSnackBar(
        'Absen ditolak! Tidak ada pelajaran aktif saat ini.',
        Colors.orange,
      );
      return;
    }

    if (_tipeAbsen == 'Pulang') {
      final wp = _waktuPulangSekolah;
      if (wp != null && DateTime.now().isBefore(wp)) {
        _showSnackBar(
          'Absen ditolak! Belum waktunya pulang sekolah.',
          Colors.red,
        );
        return;
      }
    }

    if (!_isLokasiValid) {
      _showSnackBar(
        'Absen ditolak! Anda berada di luar area sekolah.',
        Colors.red,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessingAbsen = true);

    try {
      final posisiSekarang = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final now = DateTime.now();

      String statusAbsenDb = 'H';
      String catatanWaktu = 'Tepat Waktu';
      String mapelSimpan = 'Pulang Sekolah';
      String guruSimpan = 'Semua Guru';

      if (_tipeAbsen == 'Masuk') {
        final mapelAktif = _mapelAktifSaatIni;
        if (mapelAktif == null) {
          throw 'Jadwal pelajaran aktif tidak ditemukan. Coba muat ulang halaman.';
        }
        mapelSimpan = (mapelAktif['mata_pelajaran'] ?? '-').toString();
        guruSimpan = (mapelAktif['guru_pengampu'] ?? 'Sistem Otomatis')
            .toString();

        final startMenit = _jamKeMenit(mapelAktif['jam_mulai']);
        if (startMenit != null) {
          final waktuMulai = DateTime(
            now.year,
            now.month,
            now.day,
            0,
            0,
          ).add(Duration(minutes: startMenit));
          final batasToleransi = waktuMulai.add(
            const Duration(minutes: _toleransiMenitTerlambat),
          );

          if (now.isAfter(batasToleransi)) {
            statusAbsenDb = 'T';
            catatanWaktu =
                'Terlambat (Lebih dari $_toleransiMenitTerlambat Menit)';
          }
        }
      } else {
        catatanWaktu = 'Absen Kepulangan';
      }

      // --- Ambil foto & deteksi wajah ---
      final picker = ImagePicker();
      final foto = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 30,
      );
      if (foto == null) throw 'Pengambilan foto dibatalkan.';

      if (_faceDetector == null)
        throw 'Modul deteksi wajah belum siap. Coba lagi.';

      final inputImage = InputImage.fromFilePath(foto.path);
      final List<Face> faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty)
        throw 'Wajah tidak terdeteksi. Pastikan pencahayaan cukup.';
      if (faces.isEmpty)
        throw 'Wajah tidak terdeteksi. Pastikan pencahayaan cukup.';
      if (faces.length > 1)
        throw 'Terdeteksi lebih dari satu wajah pada kamera.';

      final face = faces.first;
      final sudutKepala = face.headEulerAngleY ?? 0;
      if (sudutKepala > 12 || sudutKepala < -12) {
        throw 'Wajah harus lurus menghadap kamera.';
      }

      // ================= LAPISAN 2: VERIFIKASI CNN (MobileFaceNet) =================
      _showSnackBar('Menganalisis wajah dengan CNN...', Colors.blue);

      if (!FaceRecognitionService.instance.isReady) {
        throw 'Model pengenalan wajah (CNN) belum siap. Tutup dan buka ulang halaman ini.';
      }

      final rawBaseline = _biodataSiswa['face_baseline'];
      final baselineEmbedding = FaceRecognitionService.instance.decodeEmbedding(
        rawBaseline,
      );

      if (baselineEmbedding == null) {
        throw 'Wajah Anda belum terdaftar di sistem. Silakan hubungi Admin/TU untuk pendaftaran wajah (Face Enrollment) terlebih dahulu.';
      }

      final embeddingSekarang = await FaceRecognitionService.instance
          .getEmbedding(File(foto.path), face);

      if (embeddingSekarang == null) {
        throw 'Gagal memproses citra wajah. Coba ulangi dengan pencahayaan lebih baik.';
      }

      final similarity = FaceRecognitionService.instance.cosineSimilarity(
        embeddingSekarang,
        baselineEmbedding,
      );

      if (similarity < FaceRecognitionService.matchThreshold) {
        throw 'Wajah tidak cocok dengan data terdaftar (kemiripan ${(similarity * 100).toStringAsFixed(1)}%). Presensi ditolak.';
      }
      // ================================================================================

      final user = _supabase.auth.currentUser;
      if (user == null)
        throw 'Sesi login tidak ditemukan, silakan login ulang.';

      String linkFotoPublik;
      try {
        final namaFileUnik =
            '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage
            .from('foto_absensi')
            .upload(namaFileUnik, File(foto.path));
        linkFotoPublik = _supabase.storage
            .from('foto_absensi')
            .getPublicUrl(namaFileUnik);
      } catch (e) {
        throw 'Gagal mengunggah foto bukti presensi: $e';
      }

      final tanggalFormat = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final jamFormat = DateFormat('HH:mm').format(DateTime.now());

      await _supabase.from('absensi').upsert({
        'siswa_id': user.id,
        'tanggal': tanggalFormat,
        'waktu_absen': jamFormat,
        'mapel': mapelSimpan,
        'kelas': _biodataSiswa['kelas'] ?? '-',
        'status': statusAbsenDb,
        'status_verifikasi': 'Pending',
        'keterangan': '$_tipeAbsen ($catatanWaktu)',
        'guru_pengampu': guruSimpan,
        'lat': posisiSekarang.latitude,
        'lng': posisiSekarang.longitude,
        'foto_url': linkFotoPublik,
      }, onConflict: 'siswa_id, tanggal, mapel');

      if (!mounted) return;
      _showSuccessDialog(
        'Absensi Berhasil!',
        'Terkirim pada $jamFormat WIB\nMenunggu verifikasi guru.\nStatus: Absen $_tipeAbsen $mapelSimpan',
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
    if (!mounted) return;
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
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.4,
              ),
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
                Navigator.pop(context);
                if (mounted) Navigator.pop(context);
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
    final mapelAktif = _mapelAktifSaatIni;
    final wp = _waktuPulangSekolah;

    bool isBolehPulang = false;
    String pesanPulang;

    if (wp == null) {
      pesanPulang = "Tidak ada jadwal pelajaran hari ini.";
    } else if (DateTime.now().isBefore(wp)) {
      pesanPulang =
          "Jam pulang hari ini adalah ${DateFormat('HH:mm').format(wp)} WIB.";
    } else {
      isBolehPulang = true;
      pesanPulang = "Silakan lakukan absen pulang sekarang.";
    }

    bool isButtonDisabled = !_isLokasiValid;
    if (_tipeAbsen == 'Masuk' && mapelAktif == null) isButtonDisabled = true;
    if (_tipeAbsen == 'Pulang' && !isBolehPulang) isButtonDisabled = true;

    final Color buttonColor = isButtonDisabled
        ? Colors.grey
        : (_tipeAbsen == 'Izin / Sakit'
              ? Colors.orange.shade700
              : Colors.blue[900]!);

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
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RekapAbsensiSiswaScreen(),
              ),
            ),
            icon: const Icon(Icons.history_edu, color: Color(0xFF1E40AF)),
            label: const Text(
              'Lihat Rekap',
              style: TextStyle(
                color: Color(0xFF1E40AF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadDataAwal();
                await _cekLokasiSekarang();
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _warnaLokasiUI.withOpacity(0.1),
                            border: Border.all(color: _warnaLokasiUI),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: _warnaLokasiUI,
                                    size: 28,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.refresh,
                                      color: _warnaLokasiUI,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _showSnackBar(
                                        'Mencari GPS...',
                                        Colors.blue,
                                      );
                                      _cekLokasiSekarang();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Status Lokasi Anda',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _infoLokasiUI,
                                style: TextStyle(
                                  color: _warnaLokasiUI,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.face_retouching_natural_rounded,
                                color: Colors.blue,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Validasi Liveness',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Kamera & Deteksi Wajah Siap',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Pilih Tipe Absensi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: RadioListTile<String>(
                      title: const Text(
                        'Masuk (Sesuai Jam Aktif)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: 'Masuk',
                      groupValue: _tipeAbsen,
                      activeColor: const Color(0xFF1E40AF),
                      onChanged: (val) =>
                          setState(() => _tipeAbsen = val ?? 'Masuk'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: RadioListTile<String>(
                      title: const Text(
                        'Pulang Sekolah',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: 'Pulang',
                      groupValue: _tipeAbsen,
                      activeColor: const Color(0xFF1E40AF),
                      onChanged: (val) =>
                          setState(() => _tipeAbsen = val ?? 'Pulang'),
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
                      onChanged: (val) =>
                          setState(() => _tipeAbsen = val ?? 'Izin / Sakit'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_tipeAbsen == 'Masuk') ...[
                    const Text(
                      'Mata Pelajaran Saat Ini:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: mapelAktif != null
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mapelAktif != null
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mapelAktif != null
                                ? Icons.play_circle_fill_rounded
                                : Icons.cancel,
                            color: mapelAktif != null
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mapelAktif != null
                                      ? (mapelAktif['mata_pelajaran'] ?? '-')
                                            .toString()
                                      : 'Belum Ada Pelajaran Dimulai',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: mapelAktif != null
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                                if (mapelAktif != null)
                                  Text(
                                    'Jam ${(mapelAktif['jam_mulai'] ?? '-').toString()} - ${(mapelAktif['jam_selesai'] ?? '-').toString()} WIB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ] else if (_tipeAbsen == 'Pulang') ...[
                    const Text(
                      'Status Kepulangan:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isBolehPulang
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBolehPulang
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isBolehPulang ? Icons.check_circle : Icons.cancel,
                            color: isBolehPulang ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBolehPulang
                                      ? 'Boleh Pulang Sekarang'
                                      : 'Belum Waktunya Pulang',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isBolehPulang
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                                Text(
                                  pesanPulang,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isBolehPulang
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  _isProcessingAbsen
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                          ),
                          onPressed: isButtonDisabled
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
                                ? 'BUAT PENGAJUAN IZIN/SAKIT'
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
                        ? '*Izin & Sakit tidak memerlukan Scan Wajah / Deteksi Area.'
                        : '*Sistem akan mengunci tombol secara otomatis jika di luar area, belum ada jam pelajaran, atau belum saatnya pulang.',
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
            ),
    );
  }
}
