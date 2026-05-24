import '../database.dart';

/// A [Round] paired with its course's display name, produced by the
/// rounds-list join in [RoundDao.watchAllWithCourse].
class RoundWithCourse {
  const RoundWithCourse({
    required this.round,
    required this.courseName,
  });

  final Round round;
  final String courseName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoundWithCourse &&
          runtimeType == other.runtimeType &&
          round == other.round &&
          courseName == other.courseName;

  @override
  int get hashCode => Object.hash(round, courseName);

  @override
  String toString() =>
      'RoundWithCourse(round: $round, courseName: $courseName)';
}
