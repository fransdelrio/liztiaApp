import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../services/cleanup_service.dart';
import '../services/database_service.dart';
import '../services/face_service.dart';
import 'home_screen.dart';

/// Splash con la imagen de marca mientras se prepara el motor facial,
/// la base de datos y la limpieza de arranque.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _splashAsset = 'assets/images/splash-screen.jpg';

  bool _loading = true;
  Object? _error;
  Brightness? _overlayBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La barra de estado sigue al brillo del tema en vez de fijar un estilo
    // incondicional: `light` en claro y `dark` en oscuro.
    final brightness = Theme.of(context).brightness;
    if (brightness == _overlayBrightness) return;
    _overlayBrightness = brightness;
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    );
  }

  Future<void> _bootstrap() async {
    if (!_loading || _error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // La imagen debe estar decodificada antes de retirar el splash nativo
      // para que el relevo no muestre un frame en blanco.
      await precacheImage(const AssetImage(_splashAsset), context);
      FlutterNativeSplash.remove();
      final faceService = FaceService();
      await faceService.init();
      await DatabaseService.instance.open();
      await CleanupService.run(faceService: faceService);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      debugPrint('Arranque falló: $e');
      FlutterNativeSplash.remove();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = _error;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _splashAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          if (!_loading && error != null)
            ColoredBox(
              color: scheme.surface.withValues(alpha: 0.92),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No se pudo iniciar la aplicación',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _bootstrap,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
