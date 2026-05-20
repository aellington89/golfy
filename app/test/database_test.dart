import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertCourse({
    String name = 'Pebble Beach',
    String gameTitle = 'PGA Tour 2K25',
  }) =>
      db.into(db.courses).insert(
            CoursesCompanion.insert(name: name, gameTitle: gameTitle),
          );

  Future<int> insertRound(
    int courseId, {
    String date = '2026-05-19',
    int roundNumber = 1,
  }) =>
      db.into(db.rounds).insert(
            RoundsCompanion.insert(
              date: date,
              courseId: courseId,
              roundNumber: Value(roundNumber),
            ),
          );

  HoleResultsCompanion holeCompanion(
    int roundId,
    int holeNumber, {
    int par = 4,
    int score = 4,
    int yards = 400,
    bool? fairwayHit = true,
    bool gir = true,
    int putts = 2,
    bool upDownAttempt = false,
    bool upDownSuccess = false,
    int penaltyStrokes = 0,
    bool bunkerVisited = false,
    bool sandSave = false,
    int driveDistanceYards = 250,
  }) =>
      HoleResultsCompanion.insert(
        roundId: roundId,
        holeNumber: holeNumber,
        par: par,
        score: score,
        yards: yards,
        fairwayHit: Value(fairwayHit),
        gir: gir,
        putts: putts,
        upDownAttempt: upDownAttempt,
        upDownSuccess: upDownSuccess,
        penaltyStrokes: penaltyStrokes,
        bunkerVisited: bunkerVisited,
        sandSave: sandSave,
        driveDistanceYards: driveDistanceYards,
      );

  Future<void> insertHole(int roundId, int holeNumber,
          {int par = 4,
          int score = 4,
          int putts = 2,
          int penaltyStrokes = 0}) =>
      db.into(db.holeResults).insert(holeCompanion(
            roundId,
            holeNumber,
            par: par,
            score: score,
            putts: putts,
            penaltyStrokes: penaltyStrokes,
          ));

  group('foreign_keys pragma', () {
    test('is enabled', () async {
      final result = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(result.data.values.first, 1);
    });
  });

  group('courses', () {
    test('UNIQUE(name, game_title) rejects exact duplicate', () async {
      await insertCourse(name: 'Pebble', gameTitle: 'PGA 2K25');
      await expectLater(
        insertCourse(name: 'Pebble', gameTitle: 'PGA 2K25'),
        throwsA(isA<Exception>()),
      );
    });

    test('same course name across different games is allowed', () async {
      await insertCourse(name: 'Pebble', gameTitle: 'PGA 2K25');
      await insertCourse(name: 'Pebble', gameTitle: 'EA Sports PGA Tour');
      final all = await db.select(db.courses).get();
      expect(all, hasLength(2));
    });
  });

  group('rounds', () {
    test('UNIQUE(date, course_id, round_number) rejects duplicate', () async {
      final cid = await insertCourse();
      await insertRound(cid, date: '2026-05-19', roundNumber: 1);
      await expectLater(
        insertRound(cid, date: '2026-05-19', roundNumber: 1),
        throwsA(isA<Exception>()),
      );
    });

    test('multiple rounds on same day/course allowed via round_number',
        () async {
      final cid = await insertCourse();
      await insertRound(cid, roundNumber: 1);
      await insertRound(cid, roundNumber: 2);
      final all = await db.select(db.rounds).get();
      expect(all, hasLength(2));
    });

    test('RESTRICT prevents course deletion while a round references it',
        () async {
      final cid = await insertCourse();
      await insertRound(cid);
      await expectLater(
        (db.delete(db.courses)..where((c) => c.id.equals(cid))).go(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('hole_results', () {
    test('UNIQUE(round_id, hole_number) rejects duplicate', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await insertHole(rid, 1);
      await expectLater(
        insertHole(rid, 1),
        throwsA(isA<Exception>()),
      );
    });

    test('CASCADE deletes hole_results when round is deleted', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      for (var h = 1; h <= 18; h++) {
        await insertHole(rid, h);
      }
      expect((await db.select(db.holeResults).get()).length, 18);
      await (db.delete(db.rounds)..where((r) => r.id.equals(rid))).go();
      expect((await db.select(db.holeResults).get()).length, 0);
    });

    test('CHECK rejects par=2', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await expectLater(
        insertHole(rid, 1, par: 2),
        throwsA(isA<Exception>()),
      );
    });

    test('CHECK rejects par=6', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await expectLater(
        insertHole(rid, 1, par: 6),
        throwsA(isA<Exception>()),
      );
    });

    test('CHECK rejects score=0', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await expectLater(
        insertHole(rid, 1, score: 0),
        throwsA(isA<Exception>()),
      );
    });

    test('CHECK rejects putts=-1', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await expectLater(
        insertHole(rid, 1, putts: -1),
        throwsA(isA<Exception>()),
      );
    });

    test('CHECK rejects penalty_strokes=-1', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await expectLater(
        insertHole(rid, 1, penaltyStrokes: -1),
        throwsA(isA<Exception>()),
      );
    });

    test('CHECK rejects hole_number=0', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await expectLater(
        insertHole(rid, 0),
        throwsA(isA<Exception>()),
      );
    });

    test('CHECK rejects hole_number=19', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await expectLater(
        insertHole(rid, 19),
        throwsA(isA<Exception>()),
      );
    });

    test('penalty_strokes can hold a count > 1', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await insertHole(rid, 1, penaltyStrokes: 3);
      final row = (await db.select(db.holeResults).get()).single;
      expect(row.penaltyStrokes, 3);
    });

    test('fairway_hit can be null (par 3 semantic)', () async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await db.into(db.holeResults).insert(holeCompanion(
            rid,
            1,
            par: 3,
            fairwayHit: null,
          ));
      final row = (await db.select(db.holeResults).get()).single;
      expect(row.fairwayHit, isNull);
    });

    test('app-layer invariants are not enforced at SQL level', () async {
      // The "0 when prereq=0" rules (e.g. up_down_success=1 with attempt=0)
      // are application-layer invariants enforced by the DAO in #6, not the
      // schema. This test pins that contract so future changes are explicit.
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      await db.into(db.holeResults).insert(holeCompanion(
            rid,
            1,
            upDownAttempt: false,
            upDownSuccess: true,
            bunkerVisited: false,
            sandSave: true,
          ));
      final row = (await db.select(db.holeResults).get()).single;
      expect(row.upDownSuccess, isTrue);
      expect(row.sandSave, isTrue);
    });
  });
}
