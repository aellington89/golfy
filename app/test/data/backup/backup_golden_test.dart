// Golden files for the backup format (#69).
//
// Two committed files, and they are the format's contract:
//
//   * `golden/backup_v1_minimal.json` — one row per table, byte for byte. A
//     diff here means the format changed.
//   * `golden/backup_v1_full.json` — the whole seeded fixture, every awkward
//     case in it. **This is the file #70's restore tests read**, so export and
//     import are proven against the same bytes rather than two hand-written
//     approximations of them.
//
// To regenerate after a deliberate format change:
//
//     GOLFY_UPDATE_GOLDEN=1 flutter test test/data/backup/backup_golden_test.dart
//
// then read the diff as carefully as you would read a migration.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_manifest.dart';
import 'package:golfy_app/data/database.dart';

import '../../dao/_fixtures.dart';
import '_sample.dart';

const String _goldenDir = 'test/data/backup/golden';
final bool _updating = Platform.environment['GOLFY_UPDATE_GOLDEN'] == '1';

/// Compares [actual] against the committed golden, or rewrites it when asked.
void expectGolden(String name, String actual) {
  final file = File('$_goldenDir/$name');
  if (_updating || !file.existsSync()) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    // ignore: avoid_print
    print('golden ${_updating ? 'updated' : 'created'}: ${file.path}');
    return;
  }
  expect(
    actual,
    file.readAsStringSync(),
    reason: 'the backup format changed. Every file a user already holds is '
        'written in the committed version, so this is a decision, not a '
        'detail: read BACKUP_FORMAT.md, then regenerate with '
        'GOLFY_UPDATE_GOLDEN=1.',
  );
}

void main() {
  test('minimal backup matches its golden file', () {
    expectGolden('backup_v1_minimal.json', encodeSample());
  });

  test('the minimal golden file reads back exactly', () {
    final text = File('$_goldenDir/backup_v1_minimal.json').readAsStringSync();

    final bundle = BackupCodec.decode(text);

    expect(bundle.payload, samplePayload());
    expect(bundle.payload.validate(), isEmpty);
    expect(bundle.manifest.formatVersion, BackupManifest.currentFormatVersion);
    expect(bundle.manifest.schemaVersion, BackupCodec.supportedSchemaVersion);
  });

  group('the full fixture', () {
    late GolfyDatabase db;
    late TestFixtures fixtures;

    setUp(() {
      db = GolfyDatabase.forTesting(NativeDatabase.memory());
      fixtures = TestFixtures(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('exports to its golden file', () async {
      await fixtures.seedFullBackupFixture();
      final payload = await db.backupDao.readAll();

      expectGolden(
        'backup_v1_full.json',
        BackupCodec.encode(sampleManifest(payload), payload),
      );
    });

    test('the full golden file reads back to the same database state',
        () async {
      final expectedCounts = await fixtures.seedFullBackupFixture();
      final payload = await db.backupDao.readAll();
      final text = File('$_goldenDir/backup_v1_full.json').readAsStringSync();

      final bundle = BackupCodec.decode(text);

      // This is the promise #70 inherits: the committed file decodes to
      // exactly what a device with this data holds, and it is internally
      // sound.
      expect(bundle.payload, payload);
      expect(bundle.payload.rowCounts, expectedCounts);
      expect(bundle.payload.validate(), isEmpty);
      expect(bundle.manifest.rowCounts, expectedCounts);
    });

    test('the full golden file carries the awkward cases', () async {
      final text = File('$_goldenDir/backup_v1_full.json').readAsStringSync();

      final payload = BackupCodec.decode(text).payload;

      expect(payload.courses, hasLength(2));
      expect(
        payload.courses.map((c) => c.name),
        contains('Königsschloß — "the castle"'),
      );
      expect(payload.rounds.where((r) => r.teeSet != null), hasLength(1));
      expect(payload.rounds.where((r) => r.migrationCanary != null),
          hasLength(1));
      expect(payload.rounds.where((r) => r.eventId == null), hasLength(1));
      expect(payload.holeResults.where((h) => h.fairwayHit == null),
          hasLength(2));
      expect(payload.holeShots.where((s) => s.club == null), hasLength(1));
      expect(payload.events.where((e) => e.missedCut), hasLength(1));
      expect(payload.events.where((e) => e.tied), hasLength(1));
      expect(payload.events.where((e) => e.season == 2), hasLength(1));
      expect(
        payload.rounds.map((r) => r.notes),
        contains('Said "nice shot" — then this:\nthree-putt. ⛳'),
      );
    });
  });
}
