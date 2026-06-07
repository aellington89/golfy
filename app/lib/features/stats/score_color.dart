import 'package:flutter/material.dart';

/// Theme colour for a score relative to par, following issue #14's bands:
/// under par → green, even → `null` (the caller's default text colour), one
/// over → amber, two-or-more over → the theme's error red.
///
/// Returning `null` for even keeps the `E` label in the default on-surface
/// colour. Green and amber are golf-semantic shades with no equivalent in a
/// deep-purple [ColorScheme]; they shift to lighter shades on a dark scheme so
/// they stay legible on a dark surface (#16). Red reuses [ColorScheme.error],
/// which already tracks the theme. Shared by the rounds list and the scorecard
/// so they agree.
Color? scoreToParColor(int relativeToPar, ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  if (relativeToPar < 0) {
    return dark ? Colors.green.shade400 : Colors.green.shade700;
  }
  if (relativeToPar == 0) return null;
  if (relativeToPar == 1) {
    return dark ? Colors.amber.shade400 : Colors.amber.shade800;
  }
  return scheme.error;
}
