import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Mantiene el splash nativo hasta que Flutter tenga lista la misma imagen.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  // Carga el tema persistido antes del primer frame para evitar el destello claro.
  await ThemeController.instance.load();
  runApp(const App());
}
