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

  group('RoundDao.watchAllWithCourse — events', () {
    test('round carries a null event when it has no eventId', () async {
      final cid = await fx.insertCourse();
      await fx.insertRound(cid);
      final row = (await db.roundDao.watchAllWithCourse().first).single;
      expect(row.round.eventId, isNull);
      expect(row.event, isNull);
    });

    test('round carries its event when eventId is set', () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent(name: 'Club Championship');
      await fx.insertRound(cid, eventId: eid);
      final row = (await db.roundDao.watchAllWithCourse().first).single;
      expect(row.round.eventId, eid);
      expect(row.event, isNotNull);
      expect(row.event!.id, eid);
      expect(row.event!.name, 'Club Championship');
    });

    test('re-emits with the updated event when its result changes', () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent(name: 'Club Championship');
      await fx.insertRound(cid, eventId: eid);
      final stream = db.roundDao.watchAllWithCourse();

      final first = await stream.first;
      expect(first.single.event!.finishPosition, isNull);
      expect(first.single.event!.missedCut, isFalse);

      await db.eventDao.setResult(eid, finishPosition: 1);
      final second = await stream.first;
      expect(second.single.event!.finishPosition, 1);
    });
  });

  group('RoundDao.watchRoundsForEvent', () {
    test('returns only that event\'s rounds', () async {
      final cid = await fx.insertCourse();
      final eventA = await fx.insertEvent(name: 'Club Championship');
      final eventB = await fx.insertEvent(name: 'Ryder Cup');
      await fx.insertRound(cid, date: '2026-05-01', eventId: eventA);
      await fx.insertRound(cid, date: '2026-05-02', eventId: eventA);
      await fx.insertRound(cid, date: '2026-05-03', eventId: eventB);
      await fx.insertRound(cid, date: '2026-05-04'); // casual, no event

      final rows = await db.roundDao.watchRoundsForEvent(eventA).first;
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.round.eventId == eventA), isTrue);
      expect(rows.every((r) => r.event?.id == eventA), isTrue);
    });

    test('is empty for an event with no rounds', () async {
      final eid = await fx.insertEvent(name: 'Empty Open');
      expect(await db.roundDao.watchRoundsForEvent(eid).first, isEmpty);
    });

    test('carries course name, event, and hole aggregates', () async {
      final cid = await fx.insertCourse(name: 'Augusta');
      final eid = await fx.insertEvent(name: 'The Masters');
      final rid = await fx.insertRound(cid, eventId: eid);
      await fx.upsertHole(rid, 1, par: 4, score: 5);
      await fx.upsertHole(rid, 2, par: 3, score: 3, fairwayHit: null);

      final row = (await db.roundDao.watchRoundsForEvent(eid).first).single;
      expect(row.courseName, 'Augusta');
      expect(row.event, isNotNull);
      expect(row.event!.id, eid);
      expect(row.event!.name, 'The Masters');
      expect(row.holesEntered, 2);
      expect(row.totalScore, 8);
      expect(row.totalPar, 7);
    });

    test('includes a round with no holes entered (aggregates coerced to 0)',
        () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent();
      await fx.insertRound(cid, eventId: eid);

      final row = (await db.roundDao.watchRoundsForEvent(eid).first).single;
      expect(row.holesEntered, 0);
      expect(row.totalScore, 0);
      expect(row.totalPar, 0);
    });

    test('orders newest first by date, then by descending id', () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent();
      // Insert out of order; two share a date to exercise the id tie-break.
      final older = await fx.insertRound(cid,
          date: '2026-05-01', roundNumber: 1, eventId: eid);
      final sameDayFirst = await fx.insertRound(cid,
          date: '2026-05-10', roundNumber: 1, eventId: eid);
      final sameDaySecond = await fx.insertRound(cid,
          date: '2026-05-10', roundNumber: 2, eventId: eid);

      final rows = await db.roundDao.watchRoundsForEvent(eid).first;
      expect(
        rows.map((r) => r.round.id).toList(),
        [sameDaySecond, sameDayFirst, older],
      );
    });

    test('reacts to a new round inserted for the event', () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent();
      await fx.insertRound(cid, date: '2026-05-01', eventId: eid);
      final stream = db.roundDao.watchRoundsForEvent(eid);

      expect(await stream.first, hasLength(1));

      await fx.insertRound(cid, date: '2026-05-02', eventId: eid);
      expect(await stream.first, hasLength(2));
    });

    test('drops a round when it is detached from the event', () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent();
      final rid = await fx.insertRound(cid, eventId: eid);
      final stream = db.roundDao.watchRoundsForEvent(eid);

      expect(await stream.first, hasLength(1));

      await db.roundDao
          .updateById(rid, const RoundsCompanion(eventId: Value(null)));
      expect(await stream.first, isEmpty);
    });
  });

  group('RoundDao.updateById', () {
    test('attaches an event to a casual round (eventId null -> set)', () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent(name: 'Club Championship');
      final rid = await fx.insertRound(cid); // casual: no event
      expect((await db.roundDao.getById(rid))!.eventId, isNull);

      final n =
          await db.roundDao.updateById(rid, RoundsCompanion(eventId: Value(eid)));
      expect(n, 1);
      expect((await db.roundDao.getById(rid))!.eventId, eid);
    });

    test('detaches an event (eventId set -> null)', () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent();
      final rid = await fx.insertRound(cid, eventId: eid);

      await db.roundDao
          .updateById(rid, const RoundsCompanion(eventId: Value(null)));
      expect((await db.roundDao.getById(rid))!.eventId, isNull);
    });

    test('updates date, course, and round number', () async {
      final c1 = await fx.insertCourse(name: 'Pebble');
      final c2 = await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA');
      final rid = await fx.insertRound(c1, date: '2026-04-01', roundNumber: 1);

      await db.roundDao.updateById(
        rid,
        RoundsCompanion(
          date: const Value('2026-04-02'),
          courseId: Value(c2),
          roundNumber: const Value(3),
        ),
      );

      final row = await db.roundDao.getById(rid);
      expect(row!.date, '2026-04-02');
      expect(row.courseId, c2);
      expect(row.roundNumber, 3);
    });

    test('sets and then clears notes', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);

      await db.roundDao
          .updateById(rid, const RoundsCompanion(notes: Value('windy')));
      expect((await db.roundDao.getById(rid))!.notes, 'windy');

      await db.roundDao
          .updateById(rid, const RoundsCompanion(notes: Value<String?>(null)));
      expect((await db.roundDao.getById(rid))!.notes, isNull);
    });

    test('returns 1 when the round existed, 0 for an unknown id', () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid);
      expect(
        await db.roundDao
            .updateById(rid, const RoundsCompanion(notes: Value('x'))),
        1,
      );
      expect(
        await db.roundDao
            .updateById(9999, const RoundsCompanion(notes: Value('x'))),
        0,
      );
    });

    test('rejects an update that collides with another round\'s triple',
        () async {
      final cid = await fx.insertCourse();
      await fx.insertRound(cid, date: '2026-04-01', roundNumber: 1);
      final r2 = await fx.insertRound(cid, date: '2026-04-01', roundNumber: 2);

      // Moving r2 onto r1's (date, courseId, roundNumber) violates UNIQUE.
      await expectLater(
        db.roundDao
            .updateById(r2, const RoundsCompanion(roundNumber: Value(1))),
        throwsA(isA<Exception>()),
      );
    });

    test('re-saving a round onto its own triple does not self-collide',
        () async {
      final cid = await fx.insertCourse();
      final rid = await fx.insertRound(cid, date: '2026-04-01', roundNumber: 1);

      final n = await db.roundDao.updateById(
        rid,
        RoundsCompanion(
          date: const Value('2026-04-01'),
          courseId: Value(cid),
          roundNumber: const Value(1),
          notes: const Value('re-saved'),
        ),
      );
      expect(n, 1);
      expect((await db.roundDao.getById(rid))!.notes, 're-saved');
    });

    test('preserves hole_results across an update (incl. a course change)',
        () async {
      final c1 = await fx.insertCourse(name: 'Pebble');
      final c2 = await fx.insertCourse(name: 'Augusta', gameTitle: 'PGA');
      final rid = await fx.insertRound(c1);
      await fx.upsertHole(rid, 1);
      await fx.upsertHole(rid, 2);

      await db.roundDao
          .updateById(rid, RoundsCompanion(courseId: Value(c2)));

      expect(await db.holeResultDao.countForRound(rid), 2);
      expect((await db.roundDao.getById(rid))!.courseId, c2);
    });
  });
}
