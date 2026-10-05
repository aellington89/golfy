// Export read-side tests (#69) — BackupDao.readAll against the full fixture.
//
// Proves that what lands in a backup is the whole database: every table, every
// column, nulls and legacy columns included, in a stable order, read as one
// consistent snapshot.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
import 'package:golfy_app/data/database.dart';

import '_fixtures.dart';

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

  test('an empty database exports eight empty tables', () async {
    final payload = await db.backupDao.readAll();

    expect(payload.tables.keys, backupTableOrder);
    expect(payload.rowCounts.values, everyElement(0));
    expect(payload.isEmpty, isTrue);
    expect(payload.totalRows, 0);
    expect(payload.validate(), isEmpty);
  });

  test('exports every row of every table', () async {
    final expected = await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    expect(payload.rowCounts, expected);
    expect(payload.totalRows, expected.values.reduce((a, b) => a + b));
  });

  test('the exported rows are exactly the rows in the database', () async {
    await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    // Compared against an independent read, so a bug in readAll's ordering or
    // filtering cannot agree with itself.
    expect(payload.courses, await db.select(db.courses).get());
    expect(payload.courseHoles, await db.select(db.courseHoles).get());
    expect(payload.courseSets, await db.select(db.courseSets).get());
    expect(payload.courseSetYards, await db.select(db.courseSetYards).get());
    expect(payload.events, await db.select(db.events).get());
    expect(payload.rounds, await db.select(db.rounds).get());
    expect(payload.holeResults, await db.select(db.holeResults).get());
    expect(payload.holeShots, await db.select(db.holeShots).get());
  });

  test('rows come back ordered by id', () async {
    await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    expect(payload.courses.map((c) => c.id), [1, 2]);
    for (final rows in payload.tables.values) {
      final ids = [
        for (final row in rows) (row.toJson()['id'] as int),
      ];
      expect(
        ids,
        orderedEquals(List<int>.of(ids)..sort()),
        reason: 'every table must come back in id order',
      );
    }
    // Ids are not contiguous and a backup must not assume they are: re-saving
    // a hole consumes an autoincrement id, so a real database has gaps. That
    // is precisely why the file carries each row's id rather than renumbering.
    expect(payload.holeResults.map((h) => h.id), isNot(contains(9)));
    expect(payload.holeResults.last.id, greaterThan(26));
  });

  test('preserves nullable columns that are set and unset', () async {
    await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    // A course with no template, beside one with a full card.
    expect(payload.courseHoles.map((h) => h.courseId).toSet(), {1});
    // Stroke index deliberately null on hole 1 only.
    final hole1 = payload.courseHoles.firstWhere((h) => h.holeNumber == 1);
    expect(hole1.strokeIndex, isNull);
    expect(payload.courseHoles.where((h) => h.strokeIndex == null), hasLength(1));

    // The par 3 carries no fairway.
    final par3 = payload.holeResults
        .firstWhere((h) => h.roundId == 2 && h.holeNumber == 7);
    expect(par3.par, 3);
    expect(par3.fairwayHit, isNull);

    // A shot whose every optional field was left blank.
    final blank = payload.holeShots.firstWhere((s) => s.shotNumber == 3);
    expect(blank.club, isNull);
    expect(blank.distanceYards, isNull);
    expect(blank.lie, isNull);
    expect(blank.result, isNull);

    // A casual round with nothing optional set at all.
    final casual = payload.rounds.firstWhere((r) => r.date == '2026-05-01');
    expect(casual.eventId, isNull);
    expect(casual.courseSetId, isNull);
    expect(casual.notes, isNull);
  });

  test('preserves the legacy tee_set and migration_canary columns', () async {
    await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    final round = payload.rounds.firstWhere((r) => r.teeSet != null);
    expect(round.teeSet, 'Blue (legacy label)');
    expect(round.migrationCanary, 'v2 canary');
  });

  test('preserves text holding quotes, newlines and non-ASCII', () async {
    await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    expect(
      payload.rounds.map((r) => r.notes),
      contains('Said "nice shot" — then this:\nthree-putt. ⛳'),
    );
    expect(
      payload.courses.map((c) => c.name),
      contains('Königsschloß — "the castle"'),
    );
  });

  test('preserves every result state an event can be in', () async {
    await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    final placed = payload.events.firstWhere((e) => e.finishPosition != null);
    expect(placed.finishPosition, 3);
    expect(placed.tied, isTrue);
    expect(placed.missedCut, isFalse);

    expect(payload.events.where((e) => e.missedCut), hasLength(1));
    expect(
      payload.events.where(
        (e) => e.finishPosition == null && !e.missedCut,
      ),
      hasLength(2),
    );
    // The same name in two seasons is two rows.
    final recurring =
        payload.events.where((e) => e.name == 'Club Championship');
    expect(recurring.map((e) => e.season), containsAll([1, 2]));
  });

  test('the full fixture passes its own referential checks', () async {
    await fixtures.seedFullBackupFixture();

    final payload = await db.backupDao.readAll();

    expect(payload.validate(), isEmpty);
  });

  test('reads a consistent snapshot while a hole is being saved', () async {
    final courseId = await fixtures.insertCourse();
    final roundId = await fixtures.insertRound(courseId);
    await fixtures.upsertHole(roundId, 1);

    // Kick off the export, then race a write against it. One transaction means
    // the export either sees the new hole or does not — never a hole_results
    // row whose hole_shots are missing.
    final exporting = db.backupDao.readAll();
    final writing = db.transaction(() async {
      final holeId = await fixtures.upsertHole(roundId, 2);
      await db.holeShotDao.replaceForHole(holeId, [
        HoleShotsCompanion.insert(holeResultId: holeId, shotNumber: 1),
      ]);
    });

    final payload = await exporting;
    await writing;

    final holeIds = payload.holeResults.map((h) => h.id).toSet();
    for (final shot in payload.holeShots) {
      expect(
        holeIds,
        contains(shot.holeResultId),
        reason: 'a backup must not hold a shot whose hole it left out',
      );
    }
  });
}
