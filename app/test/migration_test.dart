// Drift schema migration tests (#24, extended for #35 and each bump since).
//
// These prove the step-based `onUpgrade` harness end to end against drift's
// generated schema snapshots in `test/generated_migrations/`:
//   * each `vN -> vN+1` migration produces the expected schema,
//   * data written at an old version survives the upgrade, and
//   * a freshly created database matches the generated definitions.
//
// When the schema changes: bump `schemaVersion`, dump a new snapshot, add the
// `fromNToN+1` step, regenerate helpers, then extend the cases below. See
// app/README.md > "Database migrations".
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;
import 'generated_migrations/schema_v5.dart' as v5;
import 'generated_migrations/schema_v6.dart' as v6;
import 'generated_migrations/schema_v7.dart' as v7;
import 'generated_migrations/schema_v8.dart' as v8;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates the schema from v1 to v2', () async {
    final connection = await verifier.startAt(1);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Opens the db (running `onUpgrade`) and asserts the resulting sqlite
    // schema matches the generated v2 snapshot.
    await verifier.migrateAndValidate(db, 2);
  });

  test('migration preserves data written at v1', () async {
    final schema = await verifier.schemaAt(1);

    // Seed a course + round through the v1-shaped database (no canary column).
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v1.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    await oldDb.into(oldDb.rounds).insert(
          v1.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v2).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    // The pre-existing rows survive, and the new column is null for them.
    final course = await db.select(db.courses).getSingle();
    expect(course.name, 'Pebble Beach');

    final round = await db.select(db.rounds).getSingle();
    expect(round.date, '2026-05-19');
    expect(round.courseId, courseId);
    expect(round.migrationCanary, isNull);
  });

  test('migrates the schema from v2 to v3', () async {
    final connection = await verifier.startAt(2);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Opens the db (running `onUpgrade`) and asserts the resulting sqlite
    // schema — including the new events table and the rounds.event_id column
    // and index — matches the generated v3 snapshot.
    await verifier.migrateAndValidate(db, 3);
  });

  test('migration preserves data written at v2', () async {
    final schema = await verifier.schemaAt(2);

    // Seed a course + round through the v2-shaped database (no events table,
    // no event_id column).
    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v2.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    await oldDb.into(oldDb.rounds).insert(
          v2.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v3).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    // The pre-existing round survives; its new event_id is null, and the new
    // events table exists and starts empty.
    final round = await db.select(db.rounds).getSingle();
    expect(round.date, '2026-05-19');
    expect(round.courseId, courseId);
    expect(round.eventId, isNull);

    final events = await db.select(db.events).get();
    expect(events, isEmpty);
  });

  test('migrates the schema from v3 to v4', () async {
    final connection = await verifier.startAt(3);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // A data-only migration (#37) — no structural change; the resulting schema
    // must still match the generated v4 snapshot.
    await verifier.migrateAndValidate(db, 4);
  });

  test('v3 -> v4 fixes contradictory putts data (#37)', () async {
    final schema = await verifier.schemaAt(3);

    // Seed rows through the v3-shaped database. The DAO's app-layer invariants
    // don't exist here, so we can write the states this migration is meant to
    // fix.
    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v3.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    final roundId = await oldDb.into(oldDb.rounds).insert(
          v3.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );

    v3.HoleResultsCompanion hole(
      int holeNumber, {
      required int score,
      required int putts,
      required bool upDownSuccess,
    }) {
      // The versioned v3 schema stores booleans as raw ints (0/1).
      return v3.HoleResultsCompanion.insert(
        roundId: roundId,
        holeNumber: holeNumber,
        par: 4,
        score: score,
        yards: 400,
        gir: 0,
        putts: putts,
        upDownAttempt: 1,
        upDownSuccess: upDownSuccess ? 1 : 0,
        penaltyStrokes: 0,
        bunkerVisited: 0,
        sandSave: 0,
        driveDistanceYards: 250,
      );
    }

    // Hole 1: an up/down "success" recorded with 2 putts — Rule A clears the
    // success; its putts stay (2 < 5).
    await oldDb
        .into(oldDb.holeResults)
        .insert(hole(1, score: 5, putts: 2, upDownSuccess: true));
    // Hole 2: putts equal to score — Rule B clamps putts to score - 1.
    await oldDb
        .into(oldDb.holeResults)
        .insert(hole(2, score: 3, putts: 3, upDownSuccess: false));
    // Hole 3 (control): a valid 1-putt up/down success — left untouched.
    await oldDb
        .into(oldDb.holeResults)
        .insert(hole(3, score: 4, putts: 1, upDownSuccess: true));
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v4).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    final rows = await db.holeResultDao.watchForRound(roundId).first;
    final byHole = {for (final r in rows) r.holeNumber: r};

    // Rule A: the 2-putt "success" is cleared; putts untouched.
    expect(byHole[1]!.upDownSuccess, isFalse);
    expect(byHole[1]!.putts, 2);
    // Rule B: putts >= score clamped down to score - 1.
    expect(byHole[2]!.putts, 2);
    expect(byHole[2]!.upDownSuccess, isFalse);
    // Control: the valid 1-putt success survives intact.
    expect(byHole[3]!.upDownSuccess, isTrue);
    expect(byHole[3]!.putts, 1);
  });

  test('migrates the schema from v4 to v5', () async {
    final connection = await verifier.startAt(4);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Recreates `events` with the new `season` column and the
    // UNIQUE(name, season) key (#47); the resulting schema must match the
    // generated v5 snapshot.
    await verifier.migrateAndValidate(db, 5);
  });

  test('v4 -> v5 backfills season 1 and preserves event links (#47)', () async {
    final schema = await verifier.schemaAt(4);

    // Seed through the v4-shaped database (events have no season column): two
    // events — one with a linked round, one empty — plus a course and round.
    final oldDb = v4.DatabaseAtV4(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v4.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    final linkedEventId = await oldDb.into(oldDb.events).insert(
          v4.EventsCompanion.insert(name: 'Club Championship'),
        );
    await oldDb
        .into(oldDb.events)
        .insert(v4.EventsCompanion.insert(name: 'Empty Open'));
    final roundId = await oldDb.into(oldDb.rounds).insert(
          v4.RoundsCompanion.insert(
            date: '2026-05-19',
            courseId: courseId,
            eventId: Value(linkedEventId),
          ),
        );
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v5).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);

    // Every pre-existing event is backfilled to season 1 (each is the sole
    // occurrence of its name today), ordered by name then season.
    final events = await db.eventDao.watchAll().first;
    expect(
      events.map((e) => (e.name, e.season)).toList(),
      [('Club Championship', 1), ('Empty Open', 1)],
    );

    // The round still points at its event — TableMigration preserved row ids.
    final round = await db.roundDao.getById(roundId);
    expect(round!.eventId, linkedEventId);

    // The new (name, season) key is live: a second season of the same name is
    // now allowed, but re-inserting season 1 collides.
    await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship', season: const Value(2)),
    );
    await expectLater(
      db.eventDao.insert(EventsCompanion.insert(name: 'Club Championship')),
      throwsA(isA<Exception>()),
    );
  });

  test('migrates the schema from v5 to v6', () async {
    final connection = await verifier.startAt(5);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Opens the db (running `onUpgrade`) and asserts the resulting sqlite schema
    // — the new course_holes / course_sets / course_set_yards tables, their
    // indexes, and rounds.course_set_id — matches the generated v6 snapshot.
    await verifier.migrateAndValidate(db, 6);
  });

  test('v5 -> v6 adds the course-template tables and preserves data (#36)',
      () async {
    final schema = await verifier.schemaAt(5);

    // Seed a course + round through the v5-shaped database (none of the new
    // tables, no rounds.course_set_id yet).
    final oldDb = v5.DatabaseAtV5(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v5.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    final roundId = await oldDb.into(oldDb.rounds).insert(
          v5.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v6).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);

    // Read back through the v6 shape: v9 replaced its yardage sets, so the
    // app's own DAOs no longer describe this version.
    final atV6 = v6.DatabaseAtV6(schema.newConnection());
    addTearDown(atV6.close);

    // The pre-existing rows survive; the new tables start empty and the round's
    // new course_set_id is null (no backfill).
    final course = await atV6.select(atV6.courses).getSingle();
    expect(course.name, 'Pebble Beach');
    expect(await atV6.select(atV6.courseHoles).get(), isEmpty);
    expect(await atV6.select(atV6.courseSets).get(), isEmpty);
    final round = await atV6.select(atV6.rounds).getSingle();
    expect(round.id, roundId);
    expect(round.courseSetId, isNull);

    // The new tables are live: par/SI card, a named set, and its yardages — and
    // linking the round to the set.
    await atV6.into(atV6.courseHoles).insert(v6.CourseHolesCompanion.insert(
          courseId: courseId,
          holeNumber: 1,
          par: 4,
          strokeIndex: const Value(7),
        ));
    final setId = await atV6.into(atV6.courseSets).insert(
          v6.CourseSetsCompanion.insert(courseId: courseId, name: 'Blue tees'),
        );
    await atV6.into(atV6.courseSetYards).insert(
          v6.CourseSetYardsCompanion.insert(
            courseSetId: setId,
            holeNumber: 1,
            yards: 420,
          ),
        );
    await atV6.update(atV6.rounds).write(
          v6.RoundsCompanion(courseSetId: Value(setId)),
        );

    final card = await atV6.select(atV6.courseHoles).getSingle();
    expect(card.par, 4);
    expect(card.strokeIndex, 7);
    final yards = await atV6.select(atV6.courseSetYards).getSingle();
    expect(yards.yards, 420);
    expect((await atV6.select(atV6.rounds).getSingle()).courseSetId, setId);
  });

  test('migrates the schema from v6 to v7', () async {
    final connection = await verifier.startAt(6);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Adds the hole_shots table and recreates hole_results without the three
    // flat shot columns (#22); the resulting schema must match the v7 snapshot.
    await verifier.migrateAndValidate(db, 7);
  });

  test('v6 -> v7 adds hole_shots and drops the flat columns, preserving data '
      '(#22)', () async {
    final schema = await verifier.schemaAt(6);

    // Seed a course + round + hole_result (with the flat shot columns) through
    // the v6-shaped database.
    final oldDb = v6.DatabaseAtV6(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v6.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    final roundId = await oldDb.into(oldDb.rounds).insert(
          v6.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );
    await oldDb.into(oldDb.holeResults).insert(
          v6.HoleResultsCompanion.insert(
            roundId: roundId,
            holeNumber: 1,
            par: 4,
            score: 5,
            yards: 400,
            gir: 0,
            putts: 2,
            upDownAttempt: 0,
            upDownSuccess: 0,
            penaltyStrokes: 0,
            bunkerVisited: 0,
            sandSave: 0,
            driveDistanceYards: 250,
          ),
        );
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v7).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);

    // The hole_result survives the column drop with its id and scoring intact.
    final holes = await db.holeResultDao.watchForRound(roundId).first;
    expect(holes, hasLength(1));
    expect(holes.single.score, 5);
    final holeResultId = holes.single.id;

    // hole_shots is live and its FK to the (preserved) hole_results id holds.
    // Read with a plain `select` — a `SELECT *` — because this database stops
    // at v7, and the DAO's join names every column the app has today,
    // including ones added after v7.
    expect(await db.select(db.holeShots).get(), isEmpty);
    await db.holeShotDao.replaceForHole(holeResultId, [
      HoleShotsCompanion.insert(
        holeResultId: holeResultId,
        shotNumber: 1,
        club: const Value('Driver'),
        distanceYards: const Value(268),
        lie: const Value('Tee'),
        result: const Value('Fairway'),
      ),
    ]);
    final shots = await db.select(db.holeShots).get();
    expect(shots, hasLength(1));
    expect(shots.single.holeResultId, holeResultId);
    expect(shots.single.club, 'Driver');
    expect(shots.single.distanceYards, 268);
  });

  test('migrates the schema from v7 to v8', () async {
    final connection = await verifier.startAt(7);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Adds the nullable hole_shots.distance_feet column for putts; the
    // resulting schema must match the v8 snapshot.
    await verifier.migrateAndValidate(db, 8);
  });

  test('v7 -> v8 keeps every shot and leaves its putt distance unset',
      () async {
    final schema = await verifier.schemaAt(7);

    // Seed a hole with a full shot list — putts included — through the
    // v7-shaped database, which has no distance_feet column.
    final oldDb = v7.DatabaseAtV7(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v7.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    final roundId = await oldDb.into(oldDb.rounds).insert(
          v7.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );
    final holeResultId = await oldDb.into(oldDb.holeResults).insert(
          v7.HoleResultsCompanion.insert(
            roundId: roundId,
            holeNumber: 1,
            par: 4,
            score: 4,
            yards: 400,
            gir: 1,
            putts: 2,
            upDownAttempt: 0,
            upDownSuccess: 0,
            penaltyStrokes: 0,
            bunkerVisited: 0,
            sandSave: 0,
          ),
        );
    for (final (n, club, lie, yards, result) in [
      (1, 'Driver', 'Tee', 400, null),
      (2, '8 Iron', 'Fairway', 140, null),
      (3, 'Putter', 'Green', null, null),
      (4, 'Putter', 'Green', null, 'Holed'),
    ]) {
      await oldDb.into(oldDb.holeShots).insert(
            v7.HoleShotsCompanion.insert(
              holeResultId: holeResultId,
              shotNumber: n,
              club: Value(club),
              distanceYards: Value(yards),
              lie: Value(lie),
              result: Value(result),
            ),
          );
    }
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v8).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);

    final shots = (await db.holeShotDao.watchForRound(roundId).first)[1]!;
    expect([for (final s in shots) s.club],
        ['Driver', '8 Iron', 'Putter', 'Putter']);
    expect([for (final s in shots) s.distanceYards], [400, 140, null, null]);
    expect(shots.last.result, 'Holed');
    expect([for (final s in shots) s.distanceFeet], everyElement(isNull));

    // The new column is live: a putt can be saved with its distance.
    await db.holeShotDao.replaceForHole(holeResultId, [
      HoleShotsCompanion.insert(
        holeResultId: holeResultId,
        shotNumber: 1,
        club: const Value('Putter'),
        lie: const Value('Green'),
        distanceFeet: const Value(12),
      ),
    ]);
    final putt = (await db.holeShotDao.watchForRound(roundId).first)[1]!;
    expect(putt.single.distanceFeet, 12);
  });

  test('v7 -> v8 rewrites putts saved in yards in feet, and only putts',
      () async {
    final schema = await verifier.schemaAt(7);

    // Two holes saved the way the v0.4.0 shot list let a player save them,
    // every distance in yards: one finished with two putts, one chipped in
    // from the green with no putts at all.
    final oldDb = v7.DatabaseAtV7(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v7.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    final roundId = await oldDb.into(oldDb.rounds).insert(
          v7.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );
    Future<int> hole(int number, {required int score, required int putts}) =>
        oldDb.into(oldDb.holeResults).insert(
              v7.HoleResultsCompanion.insert(
                roundId: roundId,
                holeNumber: number,
                par: 4,
                score: score,
                yards: 400,
                gir: putts > 0 ? 1 : 0,
                putts: putts,
                upDownAttempt: 0,
                upDownSuccess: 0,
                penaltyStrokes: 0,
                bunkerVisited: 0,
                sandSave: 0,
              ),
            );
    final twoPutts = await hole(1, score: 4, putts: 2);
    final chipIn = await hole(2, score: 2, putts: 0);
    for (final (holeId, n, club, lie, yards, result) in [
      (twoPutts, 1, 'Driver', 'Tee', 400, null),
      (twoPutts, 2, '8 Iron', 'Fairway', 140, null),
      (twoPutts, 3, 'Putter', 'Green', 5, null),
      (twoPutts, 4, 'Putter', 'Green', 1, 'Holed'),
      (chipIn, 1, 'Driver', 'Tee', 380, null),
      (chipIn, 2, 'Lob Wedge', 'Green', 3, 'Holed'),
    ]) {
      await oldDb.into(oldDb.holeShots).insert(
            v7.HoleShotsCompanion.insert(
              holeResultId: holeId,
              shotNumber: n,
              club: Value(club),
              distanceYards: Value(yards),
              lie: Value(lie),
              result: Value(result),
            ),
          );
    }
    await oldDb.close();

    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);

    final byHole = await db.holeShotDao.watchForRound(roundId).first;
    // The putts are in feet now (5 yd = 15 ft, 1 yd = 3 ft) and no longer in
    // yards; the shots before them keep their yards.
    expect([for (final s in byHole[1]!) s.distanceYards],
        [400, 140, null, null]);
    expect([for (final s in byHole[1]!) s.distanceFeet], [null, null, 15, 3]);
    expect(byHole[1]!.last.result, 'Holed');
    // A hole with no putts has none to convert: its last shot, from the
    // green, is still a shot in yards.
    expect([for (final s in byHole[2]!) s.distanceYards], [380, 3]);
    expect([for (final s in byHole[2]!) s.distanceFeet], [null, null]);
  });

  test('migrates the schema from v8 to v9', () async {
    final connection = await verifier.startAt(8);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Splits yardage sets into tee sets (with course yards) and pin sets (with
    // tee-to-pin yards), and rebuilds rounds around tee_set_id / pin_set_id;
    // the resulting schema must match the v9 snapshot.
    await verifier.migrateAndValidate(db, 9);
  });

  test('v8 -> v9 carries each yardage set across as a tee set', () async {
    final schema = await verifier.schemaAt(8);

    // A v8 database the way v0.6.0 could leave one: two sets on one course,
    // rounds on a set and on none, holes and shots under the rounds — and one
    // round whose set is another course's, which editing a round's course
    // after picking its set could produce.
    final oldDb = v8.DatabaseAtV8(schema.newConnection());
    final pebble = await oldDb.into(oldDb.courses).insert(
          v8.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    final augusta = await oldDb.into(oldDb.courses).insert(
          v8.CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
        );
    // Ids with a gap, so the migration has to keep them rather than renumber.
    final blue = await oldDb.into(oldDb.courseSets).insert(
          v8.CourseSetsCompanion.insert(
            id: const Value(3),
            courseId: pebble,
            name: 'Blue tees',
          ),
        );
    final gold = await oldDb.into(oldDb.courseSets).insert(
          v8.CourseSetsCompanion.insert(courseId: pebble, name: 'Gold tees'),
        );
    for (var h = 1; h <= 18; h++) {
      await oldDb.into(oldDb.courseSetYards).insert(
            v8.CourseSetYardsCompanion.insert(
              courseSetId: blue,
              holeNumber: h,
              yards: 400 + h,
            ),
          );
    }
    await oldDb.into(oldDb.courseSetYards).insert(
          v8.CourseSetYardsCompanion.insert(
            courseSetId: gold,
            holeNumber: 1,
            yards: 455,
          ),
        );
    final onBlue = await oldDb.into(oldDb.rounds).insert(
          v8.RoundsCompanion.insert(
            date: '2026-05-19',
            courseId: pebble,
            courseSetId: Value(blue),
            notes: const Value('windy'),
          ),
        );
    final onNone = await oldDb.into(oldDb.rounds).insert(
          v8.RoundsCompanion.insert(date: '2026-05-20', courseId: pebble),
        );
    final mismatched = await oldDb.into(oldDb.rounds).insert(
          v8.RoundsCompanion.insert(
            date: '2026-05-21',
            courseId: augusta,
            courseSetId: Value(gold),
          ),
        );
    final holeId = await oldDb.into(oldDb.holeResults).insert(
          v8.HoleResultsCompanion.insert(
            roundId: onBlue,
            holeNumber: 1,
            par: 4,
            score: 4,
            yards: 401,
            gir: 1,
            putts: 2,
            upDownAttempt: 0,
            upDownSuccess: 0,
            penaltyStrokes: 0,
            bunkerVisited: 0,
            sandSave: 0,
          ),
        );
    await oldDb.into(oldDb.holeShots).insert(
          v8.HoleShotsCompanion.insert(
            holeResultId: holeId,
            shotNumber: 1,
            club: const Value('Driver'),
            distanceYards: const Value(401),
          ),
        );
    await oldDb.close();

    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);

    // Each set is a tee set now, ids and names kept, and its yardages are that
    // tee set's course yards.
    final tees = await db.select(db.teeSets).get();
    expect(
      [for (final t in tees) (t.id, t.courseId, t.name)],
      [(blue, pebble, 'Blue tees'), (gold, pebble, 'Gold tees')],
    );
    final blueYards = await db.yardageDao.getCourseYards(blue);
    expect([for (final y in blueYards) y.yards],
        [for (var h = 1; h <= 18; h++) 400 + h]);
    expect((await db.yardageDao.getCourseYards(gold)).single.yards, 455);
    // v8 had no pins, so nothing is invented for them.
    expect(await db.select(db.pinSets).get(), isEmpty);
    expect(await db.select(db.teeToPinYards).get(), isEmpty);

    // A round on a set is played from that tee set, with no pin set; the
    // mismatched link is cleared rather than carried into v9.
    final rounds = {
      for (final r in await db.select(db.rounds).get()) r.id: r,
    };
    expect(rounds[onBlue]!.teeSetId, blue);
    expect(rounds[onBlue]!.pinSetId, isNull);
    expect(rounds[onBlue]!.notes, 'windy');
    expect(rounds[onNone]!.teeSetId, isNull);
    expect(rounds[mismatched]!.teeSetId, isNull);
    expect(rounds[mismatched]!.courseId, augusta);

    // The rebuilt rounds table keeps its holes and their shots attached.
    final holes = await db.holeResultDao.watchForRound(onBlue).first;
    expect(holes.single.id, holeId);
    final shots = (await db.holeShotDao.watchForRound(onBlue).first)[1]!;
    expect(shots.single.club, 'Driver');
    final fkProblems =
        await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fkProblems, isEmpty);

    // The old tables are gone.
    final leftovers = await db
        .customSelect("SELECT name FROM sqlite_master WHERE name LIKE "
            "'course_set%'")
        .get();
    expect(leftovers, isEmpty);

    // And the new ones are live: a pin set and its tee-to-pin yards, a round
    // on the whole yardage set, and a new tee set that doesn't reuse an id.
    final sunday = await db.yardageDao.insertPinSet(
      PinSetsCompanion.insert(courseId: pebble, name: 'Sunday pins'),
    );
    await db.yardageDao.upsertTeeToPinYard(TeeToPinYardsCompanion.insert(
      teeSetId: blue,
      pinSetId: sunday,
      holeNumber: 1,
      yards: 388,
    ));
    await db.roundDao.updateById(
      onBlue,
      RoundsCompanion(pinSetId: Value(sunday)),
    );
    final labelled = await db.roundDao.watchAllWithCourse().first;
    expect(
      labelled.firstWhere((r) => r.round.id == onBlue).yardageSetLabel,
      'Blue tees · Sunday pins',
    );
    final white = await db.yardageDao.insertTeeSet(
      TeeSetsCompanion.insert(courseId: pebble, name: 'White tees'),
    );
    expect(white, greaterThan(gold));
  });

  test('a freshly created database matches the generated schema', () async {
    final db = GolfyDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Validates that `onCreate` builds exactly what the current Dart
    // definitions describe — catches a forgotten migration after a table edit.
    await db.validateDatabaseSchema();
  });
}
