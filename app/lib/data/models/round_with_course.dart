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
    this.teeSetName,
    this.pinSetName,
  });

  final Round round;
  final String courseName;

  /// The event this round belongs to, or `null` for a casual round with no
  /// event. Sourced from the left-outer join in [RoundDao.watchAllWithCourse].
  final Event? event;

  /// Names of the tee set and pin set this round was played on — together its
  /// yardage set — each null when the round has none. Sourced from the
  /// left-outer joins in [RoundDao.watchAllWithCourse].
  final String? teeSetName;
  final String? pinSetName;

  /// The round's yardage set as one label — "Blue · Sunday pins", or just the
  /// half it has — or null when it has neither.
  String? get yardageSetLabel => yardageSetLabelOf(teeSetName, pinSetName);

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
          teeSetName == other.teeSetName &&
          pinSetName == other.pinSetName &&
          holesEntered == other.holesEntered &&
          totalScore == other.totalScore &&
          totalPar == other.totalPar;

  @override
  int get hashCode => Object.hash(round, courseName, event, teeSetName,
      pinSetName, holesEntered, totalScore, totalPar);

  @override
  String toString() =>
      'RoundWithCourse(round: $round, courseName: $courseName, '
      'event: $event, teeSetName: $teeSetName, pinSetName: $pinSetName, '
      'holesEntered: $holesEntered, totalScore: $totalScore, '
      'totalPar: $totalPar)';
}

/// A yardage set's label from its tee set and pin set names — "Blue · Sunday
/// pins", or whichever half is present — or null when neither is.
String? yardageSetLabelOf(String? teeSetName, String? pinSetName) {
  final parts = [?teeSetName, ?pinSetName];
  return parts.isEmpty ? null : parts.join(' · ');
}
