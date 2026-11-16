import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

/// Botón de la app bar que alterna entre modo claro y oscuro.
///
/// El estado y el icono se leen del [ThemeController] inyectado, que es la
/// única fuente de verdad; en claro muestra una luna (→ oscuro) y en oscuro un
/// sol (→ claro).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.controller});

  /// Controlador del tema a usar. `null` ⇒ `ThemeController.instance`.
  ///
  /// No se declara como valor por defecto del constructor porque la instancia
  /// global no es `const` y el widget debe seguir siendo `const`.
  final ThemeController? controller;

  @override
  Widget build(BuildContext context) {
    final themeController = controller ?? ThemeController.instance;
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final isDark = themeController.isDark;
        return IconButton(
          onPressed: themeController.toggle,
          tooltip: isDark ? 'Modo diurno' : 'Modo nocturno',
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        );
      },
    );
  }
}
