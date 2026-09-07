import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/course_dao.dart';
import 'daos/course_hole_dao.dart';
import 'daos/course_set_dao.dart';
import 'daos/dashboard_dao.dart';
import 'daos/event_dao.dart';
import 'daos/hole_result_dao.dart';
import 'daos/round_dao.dart';
import 'schema_versions.dart';
import 'tables/course_holes.dart';
import 'tables/course_set_yards.dart';
import 'tables/course_sets.dart';
import 'tables/courses.dart';
import 'tables/events.dart';
import 'tables/hole_results.dart';
import 'tables/rounds.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Courses,
    Rounds,
    HoleResults,
    Events,
    CourseHoles,
    CourseSets,
    CourseSetYards,
  ],
  daos: [
    CourseDao,
    CourseHoleDao,
    CourseSetDao,
    RoundDao,
    HoleResultDao,
    DashboardDao,
    EventDao,
  ],
)
class GolfyDatabase extends _$GolfyDatabase {
  GolfyDatabase() : super(driftDatabase(name: 'golfy'));

  GolfyDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
          // v5 -> v6: course templates (#36). `course_holes` holds the shared
          // per-hole par + stroke index; `course_sets` names each yardage set
          // (pin set / tee box) and `course_set_yards` holds a set's 18-hole
          // yardage card; `rounds.course_set_id` records which set a round was
          // played on (SET NULL on delete). Plain additive change — existing
          // courses simply have no template yet, and Hole Entry falls back to
          // its defaults until one is entered.
          from5To6: (m, schema) async {
            await m.createTable(schema.courseHoles);
            await m.create(schema.idxCourseHolesCourse);
            await m.createTable(schema.courseSets);
            await m.create(schema.idxCourseSetsCourse);
            await m.createTable(schema.courseSetYards);
            await m.create(schema.idxCourseSetYardsSet);
            await m.addColumn(schema.rounds, schema.rounds.courseSetId);
            await m.create(schema.idxRoundsCourseSet);
          },
        ),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
