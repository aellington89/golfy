// Presentation helpers for golf scores relative to par. Kept feature-neutral
// (outside `rounds/`) so the upcoming Dashboard can reuse the same "+1 / E /
// -1" formatting without a cross-feature import.

/// Formats a single hole's score relative to its par: `"+2"`, `"E"`, `"-1"`.
String formatScoreToPar(int score, int par) => formatRelativeToPar(score - par);

/// Formats an already-computed difference (score − par) the same way. A
/// negative [diff] already carries its `-` sign, so under-par values render
/// as `"-3"`; even is `"E"`; over-par gets an explicit `+`.
String formatRelativeToPar(int diff) {
  if (diff == 0) return 'E';
  return diff > 0 ? '+$diff' : '$diff';
}

/// What a screen reader says for a difference (score − par) that
/// [formatRelativeToPar] shows as `"+2"` / `"E"` / `"-3"`: `"2 over par"`,
/// `"even par"`, `"3 under par"`. A bare `"E"` or `"-3"` reads as a letter and
/// "minus three", which says nothing about golf (#73).
String spokenRelativeToPar(int diff) {
  if (diff == 0) return 'even par';
  return diff > 0 ? '$diff over par' : '${-diff} under par';
}

/// The golf name for one hole's score relative to par — `"birdie"`,
/// `"double bogey"` — or `null` past quadruple bogey, where there is no name
/// and the number says it. The same names as the dashboard's score
/// distribution (#59), except that a single hole is exactly a quadruple bogey
/// rather than that row's open-ended "Quadruple+". Lower case: it is spoken
/// mid-sentence on the scorecard (#73).
String? holeScoreName(int diff) => switch (diff) {
      -4 => 'condor',
      -3 => 'albatross',
      -2 => 'eagle',
      -1 => 'birdie',
      0 => 'par',
      1 => 'bogey',
      2 => 'double bogey',
      3 => 'triple bogey',
      4 => 'quadruple bogey',
      _ => null,
    };
