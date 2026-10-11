import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/backup_dao.dart';
import 'daos/course_dao.dart';
import 'daos/course_hole_dao.dart';
import 'daos/course_set_dao.dart';
import 'daos/dashboard_dao.dart';
import 'daos/event_dao.dart';
import 'daos/hole_result_dao.dart';
import 'daos/hole_shot_dao.dart';
import 'daos/round_dao.dart';
import 'schema_versions.dart';
import 'tables/course_holes.dart';
import 'tables/course_set_yards.dart';
import 'tables/course_sets.dart';
import 'tables/courses.dart';
import 'tables/events.dart';
import 'tables/hole_results.dart';
import 'tables/hole_shots.dart';
import 'tables/rounds.dart';
import 'upgrades/putts_in_feet.dart';

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
    HoleShots,
  ],
  daos: [
    BackupDao,
    CourseDao,
    CourseHoleDao,
    CourseSetDao,
    RoundDao,
    HoleResultDao,
    HoleShotDao,
    DashboardDao,
    EventDao,
  ],
)
class GolfyDatabase extends _$GolfyDatabase {
  GolfyDatabase() : super(driftDatabase(name: 'golfy'));

  GolfyDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

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
          // v6 -> v7: per-shot tracking (#22). Add the `hole_shots` list table
          // and its index, then recreate `hole_results` WITHOUT the three flat
          // shot columns (`tee_club`, `drive_distance_yards`,
          // `approach_distance_yards`) they supersede — a `TableMigration`
          // copies the surviving columns (and row ids, so the new hole_shots FK
          // stays valid); its index is recreated after.
          from6To7: (m, schema) async {
            await m.createTable(schema.holeShots);
            await m.create(schema.idxHoleShotsResult);
            // Recreates hole_results without the flat shot columns; the
            // TableMigration also re-creates the table's own idx_holes_round.
            await m.alterTable(TableMigration(schema.holeResults));
          },
          // v7 -> v8: putts record their distance to the hole in feet
          // (`hole_shots.distance_feet`). Add the column, then move every putt
          // saved with a distance in yards — the only unit there was — into
          // it, in feet. Which rows are putts is decided by the same frozen
          // rule the v7 backup upgrader uses (`upgrades/putts_in_feet.dart`),
          // so a restored v7 backup matches a migrated v7 database. Shots that
          // aren't putts keep their yards.
          from7To8: (m, schema) async {
            // One transaction: the conversion can touch thousands of rows,
            // which run far faster together than as a commit each, and a step
            // interrupted partway leaves the database as it was rather than
            // with the column added and half its putts converted.
            final db = m.database;
            await db.transaction(() async {
              await m.addColumn(
                  schema.holeShots, schema.holeShots.distanceFeet);
              final puttsByHole = {
                for (final r in await db
                    .customSelect('SELECT id, putts FROM hole_results')
                    .get())
                  r.read<int>('id'): r.read<int>('putts'),
              };
              final shots = [
                for (final r in await db
                    .customSelect('SELECT id, hole_result_id, shot_number, '
                        'club, lie, distance_yards FROM hole_shots')
                    .get())
                  (
                    id: r.read<int>('id'),
                    holeResultId: r.read<int>('hole_result_id'),
                    shotNumber: r.read<int>('shot_number'),
                    club: r.readNullable<String>('club'),
                    lie: r.readNullable<String>('lie'),
                    distanceYards: r.readNullable<int>('distance_yards'),
                  ),
              ];
              for (final id in puttsSavedInYards(shots, puttsByHole)) {
                await db.customStatement(
                  'UPDATE hole_shots '
                  'SET distance_feet = distance_yards * $feetPerYard, '
                  'distance_yards = NULL WHERE id = ?',
                  [id],
                );
              }
            });
          },
        ),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
