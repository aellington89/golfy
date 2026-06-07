import 'package:flutter/material.dart';

/// Theme colour for a score relative to par, following issue #14's bands:
/// under par → green, even → `null` (the caller's default text colour), one
/// over → amber, two-or-more over → the theme's error red.
///
/// Returning `null` for even keeps the `E` label in the default on-surface
/// colour. Green and amber are fixed golf-semantic shades (no equivalent in a
/// deep-purple [ColorScheme]); red reuses [ColorScheme.error] so it tracks the
/// theme. Shared by the rounds list and the scorecard so they agree.
Color? scoreToParColor(int relativeToPar, ColorScheme scheme) {
  if (relativeToPar < 0) return Colors.green.shade700;
  if (relativeToPar == 0) return null;
  if (relativeToPar == 1) return Colors.amber.shade800;
  return scheme.error;
}
