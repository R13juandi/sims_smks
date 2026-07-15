import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Layanan pengenalan wajah berbasis CNN (MobileFaceNet).
///
/// Alur:
/// 1. ML Kit (google_mlkit_face_detection) -> mendeteksi wajah & bounding box
///    (lapisan liveness: jumlah wajah, sudut kepala).
/// 2. Crop wajah dari foto berdasarkan bounding box tsb.
/// 3. CNN MobileFaceNet (TensorFlow Lite) -> mengubah wajah menjadi
///    embedding vektor 192 dimensi.
/// 4. Embedding baru dibandingkan (cosine similarity) dengan embedding
///    baseline yang tersimpan di kolom `profiles.face_baseline`.
class FaceRecognitionService {
  FaceRecognitionService._internal();
  static final FaceRecognitionService instance = FaceRecognitionService._internal();

  static const String _modelPath = 'assets/models/mobilefacenet.tflite';
  static const int inputSize = 112; // MobileFaceNet input: 112x112x3
  static const int embeddingSize = 192; // output embedding dimension

  /// Ambang batas cosine similarity untuk dianggap "orang yang sama".
  /// Rentang umum 0.70 - 0.85. Semakin tinggi -> semakin ketat.
  static const double matchThreshold = 0.75;

  Interpreter? _interpreter;
  bool get isReady => _interpreter != null;

  /// Wajib dipanggil sekali (misal di initState halaman presensi)
  /// sebelum getEmbedding() digunakan.
  Future<void> init() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
    } catch (e) {
      // Jangan lempar exception ke UI di sini; biarkan pemanggil
      // mengecek isReady dan menampilkan pesan yang sesuai.
      _interpreter = null;
      rethrow;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Crop area wajah dari file foto berdasarkan bounding box ML Kit,
  /// lalu resize ke 112x112 sesuai kebutuhan input CNN.
  img.Image? _cropWajah(File fotoFile, Face face) {
    try {
      final bytes = fotoFile.readAsBytesSync();
      final original = img.decodeImage(bytes);
      if (original == null) return null;

      final box = face.boundingBox;

      // Beri padding sedikit di sekeliling wajah agar konteks tidak terlalu ketat
      final double padding = box.width * 0.15;
      int x = (box.left - padding).clamp(0, original.width.toDouble()).toInt();
      int y = (box.top - padding).clamp(0, original.height.toDouble()).toInt();
      int w = (box.width + padding * 2).clamp(0, original.width - x).toInt();
      int h = (box.height + padding * 2).clamp(0, original.height - y).toInt();

      if (w <= 0 || h <= 0) return null;

      final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);
      return img.copyResize(cropped, width: inputSize, height: inputSize);
    } catch (e) {
      return null;
    }
  }

  /// Mengubah gambar wajah menjadi tensor input [1, 112, 112, 3]
  /// dengan normalisasi piksel ke rentang [-1, 1].
  List<List<List<List<double>>>> _imageToInputTensor(img.Image faceImage) {
    return [
      List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = faceImage.getPixel(x, y);
            final r = (pixel.r / 127.5) - 1.0;
            final g = (pixel.g / 127.5) - 1.0;
            final b = (pixel.b / 127.5) - 1.0;
            return [r, g, b];
          },
        ),
      ),
    ];
  }

  /// Menjalankan CNN dan mengembalikan embedding 192 dimensi.
  /// Mengembalikan null jika model belum siap / wajah gagal di-crop.
  Future<List<double>?> getEmbedding(File fotoFile, Face face) async {
    if (_interpreter == null) {
      throw 'Model pengenalan wajah belum dimuat (FaceRecognitionService belum di-init).';
    }

    final faceImage = _cropWajah(fotoFile, face);
    if (faceImage == null) {
      return null;
    }

    final input = _imageToInputTensor(faceImage);
    final output = List.generate(1, (_) => List.filled(embeddingSize, 0.0));

    try {
      _interpreter!.run(input, output);
      return List<double>.from(output[0]);
    } catch (e) {
      throw 'Gagal menjalankan model CNN: $e';
    }
  }

  /// Menghitung cosine similarity antara dua embedding wajah.
  /// Hasil mendekati 1.0 = sangat mirip, mendekati 0 = berbeda.
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  bool isMatch(List<double> embeddingBaru, List<double> embeddingBaseline,
      {double threshold = matchThreshold}) {
    return cosineSimilarity(embeddingBaru, embeddingBaseline) >= threshold;
  }

  // ---------- Utilitas simpan/baca embedding dari kolom teks Supabase ----------

  String encodeEmbedding(List<double> embedding) => jsonEncode(embedding);

  List<double>? decodeEmbedding(dynamic raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}