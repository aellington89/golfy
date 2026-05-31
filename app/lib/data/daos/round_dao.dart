import 'package:drift/drift.dart';

import '../database.dart';
import '../models/round_with_course.dart';
import '../tables/courses.dart';
import '../tables/hole_results.dart';
import '../tables/rounds.dart';

part 'round_dao.g.dart';

/// DAO for the `rounds` table plus the rounds-with-course-name join used by
/// the rounds list screen.
@DriftAccessor(tables: [Rounds, Courses, HoleResults])
class RoundDao extends DatabaseAccessor<GolfyDatabase> with _$RoundDaoMixin {
  RoundDao(super.db);

  /// Inserts a new round and returns the generated row id. The `courseId`
  /// must reference an existing course (FK RESTRICT).
  Future<int> insert(RoundsCompanion round) => into(rounds).insert(round);

  /// Looks up a single round by id. Returns null if no row matches.
  Future<Round?> getById(int id) {
    return (select(rounds)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Deletes a single round by id. Cascade-deletes its hole_results via the
  /// schema-level `ON DELETE CASCADE`. Returns the number of rows deleted
  /// (1 if the round existed, 0 otherwise).
  Future<int> deleteById(int id) {
    return (delete(rounds)..where((r) => r.id.equals(id))).go();
  }

  /// Reactive list of every round joined with its course's name and the
  /// count of hole_results rows attached to it. Ordered newest first by
  /// date, breaking ties by descending row id so the most recently inserted
  /// round wins on the same date.
  ///
  /// Uses a `LEFT OUTER JOIN` to `hole_results` so rounds with no holes
  /// entered still appear (with `holesEntered = 0`).
  Stream<List<RoundWithCourse>> watchAllWithCourse() {
    final holeCount = holeResults.id.count();
    final query = select(rounds).join([
      innerJoin(courses, courses.id.equalsExp(rounds.courseId)),
      leftOuterJoin(
        holeResults,
        holeResults.roundId.equalsExp(rounds.id),
      ),
    ])
      ..addColumns([holeCount])
      ..groupBy([rounds.id])
      ..orderBy([
        OrderingTerm.desc(rounds.date),
        OrderingTerm.desc(rounds.id),
      ]);

    return query.watch().map((rows) {
      return rows
          .map((row) => RoundWithCourse(
                round: row.readTable(rounds),
                courseName: row.readTable(courses).name,
                holesEntered: row.read(holeCount) ?? 0,
              ))
          .toList();
    });
  }
}
