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

  Future<int> insertEvent({String name = 'Club Championship', int season = 1}) =>
      db.into(db.events).insert(
            EventsCompanion.insert(name: name, season: Value(season)),
          );

  Future<int> insertRound(
    int courseId, {
    String date = '2026-05-19',
    int roundNumber = 1,
    int? eventId,
    int? courseSetId,
  }) =>
      db.into(db.rounds).insert(
            RoundsCompanion.insert(
              date: date,
              courseId: courseId,
              roundNumber: Value(roundNumber),
              eventId: Value(eventId),
              courseSetId: Value(courseSetId),
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

  Future<void> insertCourseHole(
    int courseId,
    int holeNumber, {
    int par = 4,
    int? strokeIndex,
  }) =>
      db.into(db.courseHoles).insert(CourseHolesCompanion.insert(
            courseId: courseId,
            holeNumber: holeNumber,
            par: par,
            strokeIndex: Value(strokeIndex),
          ));

  Future<int> insertCourseSet(int courseId, {String name = 'Blue tees'}) =>
      db.into(db.courseSets).insert(
            CourseSetsCompanion.insert(courseId: courseId, name: name),
          );

  Future<void> insertCourseSetYard(
    int setId,
    int holeNumber, {
    int yards = 400,
  }) =>
      db.into(db.courseSetYards).insert(CourseSetYardsCompanion.insert(
            courseSetId: setId,
            holeNumber: holeNumber,
            yards: yards,
          ));

  Future<void> insertHoleShot(
    int holeResultId,
    int shotNumber, {
    int? distanceYards,
  }) =>
      db.into(db.holeShots).insert(HoleShotsCompanion.insert(
            holeResultId: holeResultId,
            shotNumber: shotNumber,
            distanceYards: Value(distanceYards),
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

  group('events', () {
    test('UNIQUE(name, season) rejects a duplicate name in the same season',
        () async {
      await insertEvent(name: 'Club Championship');
      await expectLater(
        insertEvent(name: 'Club Championship'),
        throwsA(isA<Exception>()),
      );
    });

    test('allows the same name in a different season (#47)', () async {
      final s1 = await insertEvent(name: 'Club Championship');
      final s2 = await insertEvent(name: 'Club Championship', season: 2);
      expect(s1, isNot(s2)); // distinct rows / ids
      final rows = await db.select(db.events).get();
      expect(rows.length, 2);
      expect(rows.map((e) => e.season).toSet(), {1, 2});
    });

    test('deleting an event SET NULLs its rounds (no cascade delete)',
        () async {
      final cid = await insertCourse();
      final eid = await insertEvent();
      final rid = await insertRound(cid, eventId: eid);

      await (db.delete(db.events)..where((e) => e.id.equals(eid))).go();

      // The round survives with its event link cleared.
      final round =
          await (db.select(db.rounds)..where((r) => r.id.equals(rid)))
              .getSingle();
      expect(round.eventId, isNull);
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

  group('course_holes', () {
    test('UNIQUE(course_id, hole_number) rejects duplicate', () async {
      final cid = await insertCourse();
      await insertCourseHole(cid, 1);
      await expectLater(
        insertCourseHole(cid, 1),
        throwsA(isA<Exception>()),
      );
    });

    test('same hole number allowed across different courses', () async {
      final a = await insertCourse(name: 'A');
      final b = await insertCourse(name: 'B');
      await insertCourseHole(a, 1);
      await insertCourseHole(b, 1);
      expect((await db.select(db.courseHoles).get()).length, 2);
    });

    test('CASCADE deletes course_holes when its course is deleted', () async {
      final cid = await insertCourse();
      for (var h = 1; h <= 18; h++) {
        await insertCourseHole(cid, h);
      }
      expect((await db.select(db.courseHoles).get()).length, 18);
      await (db.delete(db.courses)..where((c) => c.id.equals(cid))).go();
      expect((await db.select(db.courseHoles).get()).length, 0);
    });

    test('CHECK rejects par outside 3..5', () async {
      final cid = await insertCourse();
      await expectLater(
        insertCourseHole(cid, 1, par: 2),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertCourseHole(cid, 2, par: 6),
        throwsA(isA<Exception>()),
      );
    });

    test('CHECK rejects hole_number outside 1..18', () async {
      final cid = await insertCourse();
      await expectLater(
        insertCourseHole(cid, 0),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertCourseHole(cid, 19),
        throwsA(isA<Exception>()),
      );
    });

    test('stroke_index is nullable and 1..18 when present', () async {
      final cid = await insertCourse();
      await insertCourseHole(cid, 1); // null stroke index is fine
      await insertCourseHole(cid, 2, strokeIndex: 18);
      await expectLater(
        insertCourseHole(cid, 3, strokeIndex: 0),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertCourseHole(cid, 4, strokeIndex: 19),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('course_sets', () {
    test('UNIQUE(course_id, name) rejects a duplicate name in a course',
        () async {
      final cid = await insertCourse();
      await insertCourseSet(cid, name: 'Blue');
      await expectLater(
        insertCourseSet(cid, name: 'Blue'),
        throwsA(isA<Exception>()),
      );
    });

    test('the same set name is allowed across different courses', () async {
      final a = await insertCourse(name: 'A');
      final b = await insertCourse(name: 'B');
      await insertCourseSet(a, name: 'Blue');
      await insertCourseSet(b, name: 'Blue');
      expect((await db.select(db.courseSets).get()).length, 2);
    });

    test('CASCADE deletes sets when the course is deleted', () async {
      final cid = await insertCourse();
      await insertCourseSet(cid, name: 'Blue');
      await insertCourseSet(cid, name: 'White');
      await (db.delete(db.courses)..where((c) => c.id.equals(cid))).go();
      expect((await db.select(db.courseSets).get()), isEmpty);
    });
  });

  group('course_set_yards', () {
    test('UNIQUE(course_set_id, hole_number) rejects duplicate', () async {
      final cid = await insertCourse();
      final sid = await insertCourseSet(cid);
      await insertCourseSetYard(sid, 1);
      await expectLater(
        insertCourseSetYard(sid, 1),
        throwsA(isA<Exception>()),
      );
    });

    test('CASCADE deletes yardages when the set is deleted', () async {
      final cid = await insertCourse();
      final sid = await insertCourseSet(cid);
      for (var h = 1; h <= 18; h++) {
        await insertCourseSetYard(sid, h);
      }
      expect((await db.select(db.courseSetYards).get()).length, 18);
      await (db.delete(db.courseSets)..where((s) => s.id.equals(sid))).go();
      expect((await db.select(db.courseSetYards).get()), isEmpty);
    });

    test('CHECK rejects negative yards and out-of-range hole numbers',
        () async {
      final cid = await insertCourse();
      final sid = await insertCourseSet(cid);
      await expectLater(
        insertCourseSetYard(sid, 1, yards: -1),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertCourseSetYard(sid, 0),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('rounds.course_set_id', () {
    test('deleting a set SET NULLs the rounds played on it', () async {
      final cid = await insertCourse();
      final sid = await insertCourseSet(cid);
      final rid = await insertRound(cid, courseSetId: sid);

      await (db.delete(db.courseSets)..where((s) => s.id.equals(sid))).go();

      final round =
          await (db.select(db.rounds)..where((r) => r.id.equals(rid)))
              .getSingle();
      expect(round.courseSetId, isNull);
    });
  });

  group('hole_shots', () {
    Future<int> seedHoleResult() async {
      final cid = await insertCourse();
      final rid = await insertRound(cid);
      return db.into(db.holeResults).insert(holeCompanion(rid, 1));
    }

    test('UNIQUE(hole_result_id, shot_number) rejects duplicate', () async {
      final hrid = await seedHoleResult();
      await insertHoleShot(hrid, 1);
      await expectLater(
        insertHoleShot(hrid, 1),
        throwsA(isA<Exception>()),
      );
    });

    test('CASCADE deletes shots when the hole_results row is deleted',
        () async {
      final hrid = await seedHoleResult();
      await insertHoleShot(hrid, 1);
      await insertHoleShot(hrid, 2);
      expect((await db.select(db.holeShots).get()).length, 2);
      await (db.delete(db.holeResults)..where((h) => h.id.equals(hrid))).go();
      expect((await db.select(db.holeShots).get()), isEmpty);
    });

    test('CHECK rejects shot_number < 1 and negative distance', () async {
      final hrid = await seedHoleResult();
      await expectLater(
        insertHoleShot(hrid, 0),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertHoleShot(hrid, 1, distanceYards: -1),
        throwsA(isA<Exception>()),
      );
    });

    test('a bad hole_result_id FK is rejected', () async {
      await expectLater(
        insertHoleShot(999, 1),
        throwsA(isA<Exception>()),
      );
    });
  });
}
