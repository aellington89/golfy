import '../database.dart';

/// A [Round] paired with its course's display name and a count of
/// hole_results rows attached to it. Produced by the rounds-list join in
/// [RoundDao.watchAllWithCourse].
class RoundWithCourse {
  const RoundWithCourse({
    required this.round,
    required this.courseName,
    required this.holesEntered,
  });

  final Round round;
  final String courseName;
  final int holesEntered;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoundWithCourse &&
          runtimeType == other.runtimeType &&
          round == other.round &&
          courseName == other.courseName &&
          holesEntered == other.holesEntered;

  @override
  int get hashCode => Object.hash(round, courseName, holesEntered);

  @override
  String toString() =>
      'RoundWithCourse(round: $round, courseName: $courseName, '
      'holesEntered: $holesEntered)';
}
