import 'package:drift/drift.dart';

import 'hole_results.dart';

/// One shot played on a hole (#22) — an ordered, optional per-hole detail list
/// that supersedes the flat `teeClub` / `driveDistanceYards` /
/// `approachDistanceYards` columns. Each row records the club, distance (yards
/// to the pin, or feet to the hole for a putt), lie (where the shot was played
/// from) and result (where it finished), all optional. `score` / `putts` stay the authoritative scoring fields on
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
  /// Distance **remaining to the pin** when the shot was played — not how far
  /// the shot travelled. So a tee shot's distance is the hole's yardage, and the
  /// figure shrinks as the hole is played out. Putts leave it null: a putt is
  /// measured in feet on the green, and records [distanceFeet] instead.
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

  /// A putt's distance **remaining to the hole**, in feet — the unit golf, and
  /// every golf game, measures a putt in (schema v8). Only putts
  /// carry it; every other shot leaves it null and records [distanceYards].
  /// `putts` on [HoleResults] stays the count the stats read.
  ///
  /// Declared last because it was added last: `ALTER TABLE ADD COLUMN` appends,
  /// so this order is the one a migrated database has too.
  IntColumn get distanceFeet => integer()
      .nullable()
      .customConstraint('CHECK (distance_feet >= 0)')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {holeResultId, shotNumber},
      ];
}
