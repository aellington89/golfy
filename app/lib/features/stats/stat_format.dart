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
  const ScoreCategoryCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreCategoryCount &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          count == other.count;

  @override
  int get hashCode => Object.hash(label, count);

  @override
  String toString() => 'ScoreCategoryCount($label: $count)';
}

/// Folds the raw per-`(score - par)` buckets into the five fixed display
/// categories — Eagles (`≤ -2`, including albatross), Birdies (`-1`), Pars
/// (`0`), Bogeys (`+1`), Double+ (`≥ +2`) — always returning all five in
/// display order, zero-filled.
List<ScoreCategoryCount> groupScoreDistribution(List<ScoreBucket> buckets) {
  var eagles = 0;
  var birdies = 0;
  var pars = 0;
  var bogeys = 0;
  var doublePlus = 0;

  for (final b in buckets) {
    final diff = b.scoreVsPar;
    if (diff <= -2) {
      eagles += b.count;
    } else if (diff == -1) {
      birdies += b.count;
    } else if (diff == 0) {
      pars += b.count;
    } else if (diff == 1) {
      bogeys += b.count;
    } else {
      doublePlus += b.count;
    }
  }

  return [
    ScoreCategoryCount(label: 'Eagles', count: eagles),
    ScoreCategoryCount(label: 'Birdies', count: birdies),
    ScoreCategoryCount(label: 'Pars', count: pars),
    ScoreCategoryCount(label: 'Bogeys', count: bogeys),
    ScoreCategoryCount(label: 'Double+', count: doublePlus),
  ];
}
