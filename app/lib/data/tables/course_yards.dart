import 'package:drift/drift.dart';

import 'tee_sets.dart';

/// **Course yards**: a tee set's standard yardage for a hole — the scorecard
/// number, one row per (tee set, hole).
///
/// It varies with the tee set and never with the pin set, so it is keyed by
/// tee set alone. A round's own distance to the pin is [TeeToPinYards]; this
/// is what that falls back to when a round names a tee set but no pin set.
///
/// Cascade-deletes with its tee set.
@TableIndex(name: 'idx_course_yards_tee_set', columns: {#teeSetId})
class CourseYards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get teeSetId =>
      integer().references(TeeSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get holeNumber => integer()
      .customConstraint('NOT NULL CHECK (hole_number BETWEEN 1 AND 18)')();
  IntColumn get yards =>
      integer().customConstraint('NOT NULL CHECK (yards >= 0)')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {teeSetId, holeNumber},
      ];
}
