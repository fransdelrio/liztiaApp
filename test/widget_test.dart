import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liztia/screens/home_screen.dart';
import 'package:liztia/theme/app_theme.dart';
import 'package:liztia/theme/theme_controller.dart';
import 'package:liztia/widgets/liztia_app_bar.dart';

void main() {
  testWidgets('home muestra acciones principales', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
    );

    expect(find.text('liztia'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
  });

  testWidgets('el toggle alterna el tema y el icono', (
    WidgetTester tester,
  ) async {
    // Controller aislado: el test no comparte estado con el singleton global.
    final controller = ThemeController.test();
    expect(controller.themeMode, ThemeMode.light);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: controller.themeMode,
            home: Scaffold(appBar: LiztiaAppBar(themeController: controller)),
          );
        },
      ),
    );

    // Claro: luna y tooltip "Modo nocturno".
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
    expect(find.byTooltip('Modo nocturno'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.dark);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
    expect(find.byTooltip('Modo diurno'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('liztia'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();

    expect(controller.themeMode, ThemeMode.light);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('liztia'))).brightness,
      Brightness.light,
    );
  });
}
