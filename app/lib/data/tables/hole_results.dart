import 'package:drift/drift.dart';

import 'rounds.dart';

@TableIndex(name: 'idx_holes_round', columns: {#roundId})
class HoleResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get roundId =>
      integer().references(Rounds, #id, onDelete: KeyAction.cascade)();
  IntColumn get holeNumber => integer()
      .customConstraint('NOT NULL CHECK (hole_number BETWEEN 1 AND 18)')();
  IntColumn get par =>
      integer().customConstraint('NOT NULL CHECK (par BETWEEN 3 AND 5)')();
  IntColumn get score =>
      integer().customConstraint('NOT NULL CHECK (score >= 1)')();
  IntColumn get yards =>
      integer().customConstraint('NOT NULL CHECK (yards >= 0)')();
  BoolColumn get fairwayHit => boolean().nullable()();
  BoolColumn get gir => boolean()();
  IntColumn get putts =>
      integer().customConstraint('NOT NULL CHECK (putts >= 0)')();
  BoolColumn get upDownAttempt => boolean()();
  BoolColumn get upDownSuccess => boolean()();
  IntColumn get penaltyStrokes => integer()
      .customConstraint('NOT NULL CHECK (penalty_strokes >= 0)')();
  BoolColumn get bunkerVisited => boolean()();
  BoolColumn get sandSave => boolean()();
  IntColumn get driveDistanceYards => integer()
      .customConstraint('NOT NULL CHECK (drive_distance_yards >= 0)')();
  IntColumn get approachDistanceYards => integer()
      .nullable()
      .customConstraint('CHECK (approach_distance_yards >= 0)')();
  TextColumn get teeClub => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {roundId, holeNumber},
      ];
}
