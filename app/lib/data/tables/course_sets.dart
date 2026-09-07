import 'package:drift/drift.dart';

import 'courses.dart';

/// A named yardage set for a course (#36) — a "pin set" or tee box. Each set
/// owns a full 18-hole yardage card ([CourseSetYards]); par and stroke index
/// are shared across a course's sets (they live on [CourseHoles]).
///
/// A round records which set it was played on (`rounds.course_set_id`), and
/// Hole Entry auto-fills that set's yardages. Cascade-deletes with its course.
@TableIndex(name: 'idx_course_sets_course', columns: {#courseId})
class CourseSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseId, name},
      ];
}
