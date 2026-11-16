import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tema global de liztia (Material 3) en variantes clara y oscura.
///
/// Paleta:
/// - Claro: superficie blanca, acento petróleo `#0F4C5C`, texto oscuro.
/// - Oscuro: superficie `#0B1E24`, contenedor `#102A32`, acento `#5FC2D3`,
///   texto `#E3F0F3`.
class AppTheme {
  AppTheme._();

  /// Acento del modo claro.
  static const Color petrol = Color(0xFF0F4C5C);

  /// Superficie del modo oscuro.
  static const Color darkSurface = Color(0xFF0B1E24);

  /// Contenedores (cards, app bar, botones tonales) del modo oscuro.
  static const Color darkContainer = Color(0xFF102A32);

  /// Acento del modo oscuro.
  static const Color darkAccent = Color(0xFF5FC2D3);

  /// Texto principal del modo oscuro.
  static const Color darkText = Color(0xFFE3F0F3);

  static const double _radius = 16;

  static const _buttonPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  );
  static const _buttonMinSize = Size(0, 48);

  static final ThemeData light = _build(
    ColorScheme.fromSeed(
      seedColor: petrol,
      brightness: Brightness.light,
    ).copyWith(
      primary: petrol,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFCDE8EE),
      onPrimaryContainer: const Color(0xFF032A33),
      secondary: const Color(0xFF2E7D8C),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF102429),
      onSurfaceVariant: const Color(0xFF4A5D62),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF3F8F9),
      surfaceContainer: const Color(0xFFE8F1F3),
      surfaceContainerHigh: const Color(0xFFDEEAEC),
      // 3.68:1 sobre `surface` blanca (WCAG 1.4.11 exige >= 3:1): borde
      // visible de `OutlinedButton`.
      outline: const Color(0xFF6E8A90),
      outlineVariant: const Color(0xFFDCE6E8),
    ),
    Brightness.light,
  );

  static final ThemeData dark = _build(
    ColorScheme.fromSeed(
      seedColor: darkAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: darkAccent,
      onPrimary: const Color(0xFF04262C),
      primaryContainer: darkContainer,
      onPrimaryContainer: darkText,
      secondary: const Color(0xFF8AD6E3),
      onSecondary: const Color(0xFF04262C),
      surface: darkSurface,
      onSurface: darkText,
      onSurfaceVariant: const Color(0xFFA9C4CA),
      surfaceContainerLowest: const Color(0xFF07171C),
      surfaceContainerLow: darkContainer,
      surfaceContainer: const Color(0xFF143039),
      surfaceContainerHigh: const Color(0xFF193B45),
      // 4.19:1 sobre `surface` `#0B1E24` (WCAG 1.4.11 exige >= 3:1).
      outline: const Color(0xFF5A868F),
      outlineVariant: const Color(0xFF254A53),
    ),
    Brightness.dark,
  );

  /// Construye el [ThemeData] compartido por ambos modos.
  ///
  /// Los estilos de botón se definen aquí (no con `styleFrom` por widget) para
  /// que toda la app mantenga la misma forma, altura y tipografía.
  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final textTheme = base.textTheme;

    // `labelLarge` del tema actual, con el peso y tracking de los botones.
    final buttonTextStyle = (textTheme.labelLarge ?? const TextStyle())
        .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
    );

    final overlayStyle = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: overlayStyle.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: scheme.surface,
          systemNavigationBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
          shape: buttonShape,
          textStyle: buttonTextStyle,
          iconSize: 20,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
          shape: buttonShape,
          textStyle: buttonTextStyle,
          iconSize: 20,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
          shape: buttonShape,
          textStyle: buttonTextStyle,
          iconSize: 20,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: _buttonPadding,
          minimumSize: _buttonMinSize,
          shape: buttonShape,
          textStyle: buttonTextStyle,
          iconSize: 20,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
        ),
        // Color explícito para acciones ("Deshacer", etc.): `primary` mantiene
        // contraste >= 3:1 sobre `surfaceContainerHigh` en ambos modos.
        actionTextColor: scheme.primary,
      ),
    );
  }
}
