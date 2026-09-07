import 'package:drift/drift.dart';

import 'course_sets.dart';
import 'courses.dart';
import 'events.dart';

@TableIndex(name: 'idx_rounds_date', columns: {#date})
@TableIndex(name: 'idx_rounds_course', columns: {#courseId})
@TableIndex(name: 'idx_rounds_event', columns: {#eventId})
@TableIndex(name: 'idx_rounds_course_set', columns: {#courseSetId})
class Rounds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  IntColumn get courseId => integer()
      .references(Courses, #id, onDelete: KeyAction.restrict)();
  IntColumn get roundNumber => integer().withDefault(const Constant(1))();

  /// Legacy free-text tee-set label from the original schema. Never written by
  /// the app; superseded by [courseSetId] (#36) and left in place only so the
  /// v6 migration stays additive. Safe to drop in a later tidy.
  TextColumn get teeSet => text().nullable()();

  /// The [CourseSets] yardage set this round was played on (#36), or null for a
  /// round with no set chosen. `SET NULL` on delete so removing a set detaches
  /// its rounds rather than destroying them; Hole Entry pulls the round's
  /// yardages from this set.
  IntColumn get courseSetId => integer()
      .nullable()
      .references(CourseSets, #id, onDelete: KeyAction.setNull)();
  TextColumn get weather => text().nullable()();
  IntColumn get windSpeedMph => integer().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Inert column added in schema v2 to prove the drift migration pipeline
  /// end to end (#24). It carries no behaviour and is intentionally nullable so
  /// the upgrade is a plain `addColumn`. A later real migration (e.g. #22) may
  /// drop it.
  TextColumn get migrationCanary => text().nullable()();

  /// Optional link to the [Events] competition this round belongs to (#35).
  /// Nullable because casual rounds have no event; `SET NULL` on delete so
  /// removing an event detaches its rounds rather than destroying their holes.
  IntColumn get eventId => integer()
      .nullable()
      .references(Events, #id, onDelete: KeyAction.setNull)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, courseId, roundNumber},
      ];
}
