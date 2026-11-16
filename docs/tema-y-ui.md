# Tema y UI (lotes de estética)

## 1. Objetivo y alcance

Estado actual del tema claro/oscuro de la app y de su UI (AppBar común, toggle luna/sol, botones modernizados), incluyendo el **fix M1** (carga del tema persistido antes del primer frame).

Este documento **no duplica** la arquitectura general ni el flujo de negocio (ver `AGENTS.md` y `specs/overview.md`); cubre únicamente la capa de tema/UI con las rutas de código reales como fuente única.

## 2. Estado del fix M1 (verificado en código)

| Punto | Dónde | Comportamiento real |
| :-- | :-- | :-- |
| Carga temprana del tema | `lib/main.dart:12` | `await ThemeController.instance.load()` ejecuta **antes** de `runApp(const App())`, en un `main` async con `WidgetsFlutterBinding.ensureInitialized()` y `FlutterNativeSplash.preserve()`. |
| Destello de tema claro en arranque oscuro | `lib/main.dart` | Corregido: el `ThemeMode` persistido ya está aplicado cuando se construye el primer frame. |
| Reacción al toggle | `lib/app.dart` | `MaterialApp` observa `ThemeController.instance` con `AnimatedBuilder` y aplica `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode: _themeController.themeMode`. |
| Persistencia | `lib/theme/theme_controller.dart` | Archivo `theme_mode.txt` en `getApplicationSupportDirectory()`; valores `'light'` / `'dark'`; si el archivo no existe o falla la lectura, queda en claro. Sin `shared_preferences`. |

## 3. Paleta y estilos (`lib/theme/app_theme.dart`)

`AppTheme` genera ambos `ThemeData` con `useMaterial3: true` a partir de `ColorScheme.fromSeed` + `copyWith`.

| Modo | Superficie | Acento (primary) | Contenedores / detalles |
| :-- | :-- | :-- | :-- |
| Claro | Blanca (`#FFFFFF`) | Petróleo `#0F4C5C` | `secondary #2E7D8C`, `primaryContainer #CDE8EE` |
| Oscuro | `#0B1E24` | `#5FC2D3` | Contenedores `#102A32` (`darkContainer`), texto `#E3F0F3` (`darkText`) |

Otros estilos en `_build()` de `app_theme.dart`: `AppBarTheme` sin elevación con `surfaceTintColor` transparente, `SystemUiOverlayStyle` por modo, `SnackBar` flotante sobre `surfaceContainerHigh` con `actionTextColor: primary`, `DividerTheme` desde `outlineVariant`.

## 4. Botones

Los estilos están **centralizados** en `app_theme.dart` (no `styleFrom` por widget): forma redondeada con radio `16`, altura mínima `48`, padding `20x14`, `labelLarge` con peso `w600` y tracking `0.2`, `iconSize 20`. Se definen para `FilledButton`, `OutlinedButton`, `TextButton` y `ElevatedButton`.

En las pantallas solo se usan los constructores `.icon` (verificación con grep en `lib/`):

| Constructor | Uso verificado en el código |
| :-- | :-- |
| `FilledButton.icon` | Acción principal: `home_screen.dart:32`, `scan_screen.dart:374/476`, `register_screen.dart:289/369/390` |
| `FilledButton.tonalIcon` | Acción alternativa en el freeze: `scan_screen.dart:461` |
| `OutlinedButton.icon` | Acción secundaria: `home_screen.dart:45`, `history_screen.dart:84`, `scan_screen.dart:383/493`, `register_screen.dart:298` |
| `TextButton.icon` | Acción terciaria: `register_screen.dart:357` |

## 5. AppBar común y toggle

| Widget | Archivo | Qué hace |
| :-- | :-- | :-- |
| `LiztiaAppBar` | `lib/widgets/liztia_app_bar.dart` | `AppBar` con título por pantalla (por defecto `'liztia'`) y `ThemeToggleButton` añadido al final de las actions. La usan `home_screen.dart`, `scan_screen.dart`, `register_screen.dart` e `history_screen.dart`. |
| `ThemeToggleButton` | `lib/widgets/theme_toggle_button.dart` | En claro muestra luna (`Icons.dark_mode_outlined`, tooltip "Modo nocturno") y en oscuro sol (`Icons.light_mode_outlined`, tooltip "Modo diurno"); el icono se resuelve desde `Theme.of(context).brightness`, luego reacciona al `ThemeMode`. Acción: `ThemeController.instance.toggle()`, que persiste `light`/`dark` con `flush: true`. |

## 6. Pendiente (deuda de documentación)

- ~~`AGENTS.md` sin reflejar el fix M1 ni la paleta clara~~ **Resuelto**: `AGENTS.md` ya documenta el punto 0 del flujo (`ThemeController.load()` en `lib/main.dart` antes de `runApp`), la paleta clara (`#FFFFFF` / `#0F4C5C`), el botón `FilledButton.tonalIcon` para "Registrar", la barra de estado ligada al tema y la pantalla "Registro Exitoso!" con `colorScheme.surface` (secciones "Flujo de la app", "Tema y UI", "Splash e iconos" y "Estado actual").
- `specs/features/*.md` describen los botones solo funcionalmente ("botón Escanear", etc.), sin estilos; no hay nada de este lote estético que sincronizar ahí.
- Sin contradicciones detectadas entre el código (`lib/theme/`, `lib/widgets/`, `lib/app.dart`, `lib/main.dart`) y este documento.
