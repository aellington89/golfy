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

  Future<int> seedRound() async {
    final cid = await fx.insertCourse();
    return fx.insertRound(cid);
  }

  group('HoleResultDao.upsert', () {
    test('inserts a new hole and returns id', () async {
      final rid = await seedRound();
      final id = await fx.upsertHole(rid, 1);
      expect(id, isPositive);
    });

    test('upserting an existing (round, hole) PRESERVES the row id',
        () async {
      // This is the critical assertion that distinguishes the DAO's
      // ON CONFLICT DO UPDATE behaviour from a literal INSERT OR REPLACE.
      final rid = await seedRound();
      final firstId = await fx.upsertHole(rid, 1, score: 4);
      final secondId = await fx.upsertHole(rid, 1, score: 5);
      expect(secondId, firstId);
    });

    test('upsert updates non-key fields in place', () async {
      final rid = await seedRound();
      await fx.upsertHole(rid, 1, score: 4, putts: 2);
      await fx.upsertHole(rid, 1, score: 7, putts: 4);

      final rows = await db.holeResultDao.watchForRound(rid).first;
      expect(rows, hasLength(1));
      expect(rows.single.score, 7);
      expect(rows.single.putts, 4);
    });

    test('throws ArgumentError when upDownSuccess=true and attempt=false',
        () async {
      final rid = await seedRound();
      expect(
        () => db.holeResultDao.upsert(fx.holeCompanion(
          rid,
          1,
          upDownAttempt: false,
          upDownSuccess: true,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when sandSave=true and bunkerVisited=false',
        () async {
      final rid = await seedRound();
      expect(
        () => db.holeResultDao.upsert(fx.holeCompanion(
          rid,
          1,
          bunkerVisited: false,
          sandSave: true,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when par=3 has a non-null fairwayHit',
        () async {
      final rid = await seedRound();
      expect(
        () => db.holeResultDao.upsert(fx.holeCompanion(
          rid,
          1,
          par: 3,
          fairwayHit: true,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts par=3 with null fairwayHit', () async {
      final rid = await seedRound();
      final id = await db.holeResultDao.upsert(fx.holeCompanion(
        rid,
        1,
        par: 3,
        fairwayHit: null,
      ));
      expect(id, isPositive);
    });

    test('accepts the valid up/down + sand-save combinations', () async {
      final rid = await seedRound();
      // attempt=true, success=false → fine
      await db.holeResultDao.upsert(fx.holeCompanion(
        rid,
        1,
        upDownAttempt: true,
        upDownSuccess: false,
      ));
      // bunkerVisited=true, sandSave=false → fine
      await db.holeResultDao.upsert(fx.holeCompanion(
        rid,
        2,
        bunkerVisited: true,
        sandSave: false,
      ));
      // bunkerVisited=true, sandSave=true → fine
      await db.holeResultDao.upsert(fx.holeCompanion(
        rid,
        3,
        bunkerVisited: true,
        sandSave: true,
      ));
      final rows = await db.holeResultDao.watchForRound(rid).first;
      expect(rows, hasLength(3));
    });
  });

  group('HoleResultDao.watchForRound', () {
    test('emits empty list for an empty round', () async {
      final rid = await seedRound();
      final rows = await db.holeResultDao.watchForRound(rid).first;
      expect(rows, isEmpty);
    });

    test('returns rows ordered by holeNumber ASC', () async {
      final rid = await seedRound();
      // Insert out of order on purpose.
      await fx.upsertHole(rid, 3);
      await fx.upsertHole(rid, 1);
      await fx.upsertHole(rid, 2);

      final rows = await db.holeResultDao.watchForRound(rid).first;
      expect(rows.map((r) => r.holeNumber).toList(), [1, 2, 3]);
    });

    test('only returns rows for the requested round', () async {
      final cid = await fx.insertCourse();
      final r1 = await fx.insertRound(cid, roundNumber: 1);
      final r2 = await fx.insertRound(cid, roundNumber: 2);
      await fx.upsertHole(r1, 1);
      await fx.upsertHole(r2, 1);

      final rows = await db.holeResultDao.watchForRound(r1).first;
      expect(rows, hasLength(1));
      expect(rows.single.roundId, r1);
    });
  });

  group('HoleResultDao.countForRound', () {
    test('returns 0 for an empty round', () async {
      final rid = await seedRound();
      expect(await db.holeResultDao.countForRound(rid), 0);
    });

    test('returns 18 after a full round is entered', () async {
      final rid = await seedRound();
      for (var h = 1; h <= 18; h++) {
        await fx.upsertHole(rid, h);
      }
      expect(await db.holeResultDao.countForRound(rid), 18);
    });
  });
}
