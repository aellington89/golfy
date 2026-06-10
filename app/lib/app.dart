import 'package:flutter/material.dart';

import 'shell/app_shell.dart';

class GolfyApp extends StatelessWidget {
  const GolfyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golfy',
      theme: _golfyTheme(Brightness.light),
      darkTheme: _golfyTheme(Brightness.dark),
      // Follow the OS light/dark setting; there's no in-app toggle for v0.1.0.
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

/// Builds the app theme for a given [brightness] from a single deep-purple
/// seed, so the light and dark schemes stay visually consistent. This helper
/// is the one seam a future Material 3 dynamic-color source would slot into.
ThemeData _golfyTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: brightness,
    ),
  );
}
