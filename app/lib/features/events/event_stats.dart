// Pure, widget-free helpers for the event detail screen (#42): filtering the
// rounds stream to one event and summarising that event's scoring. Kept out of
// the widget layer (mirrors features/stats/*) so they unit-test without pumping
// a widget, and computed in-memory from the existing rounds stream so no new
// query or schema column is needed.

import '../../data/models/round_with_course.dart';

/// The rounds in [all] that belong to the event with [eventId], preserving
/// input order (the rounds stream is newest-first).
List<RoundWithCourse> roundsForEvent(List<RoundWithCourse> all, int eventId) =>
    all.where((r) => r.event?.id == eventId).toList(growable: false);

/// Per-event scoring summary derived from an event's rounds. Only rounds with
/// at least one entered hole ([RoundWithCourse.holesEntered] > 0) are counted —
/// an empty round carries no meaningful score. When the event has no scored
/// rounds yet, [scoredRounds] is 0 and the aggregates are null.
class EventScoringSummary {
  const EventScoringSummary({
    required this.scoredRounds,
    required this.avgScoreVsPar,
    required this.bestRound,
  });

  /// Number of rounds with at least one entered hole.
  final int scoredRounds;

  /// Mean strokes relative to par across [scoredRounds], or null when none.
  final double? avgScoreVsPar;

  /// The round with the lowest strokes-relative-to-par, or null when none.
  /// A tie resolves to the first such round in input order — since the stream
  /// is newest-first, that is the most recent best round.
  final RoundWithCourse? bestRound;

  bool get hasData => scoredRounds > 0;
}

/// Computes the [EventScoringSummary] for [rounds] (a single event's rounds).
EventScoringSummary computeEventScoringSummary(List<RoundWithCourse> rounds) {
  final scored =
      rounds.where((r) => r.holesEntered > 0).toList(growable: false);
  if (scored.isEmpty) {
    return const EventScoringSummary(
      scoredRounds: 0,
      avgScoreVsPar: null,
      bestRound: null,
    );
  }
  var sum = 0;
  var best = scored.first;
  for (final r in scored) {
    sum += r.relativeToPar;
    if (r.relativeToPar < best.relativeToPar) best = r;
  }
  return EventScoringSummary(
    scoredRounds: scored.length,
    avgScoreVsPar: sum / scored.length,
    bestRound: best,
  );
}
