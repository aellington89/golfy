import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/backup_dao.dart';
import 'daos/course_dao.dart';
import 'daos/course_hole_dao.dart';
import 'daos/dashboard_dao.dart';
import 'daos/event_dao.dart';
import 'daos/hole_result_dao.dart';
import 'daos/hole_shot_dao.dart';
import 'daos/round_dao.dart';
import 'daos/yardage_dao.dart';
import 'schema_versions.dart';
import 'tables/course_holes.dart';
import 'tables/course_yards.dart';
import 'tables/courses.dart';
import 'tables/events.dart';
import 'tables/hole_results.dart';
import 'tables/hole_shots.dart';
import 'tables/pin_sets.dart';
import 'tables/rounds.dart';
import 'tables/tee_sets.dart';
import 'tables/tee_to_pin_yards.dart';
import 'upgrades/putts_in_feet.dart';
import 'upgrades/split_yardage_sets.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Courses,
    Rounds,
    HoleResults,
    Events,
    CourseHoles,
    TeeSets,
    CourseYards,
    PinSets,
    TeeToPinYards,
    HoleShots,
  ],
  daos: [
    BackupDao,
    CourseDao,
    CourseHoleDao,
    YardageDao,
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
  int get schemaVersion => 9;

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
          // v8 -> v9: yardage splits by tee set and pin set. A hole has course
          // yards per tee set (`course_yards`) and tee-to-pin yards per tee
          // set × pin set (`tee_to_pin_yards`); a round's yardage set is its
          // `tee_set_id` + `pin_set_id`. Each v8 set was one such pair, named
          // "Tee Set - Pin Set", holding the pair's tee-to-pin yards — so its
          // name splits into a tee set and a pin set, its yards become their
          // tee-to-pin yards, and a round played on it is played on the pair.
          // The split is the frozen rule the v8 backup upgrader uses too
          // (`upgrades/split_yardage_sets.dart`). `rounds` is rebuilt without
          // `course_set_id` and the never-written `tee_set` label.
          from8To9: (m, schema) async {
            // One transaction, so an interrupted step leaves v8 as it was.
            final db = m.database;
            await db.transaction(() async {
              final split = splitYardageSets(
                [
                  for (final r in await db
                      .customSelect('SELECT id, course_id, name FROM course_sets')
                      .get())
                    (
                      id: r.read<int>('id'),
                      courseId: r.read<int>('course_id'),
                      name: r.read<String>('name'),
                    ),
                ],
                [
                  for (final r in await db
                      .customSelect('SELECT id, course_set_id, hole_number, '
                          'yards FROM course_set_yards')
                      .get())
                    (
                      id: r.read<int>('id'),
                      courseSetId: r.read<int>('course_set_id'),
                      holeNumber: r.read<int>('hole_number'),
                      yards: r.read<int>('yards'),
                    ),
                ],
              );
              // Which set each round was played on, read before the rebuild
              // drops the column.
              final roundSets = [
                for (final r in await db
                    .customSelect('SELECT id, course_id, course_set_id '
                        'FROM rounds WHERE course_set_id IS NOT NULL')
                    .get())
                  (
                    id: r.read<int>('id'),
                    courseId: r.read<int>('course_id'),
                    setId: r.read<int>('course_set_id'),
                  ),
              ];

              await m.createTable(schema.teeSets);
              await m.create(schema.idxTeeSetsCourse);
              await m.createTable(schema.pinSets);
              await m.create(schema.idxPinSetsCourse);
              await m.createTable(schema.courseYards);
              await m.create(schema.idxCourseYardsTeeSet);
              await m.createTable(schema.teeToPinYards);
              await m.create(schema.idxTeeToPinYardsTeeSet);
              await m.create(schema.idxTeeToPinYardsPinSet);
              for (final t in split.teeSets) {
                await db.customStatement(
                  'INSERT INTO tee_sets (id, course_id, name) VALUES (?, ?, ?)',
                  [t.id, t.courseId, t.name],
                );
              }
              for (final p in split.pinSets) {
                await db.customStatement(
                  'INSERT INTO pin_sets (id, course_id, name) VALUES (?, ?, ?)',
                  [p.id, p.courseId, p.name],
                );
              }
              for (final y in split.courseYards) {
                await db.customStatement(
                  'INSERT INTO course_yards (id, tee_set_id, hole_number, '
                  'yards) VALUES (?, ?, ?, ?)',
                  [y.id, y.teeSetId, y.holeNumber, y.yards],
                );
              }
              for (final y in split.teeToPinYards) {
                await db.customStatement(
                  'INSERT INTO tee_to_pin_yards (id, tee_set_id, pin_set_id, '
                  'hole_number, yards) VALUES (?, ?, ?, ?, ?)',
                  [y.id, y.teeSetId, y.pinSetId, y.holeNumber, y.yards],
                );
              }

              // TableMigration re-runs the old table's index statements after
              // the rebuild, and this one names a column the new table drops.
              await db.customStatement('DROP INDEX idx_rounds_course_set');
              await m.alterTable(
                TableMigration(
                  schema.rounds,
                  newColumns: [schema.rounds.teeSetId, schema.rounds.pinSetId],
                ),
              );
              await m.create(schema.idxRoundsTeeSet);
              await m.create(schema.idxRoundsPinSet);
              for (final round in roundSets) {
                final pair = split.bySetId[round.setId];
                // A set on another course — possible in v8 by editing a
                // round's course after picking its set — would pre-fill yards
                // for different holes. v9 refuses that link, so it is left
                // unset rather than carried across.
                if (pair == null || pair.courseId != round.courseId) continue;
                await db.customStatement(
                  'UPDATE rounds SET tee_set_id = ?, pin_set_id = ? '
                  'WHERE id = ?',
                  [pair.teeSetId, pair.pinSetId, round.id],
                );
              }

              await m.deleteTable('course_set_yards');
              await m.deleteTable('course_sets');
            });
          },
        ),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
