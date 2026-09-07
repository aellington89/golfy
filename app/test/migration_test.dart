// Drift schema migration tests (#24, extended for #35).
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

    // The pre-existing rows survive; the new tables start empty and the round's
    // new course_set_id is null (no backfill).
    final course = await db.select(db.courses).getSingle();
    expect(course.name, 'Pebble Beach');
    expect(await db.courseHoleDao.watchForCourse(courseId).first, isEmpty);
    expect(await db.courseSetDao.watchSetsForCourse(courseId).first, isEmpty);
    final round = await db.roundDao.getById(roundId);
    expect(round!.courseSetId, isNull);

    // The new tables are live: par/SI card, a named set, and its yardages — and
    // linking the round to the set.
    await db.courseHoleDao.replaceForCourse(courseId, [
      CourseHolesCompanion.insert(
        courseId: courseId,
        holeNumber: 1,
        par: 4,
        strokeIndex: const Value(7),
      ),
    ]);
    final setId = await db.courseSetDao.insertSet(
      CourseSetsCompanion.insert(courseId: courseId, name: 'Blue tees'),
    );
    await db.courseSetDao.replaceYardsForSet(setId, [
      CourseSetYardsCompanion.insert(
        courseSetId: setId,
        holeNumber: 1,
        yards: 420,
      ),
    ]);
    await db.roundDao.updateById(
      roundId,
      RoundsCompanion(courseSetId: Value(setId)),
    );

    final card = await db.courseHoleDao.watchForCourse(courseId).first;
    expect(card.single.par, 4);
    expect(card.single.strokeIndex, 7);
    final yards = await db.courseSetDao.watchYardsForSet(setId).first;
    expect(yards.single.yards, 420);
    expect((await db.roundDao.getById(roundId))!.courseSetId, setId);
  });

  test('a freshly created database matches the generated schema', () async {
    final db = GolfyDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Validates that `onCreate` builds exactly what the current Dart
    // definitions describe — catches a forgotten migration after a table edit.
    await db.validateDatabaseSchema();
  });
}
