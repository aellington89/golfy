import 'package:drift/drift.dart';

import 'courses.dart';

/// A course's named **pin set** — one pin position per hole: "Sunday pins",
/// "Tournament day 1".
///
/// A pin set has no yardage of its own. Where its pins sit changes every tee
/// set's distance to them, so a hole's yards for a pin set are always
/// per tee set too — the [TeeToPinYards]. Paired with a [TeeSets] row it makes
/// a round's **yardage set**.
///
/// Cascade-deletes with its course.
@TableIndex(name: 'idx_pin_sets_course', columns: {#courseId})
class PinSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseId, name},
      ];
}
