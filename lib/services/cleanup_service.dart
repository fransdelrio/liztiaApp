import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';
import 'face_service.dart';

class CleanupService {
  CleanupService._();

  static const _imageExtensions = {'.jpg', '.jpeg', '.png'};

  /// Limpieza de arranque: borra caras sin persona y fotos temporales.
  static Future<void> run({
    FaceService? faceService,
    DatabaseService? databaseService,
  }) async {
    final faces = faceService ?? FaceService();
    final db = databaseService ?? DatabaseService.instance;
    await deleteOrphanFaces(faceService: faces, databaseService: db);
    await deleteCapturedPhotos();
  }

  /// Borra de face_verification los IDs que ya no existen en `persons`.
  ///
  /// Tras una instalación limpia `persons` puede estar vacío, así que esto
  /// elimina las caras sin persona. Es idempotente y se reintenta en cada
  /// arranque si una ejecución falla.
  static Future<void> deleteOrphanFaces({
    FaceService? faceService,
    DatabaseService? databaseService,
  }) async {
    final faces = faceService ?? FaceService();
    final db = databaseService ?? DatabaseService.instance;
    try {
      final personIds = await db.getAllPersonIds();
      final faceIds = await faces.getAllRegisteredUsers();
      for (final id in faceIds) {
        final personaId = int.tryParse(id);
        if (personaId == null || !personIds.contains(personaId)) {
          try {
            await faces.deleteUserFaces(id);
            debugPrint('Limpieza: cara huérfana borrada ($id)');
          } catch (e) {
            debugPrint('Limpieza: no se pudo borrar la cara $id: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Limpieza: no se pudieron reconciliar las caras: $e');
    }
  }

  /// Borra las fotos capturadas que hayan quedado en el directorio temporal.
  static Future<void> deleteCapturedPhotos() async {
    try {
      final dir = await getTemporaryDirectory();
      if (!await dir.exists()) return;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        if (!_imageExtensions.contains(
          p.extension(entity.path).toLowerCase(),
        )) {
          continue;
        }
        await deletePhoto(entity.path);
      }
    } catch (e) {
      debugPrint('Limpieza: no se pudieron borrar las fotos temporales: $e');
    }
  }

  static Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<void> deletePhotos(Iterable<String> paths) async {
    for (final path in paths) {
      await deletePhoto(path);
    }
  }
}
