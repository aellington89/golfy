import 'dashboard_stats.dart';

export 'dashboard_stats.dart' show BestRound;

/// Aggregated scoring statistics for a single event, computed across the
/// `hole_results` of that event's rounds. The per-event counterpart to
/// [DashboardStats] — see [DashboardDao.watchEventStats].
///
/// The average fields are nullable: a `null` means the underlying denominator
/// was zero (the event has no scored holes yet) and the UI should render an
/// em-dash placeholder. [roundsScored] and [holesPlayed] are non-nullable, where
/// `0` is a meaningful "nothing entered for this event yet" value.
class EventStats {
  const EventStats({
    required this.roundsScored,
    required this.holesPlayed,
    required this.avgScorePerRound,
    required this.avgScoreVsPar,
    required this.bestRound,
  });

  /// The "no data" baseline returned for an event with no scored holes.
  static const empty = EventStats(
    roundsScored: 0,
    holesPlayed: 0,
    avgScorePerRound: null,
    avgScoreVsPar: null,
    bestRound: null,
  );

  /// Number of the event's rounds with at least one entered hole (an empty
  /// round carries no meaningful score, so it is not counted).
  final int roundsScored;

  /// Total hole_results rows across the event's rounds.
  final int holesPlayed;

  /// Mean strokes per round across [roundsScored], or null when none.
  final double? avgScorePerRound;

  /// Mean strokes relative to par across [roundsScored], or null when none.
  final double? avgScoreVsPar;

  /// The event's round with the lowest cumulative `score - par`, or null when
  /// no round has any hole_results. A to-par tie resolves to the most recent
  /// round (see [DashboardDao.watchEventStats]).
  final BestRound? bestRound;

  bool get hasData => roundsScored > 0;
}
