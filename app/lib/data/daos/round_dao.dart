import 'package:drift/drift.dart';

import '../database.dart';
import '../models/round_with_course.dart';
import '../tables/courses.dart';
import '../tables/rounds.dart';

part 'round_dao.g.dart';

/// DAO for the `rounds` table plus the rounds-with-course-name join used by
/// the rounds list screen.
@DriftAccessor(tables: [Rounds, Courses])
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

  /// Reactive list of every round joined with its course's name. Ordered
  /// newest first by date, breaking ties by descending row id so the most
  /// recently inserted round wins on the same date.
  Stream<List<RoundWithCourse>> watchAllWithCourse() {
    final query = select(rounds).join([
      innerJoin(courses, courses.id.equalsExp(rounds.courseId)),
    ])
      ..orderBy([
        OrderingTerm.desc(rounds.date),
        OrderingTerm.desc(rounds.id),
      ]);

    return query.watch().map((rows) {
      return rows
          .map((row) => RoundWithCourse(
                round: row.readTable(rounds),
                courseName: row.readTable(courses).name,
              ))
          .toList();
    });
  }
}
