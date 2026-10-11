import 'package:drift/drift.dart';

import 'courses.dart';

/// A course's named **tee set** — the tee box a hole is played from: "Black",
/// "Blue", "Forward".
///
/// Each tee set owns a standard per-hole yardage, its [CourseYards] — the
/// scorecard number, which moves with the tee box but not with where the pin
/// is cut. With a [PinSets] row it makes a round's **yardage set**, whose
/// per-hole yards are the pair's [TeeToPinYards].
///
/// Cascade-deletes with its course.
@TableIndex(name: 'idx_tee_sets_course', columns: {#courseId})
class TeeSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseId, name},
      ];
}
