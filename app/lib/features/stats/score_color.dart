import 'package:flutter/material.dart';

/// Theme colour for a score relative to par, following issue #14's bands:
/// under par → green, even → `null` (the caller's default text colour), one
/// over → amber, two-or-more over → the theme's error red.
///
/// Returning `null` for even keeps the `E` label in the default on-surface
/// colour. Green and amber are fixed golf-semantic shades — they signal a
/// scoring outcome independent of the app's palette, so they're kept out of the
/// [ColorScheme]; they shift to lighter shades on a dark scheme so they stay
/// legible on a dark surface (#16). Red reuses [ColorScheme.error],
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

/// Theme colour for an *average* score relative to par — the nullable decimal
/// rendered by [formatSignedAverage] on the scoring summaries. Rounds to one
/// decimal first so an average that displays as `"E"` stays neutral, then maps
/// the sign onto [scoreToParColor]'s bands: any amount under par → green, any
/// amount over → the theme's error red, even (or a `null` "no data" average) →
/// `null` for the caller's default text colour.
///
/// Unlike [scoreToParColor], a small positive average (e.g. `+0.3`) is red
/// rather than amber: an over-par *average* has no single-hole "one over"
/// notion. Shared by the Dashboard, the Event detail card, and the Events list
/// tiles so their averages agree.
Color? avgScoreVsParColor(double? avg, ColorScheme scheme) {
  if (avg == null) return null;
  final rounded = (avg * 10).round() / 10;
  if (rounded > 0) return scoreToParColor(2, scheme);
  if (rounded < 0) return scoreToParColor(-1, scheme);
  return null;
}
