import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';

import '_fixtures.dart';

void main() {
  late GolfyDatabase db;
  late TestFixtures fx;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fx = TestFixtures(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('RoundDao.insert + getById', () {
    test('round-trips a round', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid, date: '2026-04-01');
      final row = await db.roundDao.getById(rid);
      expect(row, isNotNull);
      expect(row!.id, rid);
      expect(row.courseId, cid);
      expect(row.date, '2026-04-01');
    });

    test('getById returns null for unknown id', () async {
      final row = await db.roundDao.getById(9999);
      expect(row, isNull);
    });

    test('FK rejects an insert with a non-existent course_id', () async {
      // PRAGMA foreign_keys=ON makes the courseId column reject any value
      // that isn't a real course row.
      await expectLater(
        fx.insertRound(9999),
        throwsA(isA<Exception>()),
      );
    });

    test('roundNumber defaults to 1 when omitted from the companion',
        () async {
      final cid = await fx.insertCourse();
      // Use a raw companion that omits roundNumber — fixtures always set it,
      // but the DAO must honour the schema-level default.
      final rid = await db.roundDao.insert(RoundsCompanion.insert(
        date: '2026-05-01',
        courseId: cid,
      ));
      final row = await db.roundDao.getById(rid);
      expect(row!.roundNumber, 1);
    });
  });

  group('RoundDao.deleteById', () {
    test('returns 1 when a row was deleted', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      final n = await db.roundDao.deleteById(rid);
      expect(n, 1);
      expect(await db.roundDao.getById(rid), isNull);
    });

    test('returns 0 when no row matched', () async {
      final n = await db.roundDao.deleteById(9999);
      expect(n, 0);
    });

    test('cascade-deletes hole_results via schema FK', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      await fx.upsertHole(rid, 1);
      await fx.upsertHole(rid, 2);
      await db.roundDao.deleteById(rid);
      expect(await db.holeResultDao.countForRound(rid), 0);
    });

    test('leaves the parent course intact (no upward cascade)', () async {
      // AC #5 (#12): deleting the only round for a course must NOT remove the
      // course. The rounds → courses FK is RESTRICT, so a round delete never
      // propagates upward; only hole_results cascade down.
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      await db.roundDao.deleteById(rid);
      final courses = await db.courseDao.watchAll().first;
      expect(courses.map((c) => c.id), contains(cid));
    });
  });

  group('RoundDao.watchAllWithCourse', () {
    test('emits empty list when no rows', () async {
      final first = await db.roundDao.watchAllWithCourse().first;
      expect(first, isEmpty);
    });

    test('joins course name onto each round', () async {
      final cid = await fx.insertCourse(
        name: 'Pebble Beach',
        gameTitle: 'PGA Tour 2K25',
      );
      await fx.insertRound(cid);
      final rows = await db.roundDao.watchAllWithCourse().first;
      expect(rows, hasLength(1));
      expect(rows.single.courseName, 'Pebble Beach');
      expect(rows.single.round.courseId, cid);
    });

    test('orders by (date DESC, id DESC)', () async {
      final cid = await fx.insertCourse();
      final r1 = await fx.insertRound(cid, date: '2026-04-01');
      final r2 = await fx.insertRound(cid, date: '2026-05-01');
      final r3 = await fx.insertRound(cid, date: '2026-04-01',
          roundNumber: 2);

      final rows = await db.roundDao.watchAllWithCourse().first;
      expect(rows.map((r) => r.round.id).toList(), [r2, r3, r1]);
    });

    test('holesEntered is 0 for a round with no hole_results', () async {
      final cid = await fx.insertCourse();
      await fx.insertRound(cid);
      final rows = await db.roundDao.watchAllWithCourse().first;
      expect(rows.single.holesEntered, 0);
    });

    test('holesEntered counts partial hole_results', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      for (var h = 1; h <= 12; h++) {
        await fx.upsertHole(rid, h);
      }
      final rows = await db.roundDao.watchAllWithCourse().first;
      expect(rows.single.holesEntered, 12);
    });

    test('holesEntered reaches 18 for a complete round', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      for (var h = 1; h <= 18; h++) {
        await fx.upsertHole(rid, h);
      }
      final rows = await db.roundDao.watchAllWithCourse().first;
      expect(rows.single.holesEntered, 18);
    });

    test('holesEntered is per-round, not summed across rounds', () async {
      final cid = await fx.insertCourse();
      final r1 = await fx.insertRound(cid, date: '2026-04-01');
      final r2 = await fx.insertRound(cid, date: '2026-05-01');
      await fx.upsertHole(r1, 1);
      await fx.upsertHole(r1, 2);
      await fx.upsertHole(r2, 1);

      final rows = await db.roundDao.watchAllWithCourse().first;
      final byId = {for (final r in rows) r.round.id: r.holesEntered};
      expect(byId[r1], 2);
      expect(byId[r2], 1);
    });

    test('holesEntered re-emits when a hole is upserted', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      final stream = db.roundDao.watchAllWithCourse();

      final first = await stream.first;
      expect(first.single.holesEntered, 0);

      await fx.upsertHole(rid, 1);
      final second = await stream.first;
      expect(second.single.holesEntered, 1);
    });

    test('totals sum score and par across the entered holes', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // Two par-4 holes, bogey each: score 10, par 8, +2 to par.
      await fx.upsertHole(rid, 1, par: 4, score: 5);
      await fx.upsertHole(rid, 2, par: 4, score: 5);

      final row = (await db.roundDao.watchAllWithCourse().first).single;
      expect(row.totalScore, 10);
      expect(row.totalPar, 8);
      expect(row.relativeToPar, 2);
    });

    test('totals are zero for a round with no hole_results', () async {
      final cid = await fx.insertCourse();
      await fx.insertRound(cid);
      final row = (await db.roundDao.watchAllWithCourse().first).single;
      expect(row.totalScore, 0);
      expect(row.totalPar, 0);
      expect(row.relativeToPar, 0);
      expect(row.holesEntered, 0);
    });

    test('totals cover only the entered holes of a partial round', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      // 12 holes, one under par each: par 48 / score 36 → -12 to par.
      for (var h = 1; h <= 12; h++) {
        await fx.upsertHole(rid, h, par: 4, score: 3);
      }
      final row = (await db.roundDao.watchAllWithCourse().first).single;
      expect(row.holesEntered, 12);
      expect(row.totalScore, 36);
      expect(row.totalPar, 48);
      expect(row.relativeToPar, -12);
    });

    test('totals are per-round, not summed across rounds', () async {
      final cid = await fx.insertCourse();
      final r1 = await fx.insertRound(cid, date: '2026-04-01');
      final r2 = await fx.insertRound(cid, date: '2026-05-01');
      await fx.upsertHole(r1, 1, par: 4, score: 6); // +2
      await fx.upsertHole(r1, 2, par: 4, score: 4); // E
      await fx.upsertHole(r2, 1, par: 4, score: 3); // -1

      final rows = await db.roundDao.watchAllWithCourse().first;
      final byId = {for (final r in rows) r.round.id: r};
      expect(byId[r1]!.relativeToPar, 2);
      expect(byId[r2]!.relativeToPar, -1);
    });

    test('relativeToPar re-emits when a hole is upserted', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      final stream = db.roundDao.watchAllWithCourse();

      expect((await stream.first).single.relativeToPar, 0);

      await fx.upsertHole(rid, 1, par: 4, score: 5);
      expect((await stream.first).single.relativeToPar, 1);
    });
  });

  group('RoundDao.getOrCreate', () {
    test('inserts when absent and returns a positive id', () async {
      final cid = await fx.insertCourse();
      final id = await db.roundDao.getOrCreate(
        RoundsCompanion.insert(date: '2026-04-01', courseId: cid),
      );
      expect(id, isPositive);
    });

    test('returns the same id and creates no duplicate when present',
        () async {
      final cid = await fx.insertCourse();
      final companion =
          RoundsCompanion.insert(date: '2026-04-01', courseId: cid);
      final first = await db.roundDao.getOrCreate(companion);
      final second = await db.roundDao.getOrCreate(companion);
      expect(second, first);
      expect(await db.roundDao.watchAllWithCourse().first, hasLength(1));
    });

    test('matches a round created earlier via insert()', () async {
      final cid = await fx.insertCourse();
      final inserted = await fx.insertRound(cid, date: '2026-04-01');
      final got = await db.roundDao.getOrCreate(
        RoundsCompanion.insert(date: '2026-04-01', courseId: cid),
      );
      expect(got, inserted);
    });

    test('distinguishes rounds by roundNumber on the same date and course',
        () async {
      final cid = await fx.insertCourse();
      // Omitted roundNumber falls back to the schema default of 1.
      final r1 = await db.roundDao.getOrCreate(
        RoundsCompanion.insert(date: '2026-04-01', courseId: cid),
      );
      final r2 = await db.roundDao.getOrCreate(
        RoundsCompanion.insert(
          date: '2026-04-01',
          courseId: cid,
          roundNumber: const Value(2),
        ),
      );
      expect(r2, isNot(r1));
      expect(await db.roundDao.watchAllWithCourse().first, hasLength(2));
    });
  });
}
