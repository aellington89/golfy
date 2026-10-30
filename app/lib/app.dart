import 'package:flutter/material.dart';

import 'shell/app_shell.dart';

/// Golf-palette seeds: a fairway green primary with flag-yellow and sky-blue
/// accents. Anchoring hues only — Material 3 tonally normalises each into its
/// scheme roles (see [golfyColorScheme]). Shades are deliberately chosen so the
/// yellow accent stays distinct from the orange-amber "one over par" score band.
const Color _kFairwayGreen = Color(0xFF2E7D32);
const Color _kFlagYellow = Color(0xFFFBC02D);
const Color _kSkyBlue = Color(0xFF1565C0);

class GolfyApp extends StatelessWidget {
  const GolfyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golfy',
      theme: golfyTheme(Brightness.light),
      darkTheme: golfyTheme(Brightness.dark),
      // Follow the OS light/dark setting; there's no in-app toggle for v0.1.0.
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

/// Builds the app theme for a given [brightness] from the golf palette, so the
/// light and dark schemes stay visually consistent. This helper is the one seam
/// a future Material 3 dynamic-color source would slot into.
///
/// Visible for testing so the accessibility suite (#73) checks screens in the
/// theme the app really ships, not a stand-in.
@visibleForTesting
ThemeData golfyTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: golfyColorScheme(brightness),
  );
}

/// The golf [ColorScheme]: a fairway-green primary with a flag-yellow secondary
/// and a sky-blue tertiary.
///
/// A single [ColorScheme.fromSeed] green seed would derive the secondary and
/// tertiary as green-adjacent tones, never a distinct yellow and blue. So we
/// generate a per-brightness sub-scheme from each accent seed and splice its
/// Material-harmonised `primary` family into the green base. Borrowing each
/// accent's `primary` + `onPrimary` + `primaryContainer` + `onPrimaryContainer`
/// keeps its contrast pair correct in both light and dark; surfaces, outlines
/// and the error red stay from the green base (error is red-family for any
/// non-red seed, so score-band red still tracks the theme).
///
/// Visible for testing so the native Android splash (#71), whose background
/// must equal the first frame's [ColorScheme.surface], can be checked against
/// it without pumping the whole app.
@visibleForTesting
ColorScheme golfyColorScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: _kFairwayGreen,
    brightness: brightness,
  );
  final yellow = ColorScheme.fromSeed(
    seedColor: _kFlagYellow,
    brightness: brightness,
  );
  final blue = ColorScheme.fromSeed(
    seedColor: _kSkyBlue,
    brightness: brightness,
  );
  return base.copyWith(
    secondary: yellow.primary,
    onSecondary: yellow.onPrimary,
    secondaryContainer: yellow.primaryContainer,
    onSecondaryContainer: yellow.onPrimaryContainer,
    tertiary: blue.primary,
    onTertiary: blue.onPrimary,
    tertiaryContainer: blue.primaryContainer,
    onTertiaryContainer: blue.onPrimaryContainer,
  );
}
