import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/history_record.dart';
import '../models/person.dart';
import '../services/cleanup_service.dart';
import '../services/database_service.dart';
import '../services/face_service.dart';
import '../utils/date_formats.dart';
import '../utils/name_input_formatters.dart';
import '../widgets/liztia_app_bar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _maxPhotos = 3;
  static const double _thumbSize = 56;

  CameraController? _controller;
  final FaceService _faceService = FaceService();
  int _count = 0;
  final List<String> _photos = [];
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _apellido = TextEditingController();
  bool _registering = false;
  bool _validating = false;
  bool _initializing = false;
  String? _cameraError;

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

  /// Reinicia la cámara: en algunos dispositivos CameraX deja el preview
  /// congelado después de `takePicture()`.
  Future<void> _restartCamera() async {
    if (!mounted || _initializing) return;
    await _releaseCamera();
    if (mounted) setState(() {});
    await _initCamera();
  }

  CameraDescription _pickCamera(List<CameraDescription> cameras) {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  Future<void> _takePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _count >= _maxPhotos ||
        _validating) {
      return;
    }
    setState(() {
      _validating = true;
    });
    String? captured;
    try {
      final picture = await _controller!.takePicture();
      captured = picture.path;
      await _faceService.validatePhoto(captured);
      if (!mounted) {
        await CleanupService.deletePhoto(captured);
        return;
      }
      setState(() {
        _photos.add(captured!);
        _count++;
      });
    } catch (e) {
      debugPrint('Foto ${_count + 1}/$_maxPhotos rechazada: $e');
      if (captured != null) {
        await CleanupService.deletePhoto(captured);
      }
      _showMessage(_errorMessage(e, _count + 1));
    } finally {
      if (mounted) {
        setState(() {
          _validating = false;
        });
      }
      if (_count < _maxPhotos) {
        await _restartCamera();
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resetPhotos() async {
    if (!mounted) return;
    final photos = List<String>.of(_photos);
    setState(() {
      _photos.clear();
      _count = 0;
    });
    await CleanupService.deletePhotos(photos);
    await _restartCamera();
  }

  String _errorMessage(Object error, int photoIndex) {
    if (error is FaceDetectionException) {
      return switch (error.error) {
        FaceDetectionError.multipleFaces =>
          'Hay más de un rostro en la foto $photoIndex/$_maxPhotos. '
              'Aléjate de otras personas o fotos y repite esa foto.',
        FaceDetectionError.noFace =>
          'No se detectó un rostro en la foto $photoIndex/$_maxPhotos. '
              'Mejora la luz y repite esa foto.',
      };
    }
    return 'No se pudo registrar: $error';
  }

  Future<void> _save() async {
    if (_registering) return;
    if (_photos.length != _maxPhotos) {
      _showMessage('Debes tomar las $_maxPhotos fotos');
      return;
    }
    final nombre = _nombre.text.trim().toUpperCase();
    final apellido = _apellido.text.trim().toUpperCase();
    if (nombre.isEmpty || apellido.isEmpty) {
      _showMessage('Ingresa nombre y apellido');
      return;
    }
    setState(() {
      _registering = true;
    });
    final personaIdStr = DateTime.now().millisecondsSinceEpoch.toString();
    int photoIndex = 0;
    var registrationSaved = false;
    try {
      for (final p in _photos) {
        photoIndex++;
        await _faceService.register(
          id: personaIdStr,
          imagePath: p,
          imageId: '${personaIdStr}_$photoIndex',
          name: '$nombre $apellido',
        );
      }
      final personaId = int.parse(personaIdStr);
      final now = DateTime.now();
      final person = Person(id: personaId, nombre: nombre, apellido: apellido);
      await DatabaseService.instance.saveRegistration(
        person: person,
        history: HistoryRecord(
          fecha: DateFormats.fecha(now),
          personaId: personaId,
          apellido: apellido,
          nombre: nombre,
          timestamp: DateFormats.timestamp(now),
        ),
      );
      registrationSaved = true;
      final photos = List<String>.of(_photos);
      _photos.clear();
      await CleanupService.deletePhotos(photos);
      if (mounted) {
        Navigator.pop(context, person);
      }
    } catch (e) {
      debugPrint('Registro falló en foto $photoIndex/$_maxPhotos: $e');
      // Si falló una foto o la DB, borrar las caras ya registradas de este
      // intento para no dejar personas huérfanas en la base.
      if (!registrationSaved) {
        try {
          await _faceService.deleteUserFaces(personaIdStr);
        } catch (_) {}
      }
      final message = _errorMessage(e, photoIndex);
      _showMessage(message);
      if (!registrationSaved && !message.startsWith('No se pudo')) {
        await _resetPhotos();
      }
    } finally {
      if (mounted) {
        setState(() {
          _registering = false;
        });
      }
    }
  }

  @override
  void dispose() {
    final photos = List<String>.of(_photos);
    _photos.clear();
    unawaited(CleanupService.deletePhotos(photos));
    unawaited(_releaseCamera());
    _nombre.dispose();
    _apellido.dispose();
    super.dispose();
  }

  /// Intercepta el "back" del sistema: libera la cámara y navega manualmente
  /// para que el controller no quede vivo al volver a ScanScreen.
  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    // No abandonar la pantalla con un registro en curso.
    if (_registering) return;
    await _releaseCamera();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final cameraError = _cameraError;
    if (cameraError != null) {
      final theme = Theme.of(context);
      return Scaffold(
        appBar: const LiztiaAppBar(title: 'Registrar'),
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
    final controller = _controller;
    final cameraReady = controller != null && controller.value.isInitialized;
    final theme = Theme.of(context);
    // La miniatura mide 56 px lógicos: decodificar el JPEG a esa resolución
    // (en píxeles físicos) en lugar de a tamaño completo.
    final thumbCacheWidth =
        (_thumbSize * MediaQuery.devicePixelRatioOf(context)).round();
    return Scaffold(
      appBar: const LiztiaAppBar(title: 'Registrar'),
      body: Column(
        children: [
          Expanded(
            child: cameraReady
                ? CameraPreview(controller)
                : const ColoredBox(
                    color: Colors.black,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_count/$_maxPhotos',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (_photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final photo in _photos)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Image.file(
                        File(photo),
                        width: _thumbSize,
                        height: _thumbSize,
                        fit: BoxFit.cover,
                        cacheWidth: thumbCacheWidth,
                      ),
                    ),
                ],
              ),
            ),
          if (_count > 0 && !_registering && !_validating)
            TextButton.icon(
              onPressed: _resetPhotos,
              icon: const Icon(Icons.refresh),
              label: const Text('Repetir fotos'),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_count < _maxPhotos)
                  FilledButton.icon(
                    onPressed: (_validating || !cameraReady)
                        ? null
                        : _takePhoto,
                    icon: const Icon(Icons.camera),
                    label: Text(_validating ? 'Verificando...' : 'Tomar foto'),
                  )
                else ...[
                  TextField(
                    controller: _nombre,
                    enabled: !_registering,
                    maxLength: 20,
                    inputFormatters: [SpanishNameInputFormatter(maxLength: 20)],
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  TextField(
                    controller: _apellido,
                    enabled: !_registering,
                    maxLength: 20,
                    inputFormatters: [SpanishNameInputFormatter(maxLength: 20)],
                    decoration: const InputDecoration(labelText: 'Apellido'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _registering ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_registering ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
