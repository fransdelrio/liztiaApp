# AGENTS.md

## Objetivo
Aplicación Flutter **liztia** para verificación facial 100% offline. Permite identificar personas mediante reconocimiento facial, registrar nuevas con 3 fotos y guardar un historial local de escaneos y registros.

## Stack
- **Framework:** Flutter (Dart)
- **Reconocimiento facial:** `face_verification` ^0.3.6
- **Detección facial previa:** `google_mlkit_face_detection` ^0.15.1 (validación de un solo rostro antes de registrar)
- **Cámara:** `camera` ^0.11.0+2
- **Permisos:** `permission_handler` ^11.3.1
- **Base de datos local:** `sqflite` ^2.4.1 + `path` ^1.9.1
- **Archivos temporales:** `path_provider` ^2.1.6
- **Procesado de imagen:** `image` ^4.12.0 (rotaciones para MLKit)
- **Splash e iconos:** `flutter_native_splash` ^2.4.8; `flutter_launcher_icons` ^0.14.4 (dev)
- **Modo:** 100% offline (sin Firebase ni servicios en la nube)
- **Plataformas:** Android (minSdk 29) / iOS (platform 12.0)
- **Package/Org:** `cc.makico`
- **Nombre del proyecto:** `liztia`

## Restricciones
- **Offline estricto:** No utilizar Firebase, APIs externas ni cualquier servicio de nube.
- **Permisos mínimos:** Solo `CAMERA` es necesario.
- **Historial obligatorio:** Insertar en el historial tanto en un match exitoso como en un registro nuevo.
- **Sin huérfanos:** No deben quedar caras/IDs sin persona ni fotos temporales tras el uso.
- **API nativa fija:** Respetar `minSdk 29` y `iOS 12.0`.

## Arquitectura y estructura
```
lib/
├── app.dart
├── main.dart
├── models/
│   ├── person.dart
│   └── history_record.dart
├── services/
│   ├── database_service.dart   # SQLite (persons + history)
│   ├── face_service.dart       # Wrapper de face_verification
│   └── cleanup_service.dart    # Reconciliación de caras y fotos
├── screens/
│   ├── splash_screen.dart
│   ├── home_screen.dart
│   ├── scan_screen.dart
│   ├── register_screen.dart
│   └── history_screen.dart
├── theme/
│   ├── app_theme.dart          # ThemeData M3 claro/oscuro + estilos de botón
│   └── theme_controller.dart   # ThemeMode + persistencia (theme_mode.txt)
├── utils/
│   └── date_formats.dart
└── widgets/
    ├── liztia_app_bar.dart     # AppBar común (título + toggle de tema)
    └── theme_toggle_button.dart

assets/
└── images/
    └── splash-screen.jpg   # Splash vertical (BoxFit.cover)
```

## Base de datos (SQLite)
Tabla `persons`
| Campo | Tipo | Descripción |
| :-- | :-- | :-- |
| `id` | INTEGER PRIMARY KEY | Mismo ID que `face_verification` |
| `nombre` | TEXT | Nombre |
| `apellido` | TEXT | Apellido |

Tabla `history`
| Campo | Tipo | Descripción |
| :-- | :-- | :-- |
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | ID numérico autoincremental |
| `fecha` | TEXT | Fecha en formato `YYYY-MM-DD` |
| `persona_id` | INTEGER | ID de la persona identificada/registrada |
| `apellido` | TEXT | Apellido (snapshot del momento) |
| `nombre` | TEXT | Nombre (snapshot del momento) |
| `timestamp` | TEXT | Timestamp en formato `YYYYMMDDhhmmss` |

Reglas:
- `history.persona_id` referencia lógicamente a `persons.id` (sin FK).
- Sin versiones en producción: no hay migraciones de datos. `_dbVersion = 1`.
- Esquema inicial (`onCreate`): `persons`, `history` e `idx_history_fecha`.
- Un cambio de esquema se aplica reinstalando la app (borrar datos en desarrollo).
- Añadir `onUpgrade` o cualquier migración requiere autorización explícita del responsable.
- Registro nuevo: `persons` + `history` en una sola transacción.
- Match: lookup en `persons`; sin persona no hay match ni historial.
- El historial mantiene nombre/apellido como snapshot.

## Flujo de la app
0. **Boot (`main.dart`)** - `main` async: `WidgetsFlutterBinding.ensureInitialized()` → `FlutterNativeSplash.preserve()` → `await ThemeController.instance.load()` (carga el `ThemeMode` persistido **antes** de `runApp`, fix M1: evita el destello claro al arrancar en oscuro) → `runApp(const App())`.
1. **Arranque (`splash_screen.dart`)** - Splash nativo (`flutter_native_splash`) con la imagen de marca + `SplashScreen` Dart con la misma imagen a pantalla completa (`BoxFit.cover`) para que el relevo sea invisible. Mientras se muestra ejecuta `FaceService.init()` → abrir DB → `CleanupService.run()`; usa `precacheImage` + `FlutterNativeSplash.remove()` y luego navega a Home (sin retardo artificial). Si falla, muestra `Reintentar`.
2. **Inicio (`home_screen.dart`)** - Título + botones `"Iniciar"` e `"Historial"`.
3. **Escaneo (`scan_screen.dart`)** - Cámara + botón `"Escanear"` + botón `"Volver"` abajo.
4. **Match exitoso** - Resolver `persona_id` en `persons`; mostrar `nombre` + `apellido` + ✅ durante 3 s (ocultando `"Escanear"`/`"Volver"`) e insertar historial con snapshot.
5. **Sin coincidencia o ID sin persona** - Mostrar `"No ha sido posible identificar"` con botones `"Escanear"` (reintentar) y `"Registrar"`. No insertar historial.
6. **Registro (`register_screen.dart`)** - 3 fotos con contador y validación de un solo rostro; nombre/apellido; registrar caras; guardar `persons` + `history`; borrar fotos. Al volver, `scan_screen` muestra una pantalla del color `colorScheme.surface` (blanca en claro, oscura en oscuro) con `"Registro Exitoso!"` + nombre/apellido + ✅ durante 3 s y después restaura la cámara con `"Escanear"` y `"Volver"`. Si se vuelve **sin** registro exitoso, `_openRegistration` reinicia la cámara con `_restartCamera()` (el preview puede quedar congelado al recuperar el foco tras `Navigator.push`).
7. **Historial (`history_screen.dart`)** - Filtro por fecha (día anterior/siguiente y selector).

## Limpieza
- Al iniciar, `SplashScreen`: `FaceService.init()` → abrir DB (crea el esquema si no existe) → `CleanupService.run()`; después navega a Home.

## Tema y UI
- Detalle completo (paleta, toggle luna/sol, `LiztiaAppBar`, estilos de botón): ver `docs/tema-y-ui.md`.
- **Botones centralizados en `ThemeData`** (`lib/theme/app_theme.dart`): misma forma (radio 16), altura mínima 48, padding 20x14 y `iconSize` 20 para `FilledButton`, `OutlinedButton`, `TextButton` y `ElevatedButton`. Uso en pantallas: `FilledButton.icon` (primaria), `OutlinedButton.icon` (secundaria), `TextButton.icon` (terciaria) y `FilledButton.tonalIcon` para "Registrar" en `scan_screen.dart`.

## Splash e iconos
- **Nativo (`flutter_native_splash.yaml`)**: `< Android 12` muestra `assets/images/splash-screen.jpg` a pantalla completa; `Android 12+` usa fondo blanco + `assets/images/splash-icon.png` (limitación de la SplashScreen API).
- **Dart**: `SplashScreen` mantiene la misma imagen y la retira cuando el primer frame está pintado (`precacheImage` + `FlutterNativeSplash.remove()`), evitando el flash blanco.
- **Icono de app**: `flutter_launcher_icons` con `assets/images/splash-icon.png` (legacy + adaptive icon), sin logo de Flutter.
- **Barra de estado**: visible; en el splash los iconos siguen al brillo del tema (`SystemUiOverlayStyle.light` en claro, `dark` en oscuro) y en las pantallas al `AppBarTheme.systemOverlayStyle` de `lib/theme/app_theme.dart`.
- **Regenerar**: `dart run flutter_native_splash:create` y `dart run flutter_launcher_icons`. Tras regenerar, mover `res/drawable/background.png` a `res/drawable-nodpi/` para evitar el reescalado por densidad.
- `CleanupService` borra caras de IDs que no existen en `persons`. En el primer arranque tras instalar esto elimina las caras sin persona.
- Las fotos capturadas se borran tras el escaneo (inmediato o al terminar el freeze) y tras el registro (éxito, repetir o salir).
- Al iniciar se barren imágenes temporales (`jpg`, `jpeg`, `png`).

## Configuración nativa
- **Android (`android/app/build.gradle.kts`)**: `minSdk = 29`, `ndk.abiFilters` = `armeabi-v7a`, `arm64-v8a` (sin `x86_64`: no soporta emuladores PC).
- **`android/build.gradle.kts`**: Java/Kotlin alineados a 17 en todos los subproyectos.
- **AndroidManifest.xml**: solo `CAMERA`. Con `tools:node="remove"` se eliminan `RECORD_AUDIO`, `READ_PHONE_STATE`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `ACCESS_NETWORK_STATE` e `INTERNET` (este último solo en release; `src/debug` y `src/profile` lo vuelven a declarar para el tooling de Flutter).
- **iOS (`ios/Podfile`)**: `platform :ios, '12.0'` (se genera en macOS con `pod install`).
- **iOS (`ios/Runner/Info.plist`)**: `NSCameraUsageDescription`.

## Convenciones de desarrollo
- **Archivos:** `snake_case.dart`
- **Clases/Widgets:** `PascalCase`
- **Separación:** UI en `screens/`, lógica en `services/`, datos en `models/`, utilidades en `utils/`, componentes en `widgets/`.
- **Asincronía:** `async/await`; manejar permisos con `permission_handler`.
- **Rendimiento:** usar `const` cuando sea posible.
- **SQLite:** toda la lógica en `DatabaseService`; `fecha` `YYYY-MM-DD`, `timestamp` `YYYYMMDDhhmmss`.
- **Facial:** toda la lógica de `face_verification` en `FaceService`.
- **Archivos:** toda foto capturada debe borrarse con `CleanupService`.

## Configuración de agentes (OpenCode V2)
- **Agentes:** `.opencode/agents/<id>.md` con frontmatter V2 (`description`, `mode`, `model`, `permissions`, `steps`, `color`). El cuerpo Markdown es el `system` prompt.
- **Skills:** `.opencode/skills/<id>/SKILL.md` (o `<id>.md` en la raíz de `skills/`). El ID sale del directorio, en kebab-case. `description` es obligatoria para que el modelo lo descubra.
- **Variantes de modelo y `default_agent`:** `opencode.jsonc` en la raíz. `temperature`/`top_p` **no** existen a nivel de agente en V2: van en `providers.<provider>.models.<modelo>.variants[].body` y se referencian como `provider/modelo#variante`.
- **Campos legacy prohibidos:** `agent` (singular), `permission`, `task`, `system_prompt`, `allowed_skills`, `temperature`/`top_p` a nivel de agente.
- **Permisos:** lista ordenada de `{action, resource, effect}`; la última regla que coincide gana. La acción para delegar es `subagent` (no `task`); para skills es `skill`.
- **`.agents/` no se usa:** en V2 no es una ruta de agentes (solo compatibilidad de skills). Queda como `.agents.bak/` de rollback.
- **Agentes del proyecto:** `ag_coordinator` (primary, delega), `ag_developer` (implementación), `ag_flutter_bug_hunter` (diagnóstico, solo skill `analyze-flutter-logs`), `ag_documentator` (documentación), `ag_code_reviewer` (revisión Dart/Flutter, solo lectura), `ag_qa` (quality gate, solo ejecuta y reporta).
- **Autogestión prohibida:** ningún agente edita su propia configuración ni la de otros. Los cambios en `.opencode/agents/*` los aplica el humano (o **Build** con autorización explícita). `ag_coordinator` solo orquesta y delega: no edita, no escribe y no ejecuta shell.
- **Verificación:** `opencode api get /api/agent --standalone` debe listar los agentes con el `mode` y `model` esperados. La configuración se recarga al guardar; `/reload` fuerza la recarga completa.

## Comandos útiles
```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

## Reglas para agentes IA
- **Alcance estricto:** No acceder a archivos fuera del directorio del proyecto sin preguntar.
- **Sin inspección del sistema:** No ejecutar comandos como `whoami`, `hostname`, `systeminfo`, etc.
- **Sin configs ajenas:** No leer archivos de configuración de OpenCode u otras herramientas.
- **Respetar decisiones duras:** Seguir stack, flujo, esquema SQLite y restricciones (100% offline, minSdk 29, sin huérfanos).
- **Código coherente:** Mantener estilo, nomenclatura y arquitectura definidos aquí.
- **Sin inventar servicios:** No añadir dependencias cloud. Solo las listadas en el stack.
- **Sin migraciones no autorizadas:** No añadir `onUpgrade`, bumps de `_dbVersion` ni lógica de migración de datos sin autorización explícita. El esquema es recreable en desarrollo.
- **Cambios vivos:** Si se toma una decisión arquitectónica duradera, actualizar este `AGENTS.md`.
- **Respuestas breves:** Respuestas técnicas y resumidas; el humano pedirá más detalle si lo necesita.

## Estado actual
- **Implementación:** flujo completo funcional; DB con `persons` + `history` (esquema v1, sin migraciones); limpieza de caras/fotos al iniciar.
- **Tema:** claro/oscuro Material 3 (`AppTheme`); paleta clara: superficie `#FFFFFF` + acento petróleo `#0F4C5C`; paleta oscura `#0B1E24` / `#102A32` / `#5FC2D3` / `#E3F0F3`. `ThemeMode` se persiste en `theme_mode.txt` (`getApplicationSupportDirectory()`), sin `shared_preferences`; **fix M1**: el tema persistido se carga en `lib/main.dart` antes de `runApp` (`ThemeController.instance.load()`), sin destello claro al arrancar en oscuro.
- **Build:** `app-release.apk` del 10/11/2026 (167,2 MB; ABIs `arm64-v8a` + `armeabi-v7a`, sin `x86_64`); debug del 10/11/2026 (297,8 MB).
- **Verificado:** `flutter analyze`, `flutter test` y `flutter build apk --release`.
- **Pendiente:** prueba en dispositivo del flujo cámara y de la creación inicial del esquema; `ios/Podfile` en macOS.
- **Work State:**
  - **Active:** —
  - **Completed:** F002 — Fix cámara congelada al volver del registro (release-before-push, `PopScope` en ambas pantallas, retry exponencial, reset del status a `idle`).
  - **Next Move:** 1. Run QA gate via `ag_qa` · 2. Update docs · 3. Rebuild release APK · 4. Reinstall + device test.
