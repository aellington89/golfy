import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/course_dao.dart';
import 'daos/dashboard_dao.dart';
import 'daos/event_dao.dart';
import 'daos/hole_result_dao.dart';
import 'daos/round_dao.dart';
import 'schema_versions.dart';
import 'tables/courses.dart';
import 'tables/events.dart';
import 'tables/hole_results.dart';
import 'tables/rounds.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Courses, Rounds, HoleResults, Events],
  daos: [CourseDao, RoundDao, HoleResultDao, DashboardDao, EventDao],
)
class GolfyDatabase extends _$GolfyDatabase {
  GolfyDatabase() : super(driftDatabase(name: 'golfy'));

  GolfyDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: stepByStep(
          // v1 -> v2: add the inert migration-canary column to `rounds` (#24).
          from1To2: (m, schema) async {
            await m.addColumn(schema.rounds, schema.rounds.migrationCanary);
          },
          // v2 -> v3: add the `events` table, the optional `rounds.event_id`
          // FK (SET NULL on delete), and its index (#35).
          from2To3: (m, schema) async {
            await m.createTable(schema.events);
            await m.addColumn(schema.rounds, schema.rounds.eventId);
            await m.create(schema.idxRoundsEvent);
          },
          // v3 -> v4: data-only fix (#37) — no structural change. Enforce the
          // two putts invariants on rows written before they existed.
          from3To4: (m, schema) async {
            // An up & down is a 1-putt (or chip-in); clear any success recorded
            // with 2+ putts. Runs BEFORE the clamp below so a 2-putt "success"
            // isn't resurrected once its putts are lowered.
            await m.database.customStatement(
              'UPDATE hole_results SET up_down_success = 0 '
              'WHERE up_down_success = 1 AND putts > 1',
            );
            // The tee shot is never a putt, so putts < score always. Clamp any
            // row that meets or exceeds score down to the max valid value.
            await m.database.customStatement(
              'UPDATE hole_results SET putts = score - 1 WHERE putts >= score',
            );
          },
          // v4 -> v5: events gain a `season` column so a recurring competition
          // is one row per season, and the unique key becomes (name, season)
          // (#47). Changing a table-level UNIQUE means recreating the table;
          // every existing event is the sole occurrence of its name today, so
          // each is seeded to season 1. Round links (`rounds.event_id`) survive
          // — `TableMigration` copies row ids, and foreign keys are off during
          // migrations (they're enabled only in `beforeOpen`, which runs after).
          from4To5: (m, schema) async {
            await m.alterTable(
              TableMigration(
                schema.events,
                columnTransformer: {
                  schema.events.season: const Constant(1),
                },
                newColumns: [schema.events.season],
              ),
            );
          },
        ),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
