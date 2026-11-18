# liztia

Aplicación Flutter de verificación facial 100% offline.

## Funcionalidad
- Identificación facial con cámara.
- Registro de personas con 3 fotos.
- Historial local en SQLite con filtro por fecha.
- Sin servicios en la nube.

## Estructura
Ver `AGENTS.md` para stack, arquitectura, esquema SQLite y flujo.

## Comandos
```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
flutter build apk --release
```

## Build release
- Salida: `build/app/outputs/flutter-apk/app-release.apk` (~167 MB).
- ABIs incluidas: `arm64-v8a` y `armeabi-v7a`. Sin `x86_64`: no instala en emuladores PC.
- El tamaño lo dominan `facenet.tflite` (89,6 MB) y las librerías nativas de Flutter/ML Kit.
