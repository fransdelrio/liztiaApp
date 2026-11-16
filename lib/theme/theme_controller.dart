import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Preferencia de tema persistida en `theme_mode.txt` dentro del directorio de
/// soporte de la app (sin `shared_preferences`, todo offline).
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  /// Instancia aislada para tests: mismo comportamiento que [instance] pero sin
  /// compartir el `ThemeMode` global. La persistencia sigue intentándose; en el
  /// entorno de test falla y queda absorbida por `_persist`.
  @visibleForTesting
  factory ThemeController.test() => ThemeController._();

  static const String fileName = 'theme_mode.txt';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Lee la preferencia guardada. Si no existe o falla, mantiene el modo claro.
  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final raw = (await file.readAsString()).trim().toLowerCase();
      final mode = switch (raw) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => null,
      };
      if (mode != null && mode != _themeMode) {
        _themeMode = mode;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Tema: no se pudo leer la preferencia: $e');
    }
  }

  /// Cola de escrituras: serializa los guardados para que un doble toque
  /// rápido no deje en disco un valor distinto al `ThemeMode` vigente.
  Future<void> _writes = Future<void>.value();

  /// Alterna claro/oscuro y persiste el resultado.
  void toggle() {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    _themeMode = next;
    notifyListeners();
    unawaited(_enqueuePersist(next));
  }

  /// Encola la escritura del [mode] capturado y devuelve el final de la cola.
  Future<void> _enqueuePersist(ThemeMode mode) {
    _writes = _writes.then(
      (_) => _persist(mode),
      onError: (Object _) => _persist(mode),
    );
    return _writes;
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        mode == ThemeMode.dark ? 'dark' : 'light',
        flush: true,
      );
    } catch (e) {
      debugPrint('Tema: no se pudo guardar la preferencia: $e');
    }
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, fileName));
  }
}
