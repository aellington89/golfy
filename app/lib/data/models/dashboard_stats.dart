/// Aggregated lifetime statistics computed across every `hole_results` row.
///
/// All percentage / average fields are nullable: a `null` value means the
/// underlying denominator was zero (e.g. no rounds, no up-and-down attempts,
/// no scoreable holes) and the UI should render an em-dash placeholder. The
/// only non-nullable scalar is [roundsPlayed], where `0` is a meaningful
/// "no rounds yet" value.
class DashboardStats {
  const DashboardStats({
    required this.roundsPlayed,
    required this.avgScorePerRound,
    required this.avgScoreVsPar,
    required this.fairwayHitPct,
    required this.girPct,
    required this.avgPuttsPerHole,
    required this.upDownPct,
    required this.penaltyHolePct,
    required this.avgPenaltyStrokesPerHole,
    required this.scoreDistribution,
    required this.bestRound,
  });

  /// The "no data" baseline returned when the database has no hole_results.
  static const empty = DashboardStats(
    roundsPlayed: 0,
    avgScorePerRound: null,
    avgScoreVsPar: null,
    fairwayHitPct: null,
    girPct: null,
    avgPuttsPerHole: null,
    upDownPct: null,
    penaltyHolePct: null,
    avgPenaltyStrokesPerHole: null,
    scoreDistribution: <ScoreBucket>[],
    bestRound: null,
  );

  final int roundsPlayed;
  final double? avgScorePerRound;
  final double? avgScoreVsPar;

  /// Fraction of par-4/par-5 tee shots that hit the fairway. Excludes par-3
  /// holes from both numerator and denominator (their `fairway_hit` is NULL).
  final double? fairwayHitPct;

  /// Fraction of holes where greens were reached in regulation.
  final double? girPct;
  final double? avgPuttsPerHole;

  /// Conversion rate over up-and-down attempts (denominator = SUM(attempt)).
  /// Null when no attempts have been recorded.
  final double? upDownPct;

  /// Fraction of holes that incurred at least one penalty stroke.
  final double? penaltyHolePct;

  /// Mean penalty strokes across every hole (including holes with zero).
  final double? avgPenaltyStrokesPerHole;

  /// One entry per distinct `score - par` bucket, ordered ascending. Empty
  /// list when no hole_results exist. The dashboard UI labels and groups the
  /// buckets (Eagle, Birdie, Par, Bogey, Double+).
  final List<ScoreBucket> scoreDistribution;

  /// The single round with the lowest cumulative `score - par`. Null when
  /// no rounds have any hole_results recorded.
  final BestRound? bestRound;
}

/// One row of the score-distribution histogram.
class ScoreBucket {
  const ScoreBucket({required this.scoreVsPar, required this.count});

  /// The bucket key: `score - par`. Negative = under par, 0 = par, positive
  /// = over par.
  final int scoreVsPar;
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreBucket &&
          runtimeType == other.runtimeType &&
          scoreVsPar == other.scoreVsPar &&
          count == other.count;

  @override
  int get hashCode => Object.hash(scoreVsPar, count);

  @override
  String toString() => 'ScoreBucket($scoreVsPar: $count)';
}

/// Lifetime-best round summary returned by the dashboard.
class BestRound {
  const BestRound({
    required this.roundId,
    required this.courseName,
    required this.date,
    required this.toPar,
  });

  final int roundId;
  final String courseName;

  /// ISO 8601 date string, matching `rounds.date`.
  final String date;

  /// Cumulative `score - par` for the round. Negative is good.
  final int toPar;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BestRound &&
          runtimeType == other.runtimeType &&
          roundId == other.roundId &&
          courseName == other.courseName &&
          date == other.date &&
          toPar == other.toPar;

  @override
  int get hashCode => Object.hash(roundId, courseName, date, toPar);

  @override
  String toString() =>
      'BestRound(roundId: $roundId, courseName: $courseName, date: $date, toPar: $toPar)';
}
