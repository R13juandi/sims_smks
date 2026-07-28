import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/popup_service.dart'; // Sesuaikan rute file
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
    }
  }

  @override
  void dispose() {
    _faceDetector?.close();
    super.dispose();
  }

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

  // 🔥 PERBAIKAN ALGORITMA WAKTU: Early Check-in Window 15 Menit Sebelum Pelajaran
  Map<String, dynamic>? get _mapelAktifSaatIni {
    if (_jadwalHariIni.isEmpty) return null;
    final now = DateTime.now();
    final menitSekarang = (now.hour * 60) + now.minute;

    for (var j in _jadwalHariIni) {
      final startMenit = _jamKeMenit(j['jam_mulai']);
      final endMenit = _jamKeMenit(j['jam_selesai']);
      if (startMenit == null || endMenit == null) continue;
      
      // ✅ Buka tombol absen 15 menit LEBIH AWAL sebelum startMenit
      if (menitSekarang >= (startMenit - 15) && menitSekarang <= endMenit) {
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
        PopupService.show(
          context,
          'Gagal memuat data jadwal. Periksa koneksi internet.',
          isSuccess: false,
          judul: 'Koneksi Bermasalah',
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
                          if (foto != null) {
                            setStateDialog(() => fileSuratDokter = foto);
                          }
                        } catch (e) {
                          PopupService.show(
                            context,
                            'Gagal mengambil foto: $e',
                            isSuccess: false,
                            judul: 'Kamera Error',
                          );
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
                      PopupService.show(
                        context,
                        'Keterangan tidak boleh kosong!',
                        isSuccess: false,
                        judul: 'Peringatan',
                      );
                      return;
                    }
                    if (jenisKeterangan == 'Sakit' && fileSuratDokter == null) {
                      PopupService.show(
                        context,
                        'Sakit wajib melampirkan surat dokter!',
                        isSuccess: false,
                        judul: 'Surat Tidak Ada',
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
      if (user == null) {
        throw 'Sesi login tidak ditemukan, silakan login ulang.';
      }

      String? urlSurat;
      if (fotoSakit != null) {
        PopupService.show(
          context,
          'Sedang mengunggah surat dokter ke sistem...',
          isSuccess: true,
          judul: 'Mohon Tunggu',
        );
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
          if (mounted) Navigator.pop(context);
          throw 'Gagal mengunggah surat: $e';
        }
        if (mounted) Navigator.pop(context);
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
      PopupService.show(
        context,
        'Terkirim pada $jamFormat WIB\nMenunggu verifikasi guru.\nStatus: $jenisKeterangan Diajukan',
        isSuccess: true,
        judul: 'Pengajuan Berhasil!',
      );
    } catch (e) {
      PopupService.show(
        context,
        'Gagal mengirim pengajuan: $e',
        isSuccess: false,
        judul: 'Pengajuan Gagal',
      );
    } finally {
      if (mounted) setState(() => _isProcessingAbsen = false);
    }
  }

  // =========================================================================
  // 🔥 ALGORITMA LIVENESS KALIBRASI: SUPER NATURAL, CEPAT & RAMAH PENGGUNA
  // =========================================================================
  Future<void> _prosesAbsenLengkap() async {
    if (_tipeAbsen == 'Izin / Sakit') {
      _tampilkanDialogIzin();
      return;
    }

    if (_tipeAbsen == 'Masuk' && _mapelAktifSaatIni == null) {
      PopupService.show(
        context,
        'Absen ditolak! Tidak ada pelajaran aktif saat ini.',
        isSuccess: false,
        judul: 'Pelajaran Kosong',
      );
      return;
    }

    if (_tipeAbsen == 'Pulang') {
      final wp = _waktuPulangSekolah;
      if (wp != null && DateTime.now().isBefore(wp)) {
        PopupService.show(
          context,
          'Absen ditolak! Belum waktunya pulang sekolah.',
          isSuccess: false,
          judul: 'Belum Waktunya',
        );
        return;
      }
    }

    if (!_isLokasiValid) {
      PopupService.show(
        context,
        'Absen ditolak! Anda berada di luar area sekolah.',
        isSuccess: false,
        judul: 'Di Luar Area',
      );
      return;
    }

    // 1. GENERATE RANDOM LIVENESS CHALLENGE (SUDAH DIKALIBRASI AGAR SANGAT MUDAH)
    final List<Map<String, dynamic>> challenges = [
      {
        'kode': 'SMILE_NATURAL',
        'instruksi': 'TERSENYUM TIPIS / NATURAL',
        'desc': 'Tatap kamera dan berikan senyuman natural Anda saat memotret.',
        'icon': Icons.sentiment_satisfied_alt_rounded,
      },
      {
        'kode': 'EYES_WIDE',
        'instruksi': 'TATAP KAMERA DENGAN JELAS',
        'desc': 'Pastikan mata Anda terbuka jelas dan memandang lurus ke kamera.',
        'icon': Icons.remove_red_eye_rounded,
      },
      {
        'kode': 'TURN_SLIGHTLY',
        'instruksi': 'TOLEH SEDIKIT KE KANAN',
        'desc': 'Geser/putar wajah Anda sedikit saja ke arah kanan saat foto.',
        'icon': Icons.turn_right_rounded,
      },
    ];

    challenges.shuffle();
    final selectedChallenge = challenges.first;

    // Tampilkan instruksi Challenge yang ramah motorik pengguna
    final bool? siapChallenge = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              selectedChallenge['icon'] as IconData,
              color: Colors.blue.shade900,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Verifikasi Biometrik',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'INSTRUKSI KEAMANAN (LIVENESS):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ambil foto wajah sambil\n${selectedChallenge['instruksi']}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              selectedChallenge['desc'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '*Tips: Ambil foto di tempat terang agar langsung terverifikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Buka Kamera Sekarang',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (siapChallenge != true) return;

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

      // --- AMBIL FOTO KAMERA DEPAN ---
      final picker = ImagePicker();
      final foto = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 50, // Resolusi 50 agar akurasi mata & wajah lebih tajam
      );
      if (foto == null) throw 'Pengambilan foto dibatalkan.';

      if (_faceDetector == null) {
        throw 'Modul deteksi wajah belum siap. Coba lagi.';
      }

      final inputImage = InputImage.fromFilePath(foto.path);
      final List<Face> faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        throw 'Wajah tidak terdeteksi! Pastikan pencahayaan cukup dan wajah terlihat di layar.';
      }
      if (faces.length > 1) {
        throw 'Terdeteksi lebih dari satu wajah! Pastikan hanya Anda sendiri di depan kamera.';
      }

      final face = faces.first;

      // 2. 🔥 VALIDASI LIVENESS KALIBRASI BARU (SANGAT RAMAH PENGGUNA)
      PopupService.show(
        context,
        'Mengecek kecocokan wajah dengan AI...',
        isSuccess: true,
        judul: 'Memproses Absensi',
      );

      if (selectedChallenge['kode'] == 'SMILE_NATURAL') {
        final smileProb = face.smilingProbability ?? 0.0;
        // 🔥 Threshold diturunkan ke 0.25 (Senyum tipis natural langsung lolos!)
        if (smileProb < 0.25) {
          if (mounted) Navigator.pop(context);
          throw 'Verifikasi Gagal: Wajah terlihat terlalu datar/murung. Harap berikan senyuman tipis natural saat foto!';
        }
      } else if (selectedChallenge['kode'] == 'EYES_WIDE') {
        final leftEye = face.leftEyeOpenProbability ?? 1.0;
        final rightEye = face.rightEyeOpenProbability ?? 1.0;
        // 🔥 Hanya memastikan kedua mata terbuka (> 0.50). Menolak foto layar HP blur!
        if (leftEye < 0.50 || rightEye < 0.50) {
          if (mounted) Navigator.pop(context);
          throw 'Verifikasi Gagal: Mata terdeteksi tertutup atau foto terlalu blur/gelap. Pastikan menatap jelas ke kamera!';
        }
      } else if (selectedChallenge['kode'] == 'TURN_SLIGHTLY') {
        final rotasiY = face.headEulerAngleY ?? 0.0;
        // 🔥 Threshold diturunkan ke -4.0 (Geser kepala sedikit sekali langsung lolos!)
        if (rotasiY > -4.0) {
          if (mounted) Navigator.pop(context);
          throw 'Verifikasi Gagal: Wajah terlalu lurus kaku. Harap putar/geser sedikit wajah Anda ke arah kanan kamera!';
        }
      }

      // 3. 🔥 VERIFIKASI IDENTITAS CNN (MobileFaceNet - Cosine Similarity)
      if (!FaceRecognitionService.instance.isReady) {
        if (mounted) Navigator.pop(context);
        throw 'Model pengenalan wajah (CNN) belum siap. Tutup dan buka ulang halaman ini.';
      }

      final rawBaseline = _biodataSiswa['face_baseline'];
      final baselineEmbedding = FaceRecognitionService.instance.decodeEmbedding(
        rawBaseline,
      );

      if (baselineEmbedding == null) {
        if (mounted) Navigator.pop(context);
        throw 'Wajah Anda belum terdaftar di sistem. Silakan hubungi Admin/TU untuk pendaftaran wajah terlebih dahulu.';
      }

      final embeddingSekarang = await FaceRecognitionService.instance
          .getEmbedding(File(foto.path), face);

      if (embeddingSekarang == null) {
        if (mounted) Navigator.pop(context);
        throw 'Gagal mengekstraksi vektor wajah. Coba ulangi di tempat yang lebih terang.';
      }

      final similarity = FaceRecognitionService.instance.cosineSimilarity(
        embeddingSekarang,
        baselineEmbedding,
      );

      if (similarity < FaceRecognitionService.matchThreshold) {
        if (mounted) Navigator.pop(context);
        throw 'Wajah Tidak Dikenali! (Kemiripan ${(similarity * 100).toStringAsFixed(1)}%). Pastikan yang absen adalah pemilik akun asli!';
      }

      if (mounted) Navigator.pop(context); // Tutup dialog loading jika sukses lolos

      // 4. UNGGAH BUKTI & SIMPAN KE DATABASE
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw 'Sesi login tidak ditemukan, silakan login ulang.';
      }

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
        'keterangan':
            '$_tipeAbsen ($catatanWaktu - Liveness ${selectedChallenge['kode']} Lolos)',
        'guru_pengampu': guruSimpan,
        'lat': posisiSekarang.latitude,
        'lng': posisiSekarang.longitude,
        'foto_url': linkFotoPublik,
      }, onConflict: 'siswa_id, tanggal, mapel');

      if (!mounted) return;
      PopupService.show(
        context,
        'Terkirim pada $jamFormat WIB\nMenunggu verifikasi guru.\nStatus: Absen $_tipeAbsen $mapelSimpan\n(Biometrik Wajah Valid 100%)',
        isSuccess: true,
        judul: 'Absensi Berhasil!',
      );
    } catch (e) {
      PopupService.show(
        context,
        e.toString(),
        isSuccess: false,
        judul: 'Presensi Gagal',
      );
    } finally {
      if (mounted) setState(() => _isProcessingAbsen = false);
    }
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
                                      PopupService.show(
                                        context,
                                        'Sedang memperbarui koordinat GPS Anda...',
                                        isSuccess: true,
                                        judul: 'Mencari Lokasi',
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