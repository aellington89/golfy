import 'package:drift/drift.dart';

import 'courses.dart';

@TableIndex(name: 'idx_rounds_date', columns: {#date})
@TableIndex(name: 'idx_rounds_course', columns: {#courseId})
class Rounds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  IntColumn get courseId => integer()
      .references(Courses, #id, onDelete: KeyAction.restrict)();
  IntColumn get roundNumber => integer().withDefault(const Constant(1))();
  TextColumn get teeSet => text().nullable()();
  TextColumn get weather => text().nullable()();
  IntColumn get windSpeedMph => integer().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Inert column added in schema v2 to prove the drift migration pipeline
  /// end to end (#24). It carries no behaviour and is intentionally nullable so
  /// the upgrade is a plain `addColumn`. A later real migration (e.g. #22) may
  /// drop it.
  TextColumn get migrationCanary => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, courseId, roundNumber},
      ];
}
