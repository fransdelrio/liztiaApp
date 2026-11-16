import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';
import 'theme_toggle_button.dart';

/// App bar común: título a la izquierda, acciones propias de la pantalla y el
/// toggle de tema siempre al final.
class LiztiaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiztiaAppBar({
    super.key,
    this.title = 'liztia',
    this.actions = const <Widget>[],
    this.themeController,
  });

  final String title;
  final List<Widget> actions;

  /// Controlador que consume el toggle de tema (misma fuente de estado que
  /// `MaterialApp`). `null` ⇒ `ThemeController.instance`.
  final ThemeController? themeController;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [...actions, ThemeToggleButton(controller: themeController)],
    );
  }
}
