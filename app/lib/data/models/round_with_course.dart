import '../database.dart';

/// A [Round] paired with its course's display name and a count of
/// hole_results rows attached to it. Produced by the rounds-list join in
/// [RoundDao.watchAllWithCourse].
class RoundWithCourse {
  const RoundWithCourse({
    required this.round,
    required this.courseName,
    required this.holesEntered,
    required this.totalScore,
    required this.totalPar,
    this.event,
  });

  final Round round;
  final String courseName;

  /// The event this round belongs to, or `null` for a casual round with no
  /// event. Sourced from the left-outer join in [RoundDao.watchAllWithCourse].
  final Event? event;

  final int holesEntered;

  /// Sum of `score` / `par` across the round's entered holes. Both are `0` for
  /// a round with no holes; callers gate display on [holesEntered] rather than
  /// reading `0 - 0 = E` as an even round.
  final int totalScore;
  final int totalPar;

  /// Strokes relative to par across the entered holes (negative = under).
  /// Mirrors `ScorecardTotals.relativeToPar`.
  int get relativeToPar => totalScore - totalPar;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoundWithCourse &&
          runtimeType == other.runtimeType &&
          round == other.round &&
          courseName == other.courseName &&
          event == other.event &&
          holesEntered == other.holesEntered &&
          totalScore == other.totalScore &&
          totalPar == other.totalPar;

  @override
  int get hashCode => Object.hash(
      round, courseName, event, holesEntered, totalScore, totalPar);

  @override
  String toString() =>
      'RoundWithCourse(round: $round, courseName: $courseName, '
      'event: $event, holesEntered: $holesEntered, totalScore: $totalScore, '
      'totalPar: $totalPar)';
}
