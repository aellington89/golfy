// Presentation helpers for the dashboard's aggregate stats: percentages,
// fixed-precision decimals, signed averages, and score-distribution bucketing.
// Kept as pure functions (alongside score_format.dart) so they unit-test
// without a widget. A `null` input renders as an em-dash — that is how the
// DAO's division-by-zero NULLs surface in the UI.

import '../../data/models/dashboard_stats.dart';

const String _dash = '—';

/// Formats a 0..1 fraction as a one-decimal percentage: `0.625` → `"62.5%"`.
/// Null (no data) → `"—"`.
String formatPercent(double? fraction) {
  if (fraction == null) return _dash;
  return '${(fraction * 100).toStringAsFixed(1)}%';
}

/// Formats a nullable average to a fixed number of decimals (default one).
/// Null → `"—"`.
String formatDecimal(double? value, {int digits = 1}) {
  if (value == null) return _dash;
  return value.toStringAsFixed(digits);
}

/// Formats an average score-to-par with an explicit sign and one decimal:
/// `-1.0`, `+2.3`, and `"E"` when it rounds to zero. Null → `"—"`. Rounding to
/// one decimal first means a near-zero average collapses to `E` rather than
/// rendering as `-0.0` / `+0.0`.
String formatSignedAverage(double? value) {
  if (value == null) return _dash;
  final rounded = (value * 10).round() / 10;
  if (rounded == 0) return 'E';
  final magnitude = rounded.abs().toStringAsFixed(1);
  return rounded > 0 ? '+$magnitude' : '-$magnitude';
}

/// One row of the dashboard's score-distribution chart: a display label and the
/// number of holes that fell in that category.
class ScoreCategoryCount {
  const ScoreCategoryCount({
    required this.label,
    required this.count,
    this.isAce = false,
  });

  final String label;
  final int count;

  /// True only for the Ace row. Aces are also counted in their par-relative
  /// row, so this row is an overlay: it is excluded from the holes total that
  /// percentages divide by, and the UI highlights it.
  final bool isAce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreCategoryCount &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          count == other.count &&
          isAce == other.isAce;

  @override
  int get hashCode => Object.hash(label, count, isAce);

  @override
  String toString() => 'ScoreCategoryCount($label: $count)';
}

/// The par-relative rows in display order, as `score - par` → label. The ends
/// are open: anything at or below the first key lands in Condor, and anything
/// at or above the last lands in Quadruple+ bogey, so no bucket is dropped.
const _parRelativeLabels = <int, String>{
  -4: 'Condor',
  -3: 'Albatross',
  -2: 'Eagle',
  -1: 'Birdie',
  0: 'Par',
  1: 'Bogey',
  2: 'Double bogey',
  3: 'Triple bogey',
  4: 'Quadruple+ bogey',
};

/// Folds the raw per-`(score - par)` buckets into the fixed display rows,
/// always returning all ten in display order, zero-filled:
///
/// * **Ace** — holes-in-one (`score == 1`), summed from [ScoreBucket.aces].
/// * **Condor** (`≤ -4`), **Albatross** (`-3`), **Eagle** (`-2`), **Birdie**
///   (`-1`), **Par** (`0`), **Bogey** (`+1`), **Double bogey** (`+2`),
///   **Triple bogey** (`+3`), **Quadruple+ bogey** (`≥ +4`).
///
/// An ace is counted twice: in the Ace row *and* in the par-relative row it
/// scores as (eagle on a par 3, albatross on a par 4, condor on a par 5). The
/// nine par-relative rows therefore still sum to the number of holes; the Ace
/// row is flagged [ScoreCategoryCount.isAce] so callers can leave it out of
/// that total.
List<ScoreCategoryCount> groupScoreDistribution(List<ScoreBucket> buckets) {
  final keys = _parRelativeLabels.keys;
  final counts = {for (final k in keys) k: 0};
  var aces = 0;

  for (final b in buckets) {
    final key = b.scoreVsPar.clamp(keys.first, keys.last);
    counts[key] = counts[key]! + b.count;
    aces += b.aces;
  }

  return [
    ScoreCategoryCount(label: 'Ace', count: aces, isAce: true),
    for (final e in _parRelativeLabels.entries)
      ScoreCategoryCount(label: e.value, count: counts[e.key]!),
  ];
}
