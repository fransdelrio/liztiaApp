import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/cleanup_service.dart';
import '../services/database_service.dart';
import '../services/face_service.dart';
import '../models/history_record.dart';
import '../models/person.dart';
import '../utils/date_formats.dart';
import '../widgets/liztia_app_bar.dart';
import 'register_screen.dart';

enum _ScanStatus { idle, scanning, match, noMatch, registrationSuccess }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _matchFreeze = Duration(seconds: 3);
  static const _registrationFreeze = Duration(seconds: 3);
  static const _maxCameraAttempts = 3;
  static const _cameraRetryDelay = Duration(milliseconds: 400);

  CameraController? _controller;
  final FaceService _faceService = FaceService();
  _ScanStatus _status = _ScanStatus.idle;
  bool _initializing = false;
  String? _cameraError;
  bool _scanError = false;
  String _matchedName = '';
  String _matchedLastName = '';
  Timer? _resultTimer;
  String? _pendingPhotoPath;
  String? _frozenPhotoPath;
  Size? _frozenPreviewSize;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() => _cameraError = 'Permiso de cámara denegado');
        }
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'No se encontró ninguna cámara');
        }
        return;
      }
      // Sin audio: la app solo captura fotos y no debe pedir micrófono.
      final controller = CameraController(
        _pickCamera(cameras),
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) {
        setState(() => _cameraError = null);
      }
    } catch (e) {
      debugPrint('Cámara no disponible: $e');
      if (mounted) {
        setState(() => _cameraError = 'No se pudo iniciar la cámara');
      }
    } finally {
      _initializing = false;
    }
  }

  /// Libera el controller activo. `camera_android_camerax` puede lanzar si el
  /// preview todavía no registró su surface producer: nunca debe propagarse.
  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('Liberación de cámara falló: $e');
    }
  }

  /// Abre la cámara reintentando con espera exponencial: al volver de otra
  /// pantalla CameraX a veces todavía no liberó el hardware y el preview
  /// quedaría congelado.
  Future<void> _initCameraWithRetry() async {
    for (var attempt = 0; attempt < _maxCameraAttempts; attempt++) {
      await _initCamera();
      if (!mounted) return;
      if (_controller?.value.isInitialized ?? false) return;
      if (attempt == _maxCameraAttempts - 1) return;
      setState(() => _cameraError = null);
      // El intento fallido pudo dejar un controller sin inicializar.
      await _releaseCamera();
      await Future<void>.delayed(_cameraRetryDelay * (1 << attempt));
    }
  }

  /// Reinicia la cámara: en algunos dispositivos CameraX deja el preview
  /// congelado después de `takePicture()`.
  Future<void> _restartCamera() async {
    if (_initializing) return;
    await _releaseCamera();
    if (mounted) setState(() {});
    await _initCameraWithRetry();
  }

  CameraDescription _pickCamera(List<CameraDescription> cameras) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  Future<void> _scan() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _status == _ScanStatus.scanning ||
        _status == _ScanStatus.match ||
        _status == _ScanStatus.registrationSuccess) {
      return;
    }
    setState(() {
      _status = _ScanStatus.scanning;
      _scanError = false;
      _matchedName = '';
      _matchedLastName = '';
    });
    try {
      final picture = await _controller!.takePicture();
      _pendingPhotoPath = picture.path;
      final res = await _faceService.verify(picture.path);
      if (!mounted) {
        await _discardPendingPhoto();
        return;
      }
      final personaId = int.tryParse(res ?? '');
      final person = personaId == null
          ? null
          : await DatabaseService.instance.getPersonById(personaId);
      if (person == null) {
        await _discardPendingPhoto();
        if (!mounted) return;
        setState(() {
          _status = _ScanStatus.noMatch;
        });
        return;
      }
      final now = DateTime.now();
      await DatabaseService.instance.insertHistory(
        HistoryRecord(
          fecha: DateFormats.fecha(now),
          personaId: person.id,
          apellido: person.apellido,
          nombre: person.nombre,
          timestamp: DateFormats.timestamp(now),
        ),
      );
      final photoPath = _pendingPhotoPath;
      _pendingPhotoPath = null;
      if (!mounted) {
        await CleanupService.deletePhoto(photoPath);
        return;
      }
      setState(() {
        _matchedName = person.nombre;
        _matchedLastName = person.apellido;
        _frozenPhotoPath = photoPath;
        _frozenPreviewSize = _controller?.value.previewSize;
        _status = _ScanStatus.match;
      });
      _resultTimer?.cancel();
      _resultTimer = Timer(_matchFreeze, _finishResult);
    } catch (e) {
      debugPrint('Escaneo falló: $e');
      await _discardPendingPhoto();
      if (!mounted) return;
      setState(() {
        _status = _ScanStatus.noMatch;
        _scanError = true;
      });
    }
  }

  Future<void> _discardPendingPhoto() async {
    final path = _pendingPhotoPath;
    _pendingPhotoPath = null;
    await CleanupService.deletePhoto(path);
  }

  /// Tras un registro exitoso muestra el éxito 3 s y vuelve a la cámara.
  Future<void> _openRegistration() async {
    // La cámara se libera antes de navegar: RegisterScreen necesita el
    // hardware y dos controllers vivos dejan el preview congelado.
    await _releaseCamera();
    if (!mounted) return;
    setState(() => _status = _ScanStatus.idle);
    final person = await Navigator.push<Person>(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
    if (!mounted) return;
    // Al volver de cualquier navegación el estado arranca siempre en idle.
    setState(() => _status = _ScanStatus.idle);
    if (person == null) {
      // Vuelta sin registro exitoso: reabrir la cámara (con reintentos) antes
      // de permitir otro escaneo.
      await _restartCamera();
      return;
    }
    _resultTimer?.cancel();
    setState(() {
      _status = _ScanStatus.registrationSuccess;
      _matchedName = person.nombre;
      _matchedLastName = person.apellido;
    });
    _resultTimer = Timer(_registrationFreeze, _finishResult);
  }

  /// Vuelve a la cámara en vivo tras el resultado (3 s en match y registro).
  Future<void> _finishResult() async {
    _resultTimer = null;
    final photoPath = _frozenPhotoPath;
    if (!mounted) {
      await CleanupService.deletePhoto(photoPath);
      return;
    }
    setState(() {
      _status = _ScanStatus.idle;
      _matchedName = '';
      _matchedLastName = '';
      _frozenPhotoPath = null;
      _frozenPreviewSize = null;
    });
    await CleanupService.deletePhoto(photoPath);
    await _restartCamera();
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    unawaited(CleanupService.deletePhoto(_pendingPhotoPath));
    unawaited(CleanupService.deletePhoto(_frozenPhotoPath));
    unawaited(_releaseCamera());
    super.dispose();
  }

  Widget _buildLivePreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: isPortrait ? previewSize.height : previewSize.width,
          height: isPortrait ? previewSize.width : previewSize.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildFrozenPreview(String path) {
    final previewSize = _frozenPreviewSize;
    // La foto se muestra a lo sumo del ancho de pantalla: no decodificar el
    // JPEG a resolución completa.
    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    final image = Image.file(
      File(path),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: cacheWidth,
    );
    if (previewSize == null) {
      return image;
    }
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: isPortrait ? previewSize.height : previewSize.width,
          height: isPortrait ? previewSize.width : previewSize.height,
          child: image,
        ),
      ),
    );
  }

  /// La cámara queda siempre montada y la foto congelada se superpone encima,
  /// de modo que el rectángulo y encuadre no cambian entre estados.
  Widget _buildPreviewArea() {
    final frozenPath = _frozenPhotoPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildLivePreview(),
        if (frozenPath != null) _buildFrozenPreview(frozenPath),
      ],
    );
  }

  /// Intercepta el "back" del sistema: el estado vuelve a idle y la cámara se
  /// libera para que ningún controller sobreviva a la navegación.
  void _onPopInvoked(bool didPop, Object? result) {
    if (!didPop) return;
    _resultTimer?.cancel();
    _resultTimer = null;
    _status = _ScanStatus.idle;
    unawaited(_releaseCamera());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: _onPopInvoked,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    if (_status == _ScanStatus.registrationSuccess) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Scaffold(
        appBar: const LiztiaAppBar(title: 'Escanear'),
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Registro Exitoso!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 32),
                Icon(Icons.check_circle, color: scheme.primary, size: 64),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '$_matchedName $_matchedLastName'.trim(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final cameraError = _cameraError;
    if (cameraError != null) {
      final theme = Theme.of(context);
      return Scaffold(
        appBar: const LiztiaAppBar(title: 'Escanear'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    cameraError,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _cameraError = null);
                      _initCamera();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if ((_controller == null || !_controller!.value.isInitialized) &&
        _frozenPhotoPath == null) {
      return const Scaffold(
        appBar: LiztiaAppBar(title: 'Escanear'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isMatch = _status == _ScanStatus.match;
    final hasNoMatch = _status == _ScanStatus.noMatch;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const LiztiaAppBar(title: 'Escanear'),
      body: SafeArea(
        child: Column(
          children: [
            // 60% superior: cámara.
            Expanded(flex: 3, child: _buildPreviewArea()),
            // 40% inferior: resultado y botones.
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            if (isMatch) ...[
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  '$_matchedName $_matchedLastName'.trim(),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                            if (hasNoMatch) ...[
                              Text(
                                _scanError
                                    ? 'No se pudo completar el escaneo'
                                    : 'No ha sido posible identificar',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (!_scanError) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonalIcon(
                                    onPressed: _openRegistration,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Registrar'),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!isMatch) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              (_status == _ScanStatus.scanning ||
                                  _status == _ScanStatus.match)
                              ? null
                              : _scan,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            _status == _ScanStatus.scanning
                                ? 'Escaneando...'
                                : 'Escanear',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Volver'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
