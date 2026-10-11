// Golden files for the backup format (#69).
//
// Two committed files at the current schema, and they are the format's
// contract:
//
//   * `golden/backup_v1_minimal.json` — one row per table, byte for byte. A
//     diff here means the format changed.
//   * `golden/backup_v1_full.json` — the whole seeded fixture, every awkward
//     case in it. **This is the file #70's restore tests read**, so export and
//     import are proven against the same bytes rather than two hand-written
//     approximations of them.
//
// And one pair frozen at each older schema version a backup can hold —
// `golden/backup_v1_schema7_*.json`, written by v0.5.0 before putts had a
// distance, and `golden/backup_v1_schema8_*.json`, written by v0.6.0 before
// yardage split into tee sets and pin sets. These are never regenerated: they
// are files users already have, and they prove the upgrade still reads them.
//
// To regenerate after a deliberate format change:
//
//     GOLFY_UPDATE_GOLDEN=1 flutter test test/data/backup/backup_golden_test.dart
//
// then read the diff as carefully as you would read a migration.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_manifest.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
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
      expect(payload.rounds.where((r) => r.migrationCanary != null),
          hasLength(1));
      // A round on a whole yardage set, one from a tee set alone, one on none.
      expect(payload.rounds.where((r) => r.pinSetId != null), hasLength(1));
      expect(payload.rounds.where((r) => r.teeSetId == null), hasLength(1));
      // Tee to pin from two tee sets to the same pins, one card half-filled.
      expect(payload.teeToPinYards.map((y) => y.teeSetId).toSet(),
          hasLength(2));
      expect(payload.teeToPinYards, hasLength(27));
      expect(payload.rounds.where((r) => r.eventId == null), hasLength(1));
      expect(payload.holeResults.where((h) => h.fairwayHit == null),
          hasLength(2));
      expect(payload.holeShots.where((s) => s.club == null), hasLength(1));
      expect(payload.holeShots.where((s) => s.distanceFeet != null),
          hasLength(1));
      expect(payload.events.where((e) => e.missedCut), hasLength(1));
      expect(payload.events.where((e) => e.tied), hasLength(1));
      expect(payload.events.where((e) => e.season == 2), hasLength(1));
      expect(
        payload.rounds.map((r) => r.notes),
        contains('Said "nice shot" — then this:\nthree-putt. ⛳'),
      );
    });
  });
  /// What a pre-v9 file's rows become once upgraded, table by table, in v9's
  /// table names: the v8 -> v9 split of yardage sets into tee sets (and no pin
  /// sets), plus — for a v7 file — the v7 -> v8 putt column, which these
  /// fixtures hold no putt distances to convert.
  Map<String, List<Map<String, Object?>>> upgradedRows(
    Map<String, Object?> data, {
    required int fromVersion,
  }) {
    List<Map<String, Object?>> rows(String table) => [
          for (final row in data[table]! as List<Object?>)
            Map<String, Object?>.of(row! as Map<String, Object?>),
        ];
    final setCourse = {
      for (final s in rows('course_sets')) s['id']: s['course_id'],
    };
    return {
      'courses': rows('courses'),
      'course_holes': rows('course_holes'),
      'tee_sets': rows('course_sets'),
      'course_yards': [
        for (final y in rows('course_set_yards'))
          {
            'id': y['id'],
            'tee_set_id': y['course_set_id'],
            'hole_number': y['hole_number'],
            'yards': y['yards'],
          },
      ],
      'pin_sets': const [],
      'tee_to_pin_yards': const [],
      'events': rows('events'),
      'rounds': [
        for (final r in rows('rounds'))
          {
            ...r..remove('tee_set'),
            'tee_set_id': setCourse[r['course_set_id']] == r['course_id']
                ? r['course_set_id']
                : null,
            'pin_set_id': null,
          }..remove('course_set_id'),
      ],
      'hole_results': rows('hole_results'),
      'hole_shots': [
        for (final shot in rows('hole_shots'))
          {...shot, if (fromVersion < 8) 'distance_feet': null},
      ],
    };
  }

  Map<String, Object?> readTree(String name) =>
      jsonDecode(File('$_goldenDir/$name').readAsStringSync())
          as Map<String, Object?>;

  for (final version in [7, 8]) {
    group('a backup written at schema $version', () {
      test('the minimal file reads as today\'s sample, without pins', () {
        final text = File('$_goldenDir/backup_v1_schema${version}_minimal.json')
            .readAsStringSync();

        final bundle = BackupCodec.decode(text);

        expect(bundle.manifest.schemaVersion, version);
        expect(bundle.payload, upgradedV8SamplePayload());
        expect(bundle.payload.validate(), isEmpty);
      });

      test('the full file reads back whole, its sets as tee sets', () {
        final name = 'backup_v1_schema${version}_full.json';
        final data = readTree(name)['data']! as Map<String, Object?>;

        final bundle =
            BackupCodec.decode(File('$_goldenDir/$name').readAsStringSync());

        expect(bundle.payload.validate(), isEmpty);
        expect(bundle.payload.teeSets, isNotEmpty);
        expect(bundle.payload.courseYards, isNotEmpty);
        expect(bundle.payload.rounds.where((r) => r.teeSetId != null),
            isNotEmpty);
        // Every row the file holds comes through, reshaped only as the
        // upgrade says — nothing else moves.
        final expected = upgradedRows(data, fromVersion: version);
        final tables = bundle.payload.tables;
        for (final table in backupTableOrder) {
          expect(
            [for (final row in tables[table]!) row.toJson()],
            expected[table],
            reason: table,
          );
        }
      });
    });
  }

  test('a schema 7 file\'s shots arrive without a putt distance', () {
    final bundle = BackupCodec.decode(
      File('$_goldenDir/backup_v1_schema7_full.json').readAsStringSync(),
    );

    expect(bundle.payload.holeShots, isNotEmpty);
    expect(
      bundle.payload.holeShots.map((s) => s.distanceFeet),
      everyElement(isNull),
    );
  });
}
