import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/course_holes.dart';

part 'course_hole_dao.g.dart';

/// DAO for the `course_holes` table — a course's saved per-hole template (#36).
@DriftAccessor(tables: [CourseHoles])
class CourseHoleDao extends DatabaseAccessor<GolfyDatabase>
    with _$CourseHoleDaoMixin {
  CourseHoleDao(super.db);

  /// Reactive list of a course's hole template, ordered by hole number. Emits
  /// an empty list for a course with no saved template yet.
  Stream<List<CourseHole>> watchForCourse(int courseId) {
    return (select(courseHoles)
          ..where((h) => h.courseId.equals(courseId))
          ..orderBy([(h) => OrderingTerm.asc(h.holeNumber)]))
        .watch();
  }

  /// One-shot read of a course's hole template, ordered by hole number. Used to
  /// seed the Hole Entry form when a round starts.
  Future<List<CourseHole>> getForCourse(int courseId) {
    return (select(courseHoles)
          ..where((h) => h.courseId.equals(courseId))
          ..orderBy([(h) => OrderingTerm.asc(h.holeNumber)]))
        .get();
  }

  /// Replaces a course's entire hole template in one transaction: clears the
  /// existing rows for the course, then inserts [holes]. Saving the editor
  /// rewrites the whole card, so a wholesale replace keeps the stored template
  /// exactly in sync with the submitted values (no stale rows left behind).
  /// Each companion must carry `courseId == courseId`.
  Future<void> replaceForCourse(
    int courseId,
    List<CourseHolesCompanion> holes,
  ) {
    return transaction(() async {
      await (delete(courseHoles)..where((h) => h.courseId.equals(courseId)))
          .go();
      await batch((b) => b.insertAll(courseHoles, holes));
    });
  }
}
