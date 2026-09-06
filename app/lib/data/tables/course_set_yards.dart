import 'package:drift/drift.dart';

import 'course_sets.dart';

/// Per-hole yardage for one [CourseSets] set — one row per (set, hole) (#36).
///
/// Separated from [CourseHoles] (which holds the shared par / stroke index) so a
/// course can carry several sets at different yardages. Cascade-deletes with its
/// set.
@TableIndex(name: 'idx_course_set_yards_set', columns: {#courseSetId})
class CourseSetYards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseSetId =>
      integer().references(CourseSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get holeNumber => integer()
      .customConstraint('NOT NULL CHECK (hole_number BETWEEN 1 AND 18)')();
  IntColumn get yards =>
      integer().customConstraint('NOT NULL CHECK (yards >= 0)')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseSetId, holeNumber},
      ];
}
