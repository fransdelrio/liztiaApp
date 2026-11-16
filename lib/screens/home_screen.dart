import 'package:flutter/material.dart';

import '../widgets/liztia_app_bar.dart';
import 'scan_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LiztiaAppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScanScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Iniciar'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Historial'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
