# Architecture

## Patrón
Separación por capas: UI (screens/widgets), Lógica (services), Datos (models), Utilidades (utils).

## Estructura
Ver `AGENTS.md` para estructura detallada de `lib/`.

## Dependencias clave
- `face_verification` ^0.3.6: reconocimiento facial y almacenamiento de embeddings
- `camera`: captura
- `sqflite` + `path`: persistencia `persons` + `history`
- `path_provider`: directorio temporal para limpieza de fotos
- `permission_handler`: permisos

## Persistencia
- SQLite (esquema v1, sin migraciones): `persons` (identidad) + `history` (snapshot).
- `face_verification` guarda embeddings, no fotos.
- Relación lógica `history.persona_id → persons.id`; sin FK.

## Ciclo de vida
- Arranque: splash nativo (`flutter_native_splash`) + `SplashScreen` Dart (`assets/images/splash-screen.jpg`) que ejecuta `FaceService.init()` → abrir DB (crea el esquema si no existe) → `CleanupService.run()` y luego navega a Home.
- Limpieza: caras sin persona + imágenes temporales.
- Registro: caras → `persons` + `history` transaccional.
- Escaneo: verificación → lookup en `persons` → historial snapshot o no-match.
- Fotos: borrado tras uso y barrido al iniciar.

## Restricciones
- 100% offline
- Solo permiso CAMERA
- minSdk 29, iOS 12.0
- Sin caras, IDs ni fotos huérfanas
