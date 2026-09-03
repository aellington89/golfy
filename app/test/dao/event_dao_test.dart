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

  group('EventDao.insert + getById + watchAll', () {
    test('round-trips a name-only event (no result yet)', () async {
      final id = await db.eventDao.insert(
        EventsCompanion.insert(name: 'Club Championship'),
      );
      final row = await db.eventDao.getById(id);
      expect(row, isNotNull);
      expect(row!.name, 'Club Championship');
      expect(row.finishPosition, isNull);
      expect(row.tied, isFalse);
      expect(row.missedCut, isFalse);
    });

    test('getById returns null for unknown id', () async {
      expect(await db.eventDao.getById(9999), isNull);
    });

    test('watchAll orders by name then ascending season', () async {
      await fx.insertEvent(name: 'Charity Scramble');
      await fx.insertEvent(name: 'A-League Night');
      await fx.insertEvent(name: 'Major', season: 2);
      await fx.insertEvent(name: 'Major'); // season 1, inserted after season 2
      final rows = await db.eventDao.watchAll().first;
      expect(
        rows.map((e) => (e.name, e.season)).toList(),
        [
          ('A-League Night', 1),
          ('Charity Scramble', 1),
          ('Major', 1),
          ('Major', 2),
        ],
      );
    });

    test('UNIQUE(name, season) rejects a duplicate name in the same season',
        () async {
      await fx.insertEvent(name: 'Club Championship');
      await expectLater(
        fx.insertEvent(name: 'Club Championship'),
        throwsA(isA<Exception>()),
      );
    });

    test('allows the same name across seasons as distinct rows (#47)',
        () async {
      final s1 = await fx.insertEvent(name: 'Club Championship');
      final s2 = await fx.insertEvent(name: 'Club Championship', season: 2);
      expect(s1, isNot(s2));
      final rows = await db.eventDao.watchAll().first;
      expect(
        rows.map((e) => (e.name, e.season)).toList(),
        [('Club Championship', 1), ('Club Championship', 2)],
      );
    });
  });

  group('EventDao.setResult', () {
    test('records a finishing position', () async {
      final id = await fx.insertEvent();
      await db.eventDao.setResult(id, finishPosition: 2);
      final row = await db.eventDao.getById(id);
      expect(row!.finishPosition, 2);
      expect(row.tied, isFalse);
      expect(row.missedCut, isFalse);
    });

    test('records a tied position', () async {
      final id = await fx.insertEvent();
      await db.eventDao.setResult(id, finishPosition: 3, tied: true);
      final row = await db.eventDao.getById(id);
      expect(row!.finishPosition, 3);
      expect(row.tied, isTrue);
    });

    test('records a missed cut', () async {
      final id = await fx.insertEvent();
      await db.eventDao.setResult(id, missedCut: true);
      final row = await db.eventDao.getById(id);
      expect(row!.missedCut, isTrue);
      expect(row.finishPosition, isNull);
    });

    test('clears a previously recorded result', () async {
      final id = await fx.insertEvent();
      await db.eventDao.setResult(id, finishPosition: 1);
      await db.eventDao.setResult(id); // back to not-recorded
      final row = await db.eventDao.getById(id);
      expect(row!.finishPosition, isNull);
      expect(row.tied, isFalse);
      expect(row.missedCut, isFalse);
    });

    test('recording a result on one season leaves another untouched (#47)',
        () async {
      final s1 = await fx.insertEvent(name: 'Club Championship');
      final s2 = await fx.insertEvent(name: 'Club Championship', season: 2);
      await db.eventDao.setResult(s1, finishPosition: 1);
      await db.eventDao.setResult(s2, missedCut: true);

      final r1 = await db.eventDao.getById(s1);
      final r2 = await db.eventDao.getById(s2);
      expect(r1!.finishPosition, 1);
      expect(r1.missedCut, isFalse);
      expect(r2!.missedCut, isTrue);
      expect(r2.finishPosition, isNull);
    });

    test('rejects a missed cut combined with a position', () async {
      final id = await fx.insertEvent();
      expect(
        () => db.eventDao.setResult(id, missedCut: true, finishPosition: 2),
        throwsArgumentError,
      );
    });

    test('rejects a missed cut combined with a tie', () async {
      final id = await fx.insertEvent();
      expect(
        () => db.eventDao.setResult(id, missedCut: true, tied: true),
        throwsArgumentError,
      );
    });

    test('rejects a tie without a position', () async {
      final id = await fx.insertEvent();
      expect(
        () => db.eventDao.setResult(id, tied: true),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive position', () async {
      final id = await fx.insertEvent();
      expect(
        () => db.eventDao.setResult(id, finishPosition: 0),
        throwsArgumentError,
      );
    });
  });

  group('EventDao.deleteById', () {
    test('detaches rounds (event_id -> NULL) instead of deleting them',
        () async {
      final cid = await fx.insertCourse();
      final eid = await fx.insertEvent();
      final rid = await fx.insertRound(cid, eventId: eid);

      final n = await db.eventDao.deleteById(eid);
      expect(n, 1);

      // The round survives; only its event link is cleared.
      final round = await db.roundDao.getById(rid);
      expect(round, isNotNull);
      expect(round!.eventId, isNull);
      expect(await db.eventDao.getById(eid), isNull);
    });

    test('returns 0 when no row matched', () async {
      expect(await db.eventDao.deleteById(9999), 0);
    });
  });

  group('EventDao.updateDetails', () {
    test('updates name + season and leaves the recorded result untouched (#47)',
        () async {
      final id = await fx.insertEvent(name: 'Club Champ');
      await db.eventDao.setResult(id, finishPosition: 3, tied: true);

      final n = await db.eventDao
          .updateDetails(id, name: 'Club Championship', season: 4);
      expect(n, 1);

      final row = await db.eventDao.getById(id);
      expect(row!.name, 'Club Championship');
      expect(row.season, 4);
      expect(row.finishPosition, 3);
      expect(row.tied, isTrue);
    });

    test('returns 0 when no row matched', () async {
      expect(
        await db.eventDao.updateDetails(9999, name: 'Whatever', season: 1),
        0,
      );
    });

    test('UNIQUE(name, season) rejects updating onto an existing occurrence',
        () async {
      final a = await fx.insertEvent(name: 'A-League Night');
      await fx.insertEvent(name: 'Major'); // season 1
      await expectLater(
        db.eventDao.updateDetails(a, name: 'Major', season: 1),
        throwsA(isA<Exception>()),
      );
    });

    test('allows moving to a free season of an existing name (#47)', () async {
      final a = await fx.insertEvent(name: 'A-League Night');
      await fx.insertEvent(name: 'Major'); // season 1
      final n = await db.eventDao.updateDetails(a, name: 'Major', season: 2);
      expect(n, 1);
      final row = await db.eventDao.getById(a);
      expect(row!.name, 'Major');
      expect(row.season, 2);
    });
  });
}
