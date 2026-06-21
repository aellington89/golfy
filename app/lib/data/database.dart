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
  int get schemaVersion => 3;

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
        ),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
