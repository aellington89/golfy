import 'package:drift/drift.dart';

import 'pin_sets.dart';
import 'tee_sets.dart';

/// **Tee to pin** yards: the distance from a tee set's tee box to a pin set's
/// pin on one hole — one row per (tee set, pin set, hole).
///
/// It varies with both: moving the pin changes it, and the same pin set is a
/// different distance from each tee set. A **yardage set** is a (tee set, pin
/// set) pair, and these are its per-hole yards — what a round played on that
/// pair pre-fills.
///
/// The tee set and pin set must belong to the same course. SQL can't say so
/// across two parent tables, so `YardageDao` enforces it on write and a
/// backup's `validate()` on restore.
///
/// Cascade-deletes with either set.
@TableIndex(name: 'idx_tee_to_pin_yards_tee_set', columns: {#teeSetId})
@TableIndex(name: 'idx_tee_to_pin_yards_pin_set', columns: {#pinSetId})
class TeeToPinYards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get teeSetId =>
      integer().references(TeeSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get pinSetId =>
      integer().references(PinSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get holeNumber => integer()
      .customConstraint('NOT NULL CHECK (hole_number BETWEEN 1 AND 18)')();
  IntColumn get yards =>
      integer().customConstraint('NOT NULL CHECK (yards >= 0)')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {teeSetId, pinSetId, holeNumber},
      ];
}
