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

    test('watchAll orders events alphabetically by name', () async {
      await db.eventDao
          .insert(EventsCompanion.insert(name: 'Charity Scramble'));
      await db.eventDao.insert(EventsCompanion.insert(name: 'A-League Night'));
      await db.eventDao.insert(EventsCompanion.insert(name: 'Major'));
      final rows = await db.eventDao.watchAll().first;
      expect(
        rows.map((e) => e.name).toList(),
        ['A-League Night', 'Charity Scramble', 'Major'],
      );
    });

    test('UNIQUE(name) rejects a duplicate name', () async {
      await db.eventDao
          .insert(EventsCompanion.insert(name: 'Club Championship'));
      await expectLater(
        db.eventDao.insert(EventsCompanion.insert(name: 'Club Championship')),
        throwsA(isA<Exception>()),
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

  group('EventDao.rename', () {
    test('renames an event and leaves its recorded result untouched', () async {
      final id = await fx.insertEvent(name: 'Club Champ');
      await db.eventDao.setResult(id, finishPosition: 3, tied: true);

      final n = await db.eventDao.rename(id, 'Club Championship');
      expect(n, 1);

      final row = await db.eventDao.getById(id);
      expect(row!.name, 'Club Championship');
      expect(row.finishPosition, 3);
      expect(row.tied, isTrue);
    });

    test('returns 0 when no row matched', () async {
      expect(await db.eventDao.rename(9999, 'Whatever'), 0);
    });

    test('UNIQUE(name) rejects renaming onto an existing name', () async {
      final a = await fx.insertEvent(name: 'A-League Night');
      await fx.insertEvent(name: 'Major');
      await expectLater(
        db.eventDao.rename(a, 'Major'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
