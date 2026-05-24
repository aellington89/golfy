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
  });
}
