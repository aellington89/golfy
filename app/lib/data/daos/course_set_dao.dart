import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/course_set_yards.dart';
import '../tables/course_sets.dart';

part 'course_set_dao.g.dart';

/// DAO for a course's named yardage sets (#36) and each set's per-hole yardage.
@DriftAccessor(tables: [CourseSets, CourseSetYards])
class CourseSetDao extends DatabaseAccessor<GolfyDatabase>
    with _$CourseSetDaoMixin {
  CourseSetDao(super.db);

  // ── Sets ─────────────────────────────────────────────────────────────────

  /// Reactive list of a course's yardage sets, ordered by name.
  Stream<List<CourseSet>> watchSetsForCourse(int courseId) {
    return (select(courseSets)
          ..where((s) => s.courseId.equals(courseId))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  /// Inserts a set and returns its id. Throws on a duplicate `(courseId, name)`
  /// (schema-level UNIQUE).
  Future<int> insertSet(CourseSetsCompanion set) => into(courseSets).insert(set);

  /// Renames a set. Throws on a duplicate `(courseId, name)`. Returns rows
  /// updated (1 if the set existed).
  Future<int> renameSet(int id, String name) {
    return (update(courseSets)..where((s) => s.id.equals(id)))
        .write(CourseSetsCompanion(name: Value(name)));
  }

  /// Deletes a set. Its yardage rows cascade, and any round played on it is
  /// detached (`rounds.course_set_id` SET NULL). Returns rows deleted.
  Future<int> deleteSet(int id) {
    return (delete(courseSets)..where((s) => s.id.equals(id))).go();
  }

  // ── Per-set yardage ───────────────────────────────────────────────────────

  /// Reactive per-hole yardage for a set, ordered by hole number.
  Stream<List<CourseSetYard>> watchYardsForSet(int setId) {
    return (select(courseSetYards)
          ..where((y) => y.courseSetId.equals(setId))
          ..orderBy([(y) => OrderingTerm.asc(y.holeNumber)]))
        .watch();
  }

  /// One-shot read of a set's per-hole yardage, ordered by hole number. Used to
  /// seed the Hole Entry form when a round starts.
  Future<List<CourseSetYard>> getYardsForSet(int setId) {
    return (select(courseSetYards)
          ..where((y) => y.courseSetId.equals(setId))
          ..orderBy([(y) => OrderingTerm.asc(y.holeNumber)]))
        .get();
  }

  /// Replaces a set's entire yardage card in one transaction (mirrors
  /// [CourseHoleDao.replaceForCourse]). Each companion must carry
  /// `courseSetId == setId`.
  Future<void> replaceYardsForSet(
    int setId,
    List<CourseSetYardsCompanion> yards,
  ) {
    return transaction(() async {
      await (delete(courseSetYards)..where((y) => y.courseSetId.equals(setId)))
          .go();
      await batch((b) => b.insertAll(courseSetYards, yards));
    });
  }
}
