import 'package:drift/drift.dart';

import 'hole_results.dart';

/// One shot played on a hole (#22) — an ordered, optional per-hole detail list
/// that supersedes the flat `teeClub` / `driveDistanceYards` /
/// `approachDistanceYards` columns. Each row records the club, distance, lie
/// (where the shot was played from) and result (where it finished), all
/// optional. `score` / `putts` stay the authoritative scoring fields on
/// [HoleResults]; shots need not sum to the score.
///
/// Cascade-deletes with its hole_results row.
@TableIndex(name: 'idx_hole_shots_result', columns: {#holeResultId})
class HoleShots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get holeResultId =>
      integer().references(HoleResults, #id, onDelete: KeyAction.cascade)();
  IntColumn get shotNumber =>
      integer().customConstraint('NOT NULL CHECK (shot_number >= 1)')();
  TextColumn get club => text().nullable()();
  IntColumn get distanceYards => integer()
      .nullable()
      .customConstraint('CHECK (distance_yards >= 0)')();

  /// Where the shot was played from — Tee / Fairway / Light Rough / Deep Rough
  /// / Bunker / Green / Recovery. Free-ish text (a small preset list in the UI).
  TextColumn get lie => text().nullable()();

  /// Terminal outcome only — `Holed` or `Penalty`. A shot's normal end-spot is
  /// the *next* shot's [lie], so `result` is left null except for those two
  /// cases a next shot can't imply. Free-ish text (a small preset list).
  TextColumn get result => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {holeResultId, shotNumber},
      ];
}
