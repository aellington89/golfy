// Restore write-side tests (#70) — BackupDao.replaceAll and countRows.
//
// Proves that a backup goes back in whole or not at all: every table, every
// id, onto an empty device or over one holding something else, and that any
// failure partway leaves the device exactly as it was. Reads the same golden
// file the export suites write, so export and restore are proven against the
// same bytes.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
import 'package:golfy_app/data/database.dart';

import '../data/backup/_sample.dart';
import '_fixtures.dart';

BackupPayload goldenFull() => BackupCodec.decode(
      File('test/data/backup/golden/backup_v1_full.json').readAsStringSync(),
    ).payload;

void main() {
  late GolfyDatabase db;
  late TestFixtures fixtures;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fixtures = TestFixtures(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Something a device might hold that is nothing like the golden file.
  Future<void> seedSomethingElse() async {
    final augusta =
        await fixtures.insertCourse(name: 'Augusta', gameTitle: 'Other game');
    final event = await fixtures.insertEvent(name: 'Spring Classic');
    for (var n = 1; n <= 4; n++) {
      final round = await fixtures.insertRound(augusta,
          date: '2026-0$n-10', eventId: event);
      await fixtures.upsertHole(round, 1);
    }
  }

  group('replaceAll', () {
    test('restores the golden file onto an empty device exactly', () async {
      final payload = goldenFull();

      await db.backupDao.replaceAll(payload);

      expect(await db.backupDao.readAll(), payload);
      expect((await db.backupDao.readAll()).validate(), isEmpty);
    });

    test('replaces what the device held rather than adding to it', () async {
      await seedSomethingElse();
      final payload = goldenFull();

      await db.backupDao.replaceAll(payload);

      final restored = await db.backupDao.readAll();
      expect(restored, payload);
      expect(restored.courses.map((c) => c.name), isNot(contains('Augusta')));
      expect(
        restored.events.map((e) => e.name),
        isNot(contains('Spring Classic')),
      );
    });

    test('an empty backup leaves an empty device', () async {
      await seedSomethingElse();

      await db.backupDao.replaceAll(const BackupPayload.empty());

      expect((await db.backupDao.readAll()).isEmpty, isTrue);
    });

    test('a file whose rows are out of id order still restores', () async {
      final payload = goldenFull();
      final shuffled = payload.copyWith(
        rounds: payload.rounds.reversed.toList(),
        holeShots: payload.holeShots.reversed.toList(),
      );

      await db.backupDao.replaceAll(shuffled);

      expect(await db.backupDao.readAll(), payload);
    });

    test('a broken last row rolls the whole restore back', () async {
      await seedSomethingElse();
      final before = await db.backupDao.readAll();
      final payload = goldenFull();
      // Passes the file checks but not the database's: CHECK (distance_yards
      // >= 0), in the very last table, so every delete and every earlier
      // insert has already happened when it fails.
      final broken = payload.copyWith(holeShots: [
        ...payload.holeShots.take(payload.holeShots.length - 1),
        payload.holeShots.last.copyWith(distanceYards: const Value(-1)),
      ]);

      await expectLater(db.backupDao.replaceAll(broken), throwsA(anything));

      expect(await db.backupDao.readAll(), before);
    });

    test('a duplicated id rolls the whole restore back', () async {
      await seedSomethingElse();
      final before = await db.backupDao.readAll();
      final payload = samplePayload();
      final duplicated = payload.copyWith(courses: [
        ...payload.courses,
        payload.courses.first.copyWith(name: 'Another name'),
      ]);

      await expectLater(
        db.backupDao.replaceAll(duplicated),
        throwsA(anything),
      );

      expect(await db.backupDao.readAll(), before);
    });

    test('rounds recorded after a restore get new ids', () async {
      final payload = goldenFull();
      await db.backupDao.replaceAll(payload);

      final courseId = payload.courses.first.id;
      final newId = await fixtures.insertRound(courseId, date: '2027-01-01');

      expect(newId, greaterThan(payload.rounds.map((r) => r.id).reduce(
            (a, b) => a > b ? a : b,
          )));
    });

    test('restoring lower ids than the device used never reuses them',
        () async {
      // The device has already handed out round ids 1-4; the backup holds
      // round 1 only. A round recorded afterwards must not come back as 2.
      await seedSomethingElse();
      await db.backupDao.replaceAll(samplePayload());

      final newId = await fixtures.insertRound(1, date: '2027-01-01');

      expect(newId, greaterThan(4));
    });

    test('screens watching the data hear about the restore', () async {
      final payload = goldenFull();
      final rounds = db.select(db.rounds).watch();

      final heard = expectLater(
        rounds.map((rows) => rows.length),
        emitsThrough(payload.rounds.length),
      );
      await db.backupDao.replaceAll(payload);

      await heard;
    });
  });

  group('countRows', () {
    test('an empty device counts zero in every table', () async {
      final counts = await db.backupDao.countRows();

      expect(counts.keys, backupTableOrder);
      expect(counts.values, everyElement(0));
    });

    test('counts every table of the full fixture', () async {
      final expected = await fixtures.seedFullBackupFixture();

      expect(await db.backupDao.countRows(), expected);
    });
  });
}
