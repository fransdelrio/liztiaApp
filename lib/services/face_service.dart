import 'dart:io';

import 'package:face_verification/face_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

enum FaceDetectionError { noFace, multipleFaces }

class FaceDetectionException implements Exception {
  const FaceDetectionException(this.error);

  final FaceDetectionError error;

  @override
  String toString() => switch (error) {
    FaceDetectionError.noFace => 'No face detected',
    FaceDetectionError.multipleFaces => 'Multiple faces detected',
  };
}

class FaceService {
  static FaceDetector? _detector;

  // Mismas opciones que usa face_verification para que el conteo de caras
  // coincida con el que valida registerFromImagePath.
  static FaceDetector get _faceDetector => _detector ??= FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<void> init() async {
    await FaceVerification.instance.init();
  }

  Future<String?> verify(String imagePath) async {
    return await FaceVerification.instance.verifyFromImagePath(
      imagePath: imagePath,
    );
  }

  Future<String> register({
    required String id,
    required String imagePath,
    required String imageId,
    String? name,
  }) async {
    final prepared = await _singleFaceImage(imagePath);
    try {
      if (kDebugMode) {
        debugPrint('MLKit: registrando con $prepared');
      }
      return await FaceVerification.instance.registerFromImagePath(
        id: id,
        imagePath: prepared,
        imageId: imageId,
        name: name,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MLKit: register falló: $e');
      }
      rethrow;
    } finally {
      if (prepared != imagePath) {
        await _delete(prepared);
      }
    }
  }

  Future<void> deleteUserFaces(String id) async {
    await FaceVerification.instance.deleteUserFaces(id);
  }

  Future<List<String>> getAllRegisteredUsers() {
    return FaceVerification.instance.getAllRegisteredUsers();
  }

  /// Valida una foto recién capturada sin registrarla: debe haber exactamente
  /// un rostro. Lanza `No face detected` o `Multiple faces detected`.
  Future<void> validatePhoto(String imagePath) async {
    final faces = await _detect(imagePath);
    _logFaces('foto', faces);
    if (faces.isEmpty) {
      throw const FaceDetectionException(FaceDetectionError.noFace);
    }
    if (faces.length > 1) {
      throw const FaceDetectionException(FaceDetectionError.multipleFaces);
    }
  }

  Future<List<Face>> _detect(String path) {
    return _faceDetector.processImage(InputImage.fromFilePath(path));
  }

  /// Devuelve la foto original intacta si MLKit ve exactamente 1 cara.
  /// No recorta la imagen: con 0 o varias caras lanza excepción para que la
  /// pantalla pida repetir la foto.
  Future<String> _singleFaceImage(String imagePath) async {
    final faces = await _detect(imagePath);
    _logFaces('original', faces);
    if (faces.length == 1) return imagePath;
    if (faces.length > 1) {
      throw const FaceDetectionException(FaceDetectionError.multipleFaces);
    }

    // 0 caras: probar giros por si CameraX guardó la foto con orientación
    // incorrecta. Girar no recorta ni pierde parte del rostro.
    final rotated = await _tryRotations(imagePath);
    if (rotated != null) return rotated;
    throw const FaceDetectionException(FaceDetectionError.noFace);
  }

  Future<String?> _tryRotations(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final upright = img.bakeOrientation(decoded);
      _logImageInfo(bytes, decoded, upright);

      for (final angle in const [90, 180, 270]) {
        final rotated = img.copyRotate(upright, angle: angle);
        final path = _tempPath(imagePath, 'rot$angle');
        await File(path).writeAsBytes(img.encodeJpg(rotated, quality: 95));
        final rotatedFaces = await _detect(path);
        _logFaces('rotado $angle°', rotatedFaces);
        if (rotatedFaces.length == 1) return path;
        await _delete(path);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MLKit: error probando rotaciones: $e');
      }
    }
    return null;
  }

  String _tempPath(String sourcePath, String suffix) {
    return p.join(
      p.dirname(sourcePath),
      'face_${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  void _logFaces(String label, List<Face> faces) {
    if (kDebugMode) {
      debugPrint('MLKit: $label -> ${faces.length} cara(s)');
      for (final face in faces) {
        final box = face.boundingBox;
        debugPrint(
          'MLKit: caja ${box.left.toStringAsFixed(0)},'
          '${box.top.toStringAsFixed(0)} '
          '${box.width.toStringAsFixed(0)}x${box.height.toStringAsFixed(0)}',
        );
      }
    }
  }

  void _logImageInfo(Uint8List bytes, img.Image decoded, img.Image upright) {
    if (kDebugMode) {
      final hasEoi =
          bytes.length >= 2 &&
          bytes[bytes.length - 2] == 0xFF &&
          bytes[bytes.length - 1] == 0xD9;
      final small = img.copyResize(upright, width: 32);
      var sum = 0.0;
      var count = 0;
      for (final pixel in small) {
        sum += (pixel.r + pixel.g + pixel.b) / 3;
        count++;
      }
      final brightness = count == 0 ? 0.0 : sum / count;
      debugPrint(
        'MLKit: archivo ${bytes.length} bytes, EOI=$hasEoi, '
        'crudo ${decoded.width}x${decoded.height}, '
        'orientado ${upright.width}x${upright.height}, '
        'brillo ${brightness.toStringAsFixed(1)}',
      );
    }
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
