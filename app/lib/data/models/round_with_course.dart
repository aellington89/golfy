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
  });

  final Round round;
  final String courseName;
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
          holesEntered == other.holesEntered &&
          totalScore == other.totalScore &&
          totalPar == other.totalPar;

  @override
  int get hashCode =>
      Object.hash(round, courseName, holesEntered, totalScore, totalPar);

  @override
  String toString() =>
      'RoundWithCourse(round: $round, courseName: $courseName, '
      'holesEntered: $holesEntered, totalScore: $totalScore, '
      'totalPar: $totalPar)';
}
