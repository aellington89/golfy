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
