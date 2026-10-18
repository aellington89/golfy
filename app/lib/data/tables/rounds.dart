import 'package:drift/drift.dart';

import 'courses.dart';
import 'events.dart';
import 'pin_sets.dart';
import 'tee_sets.dart';

@TableIndex(name: 'idx_rounds_date', columns: {#date})
@TableIndex(name: 'idx_rounds_course', columns: {#courseId})
@TableIndex(name: 'idx_rounds_event', columns: {#eventId})
@TableIndex(name: 'idx_rounds_tee_set', columns: {#teeSetId})
@TableIndex(name: 'idx_rounds_pin_set', columns: {#pinSetId})
class Rounds extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  IntColumn get courseId => integer()
      .references(Courses, #id, onDelete: KeyAction.restrict)();
  IntColumn get roundNumber => integer().withDefault(const Constant(1))();

  /// The [TeeSets] tee box this round was played from, or null when none was
  /// chosen. With [pinSetId] it is the round's **yardage set**: Hole Entry
  /// pre-fills each hole with that pair's tee-to-pin yards, or with this tee
  /// set's course yards when the round has no pin set.
  ///
  /// `SET NULL` on delete, so removing a tee set detaches its rounds rather
  /// than destroying them. Must belong to [courseId] — `RoundDao` checks.
  IntColumn get teeSetId => integer()
      .nullable()
      .references(TeeSets, #id, onDelete: KeyAction.setNull)();

  /// The [PinSets] pin positions this round was played to, or null when none
  /// was chosen. The other half of the round's yardage set, beside
  /// [teeSetId]. `SET NULL` on delete; must belong to [courseId].
  IntColumn get pinSetId => integer()
      .nullable()
      .references(PinSets, #id, onDelete: KeyAction.setNull)();

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
