import 'package:drift/drift.dart';

import 'courses.dart';

/// The per-hole facts of a course that hold whichever tee set and pin set it
/// is played on: par and an optional stroke index, one row per (course, hole)
/// (#36).
///
/// Yardage lives elsewhere because it does vary: a hole's course yards with
/// the tee set ([CourseYards]), and its tee-to-pin yards with the tee set and
/// pin set together ([TeeToPinYards]).
///
/// Cascade-deletes with its course — a course that still has rounds can't be
/// deleted (the `rounds.course_id` FK is RESTRICT), so this only fires for an
/// unused course whose template should go with it.
@TableIndex(name: 'idx_course_holes_course', columns: {#courseId})
class CourseHoles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  IntColumn get holeNumber => integer()
      .customConstraint('NOT NULL CHECK (hole_number BETWEEN 1 AND 18)')();
  IntColumn get par =>
      integer().customConstraint('NOT NULL CHECK (par BETWEEN 3 AND 5)')();

  /// Handicap stroke index (1 = hardest hole … 18 = easiest). Optional — many
  /// video-game courses don't surface it — so nullable, with the 1–18 CHECK
  /// applied only when a value is present.
  IntColumn get strokeIndex => integer()
      .nullable()
      .customConstraint('CHECK (stroke_index BETWEEN 1 AND 18)')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseId, holeNumber},
      ];
}
