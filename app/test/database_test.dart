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
    int? teeSetId,
    int? pinSetId,
  }) =>
      db.into(db.rounds).insert(
            RoundsCompanion.insert(
              date: date,
              courseId: courseId,
              roundNumber: Value(roundNumber),
              eventId: Value(eventId),
              teeSetId: Value(teeSetId),
              pinSetId: Value(pinSetId),
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

  Future<int> insertTeeSet(int courseId, {String name = 'Blue'}) =>
      db.into(db.teeSets).insert(
            TeeSetsCompanion.insert(courseId: courseId, name: name),
          );

  Future<int> insertPinSet(int courseId, {String name = 'Sunday pins'}) =>
      db.into(db.pinSets).insert(
            PinSetsCompanion.insert(courseId: courseId, name: name),
          );

  Future<void> insertCourseYard(
    int teeSetId,
    int holeNumber, {
    int yards = 400,
  }) =>
      db.into(db.courseYards).insert(CourseYardsCompanion.insert(
            teeSetId: teeSetId,
            holeNumber: holeNumber,
            yards: yards,
          ));

  Future<void> insertTeeToPinYard(
    int teeSetId,
    int pinSetId,
    int holeNumber, {
    int yards = 390,
  }) =>
      db.into(db.teeToPinYards).insert(TeeToPinYardsCompanion.insert(
            teeSetId: teeSetId,
            pinSetId: pinSetId,
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

  group('tee_sets and pin_sets', () {
    test('UNIQUE(course_id, name) rejects a duplicate name in a course',
        () async {
      final cid = await insertCourse();
      await insertTeeSet(cid, name: 'Blue');
      await insertPinSet(cid, name: 'Sunday pins');
      await expectLater(
        insertTeeSet(cid, name: 'Blue'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertPinSet(cid, name: 'Sunday pins'),
        throwsA(isA<Exception>()),
      );
    });

    test('the same name is allowed across courses, and across kinds',
        () async {
      final a = await insertCourse(name: 'A');
      final b = await insertCourse(name: 'B');
      await insertTeeSet(a, name: 'Blue');
      await insertTeeSet(b, name: 'Blue');
      // A tee set and a pin set never clash: they are different things.
      await insertPinSet(a, name: 'Blue');
      expect((await db.select(db.teeSets).get()).length, 2);
      expect((await db.select(db.pinSets).get()).length, 1);
    });

    test('CASCADE deletes both kinds when the course is deleted', () async {
      final cid = await insertCourse();
      await insertTeeSet(cid, name: 'Blue');
      await insertTeeSet(cid, name: 'White');
      await insertPinSet(cid);
      await (db.delete(db.courses)..where((c) => c.id.equals(cid))).go();
      expect((await db.select(db.teeSets).get()), isEmpty);
      expect((await db.select(db.pinSets).get()), isEmpty);
    });
  });

  group('course_yards', () {
    test('UNIQUE(tee_set_id, hole_number) rejects duplicate', () async {
      final cid = await insertCourse();
      final tee = await insertTeeSet(cid);
      await insertCourseYard(tee, 1);
      await expectLater(
        insertCourseYard(tee, 1),
        throwsA(isA<Exception>()),
      );
    });

    test('CASCADE deletes course yards when the tee set is deleted',
        () async {
      final cid = await insertCourse();
      final tee = await insertTeeSet(cid);
      for (var h = 1; h <= 18; h++) {
        await insertCourseYard(tee, h);
      }
      expect((await db.select(db.courseYards).get()).length, 18);
      await (db.delete(db.teeSets)..where((s) => s.id.equals(tee))).go();
      expect((await db.select(db.courseYards).get()), isEmpty);
    });

    test('CHECK rejects negative yards and out-of-range hole numbers',
        () async {
      final cid = await insertCourse();
      final tee = await insertTeeSet(cid);
      await expectLater(
        insertCourseYard(tee, 1, yards: -1),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertCourseYard(tee, 0),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('tee_to_pin_yards', () {
    test('UNIQUE(tee_set_id, pin_set_id, hole_number) rejects duplicate, '
        'but the same hole can differ by tee set or pin set', () async {
      final cid = await insertCourse();
      final blue = await insertTeeSet(cid, name: 'Blue');
      final white = await insertTeeSet(cid, name: 'White');
      final sunday = await insertPinSet(cid, name: 'Sunday pins');
      final monday = await insertPinSet(cid, name: 'Monday pins');
      await insertTeeToPinYard(blue, sunday, 1, yards: 410);
      await insertTeeToPinYard(blue, monday, 1, yards: 395);
      await insertTeeToPinYard(white, sunday, 1, yards: 380);
      await expectLater(
        insertTeeToPinYard(blue, sunday, 1),
        throwsA(isA<Exception>()),
      );
    });

    test('CASCADE deletes them with the tee set or the pin set', () async {
      final cid = await insertCourse();
      final blue = await insertTeeSet(cid, name: 'Blue');
      final white = await insertTeeSet(cid, name: 'White');
      final sunday = await insertPinSet(cid, name: 'Sunday pins');
      final monday = await insertPinSet(cid, name: 'Monday pins');
      for (final tee in [blue, white]) {
        for (final pin in [sunday, monday]) {
          await insertTeeToPinYard(tee, pin, 1);
        }
      }

      await (db.delete(db.teeSets)..where((s) => s.id.equals(blue))).go();
      expect((await db.select(db.teeToPinYards).get()).length, 2);
      await (db.delete(db.pinSets)..where((s) => s.id.equals(sunday))).go();
      final left = await db.select(db.teeToPinYards).get();
      expect(left.single.teeSetId, white);
      expect(left.single.pinSetId, monday);
    });

    test('CHECK rejects negative yards and out-of-range hole numbers',
        () async {
      final cid = await insertCourse();
      final tee = await insertTeeSet(cid);
      final pin = await insertPinSet(cid);
      await expectLater(
        insertTeeToPinYard(tee, pin, 1, yards: -1),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        insertTeeToPinYard(tee, pin, 19),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('rounds.tee_set_id and rounds.pin_set_id', () {
    test('deleting either set SET NULLs the rounds played on it', () async {
      final cid = await insertCourse();
      final tee = await insertTeeSet(cid);
      final pin = await insertPinSet(cid);
      final rid = await insertRound(cid, teeSetId: tee, pinSetId: pin);
      Future<Round> round() =>
          (db.select(db.rounds)..where((r) => r.id.equals(rid))).getSingle();

      await (db.delete(db.pinSets)..where((s) => s.id.equals(pin))).go();
      expect((await round()).pinSetId, isNull);
      expect((await round()).teeSetId, tee);

      await (db.delete(db.teeSets)..where((s) => s.id.equals(tee))).go();
      expect((await round()).teeSetId, isNull);
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
