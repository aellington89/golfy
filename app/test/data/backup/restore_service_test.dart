// Restore orchestration (#70) — RestoreService against a fake source, so no
// file picker is involved.
//
// The promises under test: a file Golfy exported comes back as exactly the
// data it was made from, whichever schema version wrote it; and a file that
// cannot be restored is refused with a reason, before the database is touched.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_destination.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
import 'package:golfy_app/data/backup/backup_service.dart';
import 'package:golfy_app/data/backup/backup_source.dart';
import 'package:golfy_app/data/backup/restore_service.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/repository.dart';

import '../../dao/_fixtures.dart';

const String _goldenDir = 'test/data/backup/golden';

String golden(String name) => File('$_goldenDir/$name').readAsStringSync();

/// Hands over whatever it was told to.
class FakeSource implements BackupSource {
  FakeSource(this.outcome);

  FakeSource.text(String contents, {String fileName = 'golfy-backup.json'})
      : outcome = BackupPicked(
          fileName,
          Uint8List.fromList(utf8.encode(contents)),
        );

  BackupPickOutcome outcome;

  @override
  Future<BackupPickOutcome> pick() async => outcome;
}

/// Records the file an export hands over.
class CapturingDestination implements BackupDestination {
  String? contents;

  @override
  Future<BackupSaveOutcome> save({
    required String fileName,
    required String contents,
  }) async {
    this.contents = contents;
    return const BackupSaveOutcome.shared();
  }
}

/// [golden full] with its JSON tree edited by [edit].
String editedGolden(void Function(Map<String, dynamic> root) edit) {
  final root =
      jsonDecode(golden('backup_v1_full.json')) as Map<String, dynamic>;
  edit(root);
  return jsonEncode(root);
}

void main() {
  late GolfyDatabase db;
  late GolfyRepository repository;
  late TestFixtures fixtures;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    repository = GolfyRepository(db);
    fixtures = TestFixtures(db);
  });

  tearDown(() async {
    await db.close();
  });

  RestoreService service(BackupSource source) =>
      RestoreService(repository: repository, source: source);

  /// Something already on the device, which a refusal must leave alone.
  Future<BackupPayload> seedDevice() async {
    final course = await fixtures.insertCourse(name: 'Augusta');
    final round = await fixtures.insertRound(course, date: '2026-01-10');
    await fixtures.upsertHole(round, 1);
    return repository.readBackupPayload();
  }

  Future<RestorePlan> readyPlan(RestoreService restore) async {
    final prepared = await restore.prepare();
    expect(prepared, isA<RestoreReady>());
    return (prepared as RestoreReady).plan;
  }

  group('restoring', () {
    test('export, wipe, import: the device holds what it held', () async {
      await fixtures.seedFullBackupFixture();
      final original = await repository.readBackupPayload();
      final destination = CapturingDestination();
      final export = await BackupService(
        repository: repository,
        destination: destination,
        readAppVersion: () async => '0.8.0+45',
        clock: () => DateTime(2026, 10, 24, 9, 30),
        platformName: 'android',
      ).createBackup();
      expect(export.isSuccess, isTrue);

      // A new phone: a fresh, empty database.
      await db.close();
      db = GolfyDatabase.forTesting(NativeDatabase.memory());
      repository = GolfyRepository(db);
      final restore = service(FakeSource.text(destination.contents!));

      final plan = await readyPlan(restore);
      expect(plan.deviceIsEmpty, isTrue);
      expect(plan.manifest.appVersion, '0.8.0+45');
      final result = await restore.apply(plan);

      expect(result.isSuccess, isTrue);
      expect(result.rowCounts, original.rowCounts);
      expect(await repository.readBackupPayload(), original);
    });

    test('replaces what a device already held', () async {
      await seedDevice();
      final restore = service(FakeSource.text(golden('backup_v1_full.json')));

      final plan = await readyPlan(restore);
      expect(plan.deviceIsEmpty, isFalse);
      expect(plan.currentCounts['courses'], 1);
      expect(plan.currentCounts['rounds'], 1);
      await restore.apply(plan);

      expect(
        await repository.readBackupPayload(),
        BackupCodec.decode(golden('backup_v1_full.json')).payload,
      );
    });

    for (final version in [7, 8]) {
      test('a backup written at schema $version is upgraded and restored',
          () async {
        final text = golden('backup_v1_schema${version}_full.json');
        final restore = service(FakeSource.text(text));

        final plan = await readyPlan(restore);
        expect(plan.manifest.schemaVersion, version);
        final result = await restore.apply(plan);

        expect(result.isSuccess, isTrue);
        final restored = await repository.readBackupPayload();
        expect(restored, BackupCodec.decode(text).payload);
        expect(restored.validate(), isEmpty);
      });
    }

    test('a file starting with a byte-order mark is still read', () async {
      final restore =
          service(FakeSource.text('﻿${golden('backup_v1_full.json')}'));

      expect(await restore.prepare(), isA<RestoreReady>());
    });

    test('a failure while writing is reported, and changes nothing',
        () async {
      final before = await seedDevice();
      final payload = BackupCodec.decode(golden('backup_v1_full.json')).payload;
      // Sound by the file's checks, refused by the database's CHECK.
      final broken = payload.copyWith(holeShots: [
        for (final shot in payload.holeShots)
          shot.copyWith(distanceYards: const Value(-5)),
      ]);
      final restore = service(FakeSource(const BackupPickCancelled()));

      final result = await restore.apply(RestorePlan(
        fileName: 'broken.json',
        manifest: BackupCodec.decode(golden('backup_v1_full.json')).manifest,
        payload: broken,
        currentCounts: before.rowCounts,
      ));

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(await repository.readBackupPayload(), before);
    });
  });

  group('refusing', () {
    /// Prepares [source] over a seeded device, expects a refusal, and checks
    /// the device was not touched. Returns the refusal.
    Future<RestoreRefused> refused(BackupSource source) async {
      final before = await seedDevice();

      final prepared = await service(source).prepare();

      expect(prepared, isA<RestoreRefused>());
      expect(await repository.readBackupPayload(), before);
      return prepared as RestoreRefused;
    }

    test('a file that is not JSON', () async {
      final refusal = await refused(FakeSource.text('golf is fun'));

      expect(refusal.reason, contains('not valid JSON'));
    });

    test('a file that is not text at all', () async {
      final refusal = await refused(FakeSource(BackupPicked(
        'photo.json',
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x80]),
      )));

      expect(refusal.reason, contains('not text'));
    });

    test('JSON that is not a Golfy backup', () async {
      final refusal = await refused(FakeSource.text('{"name": "Pebble"}'));

      expect(refusal.reason, contains('does not look like a Golfy backup'));
    });

    test('a backup from a newer Golfy', () async {
      final refusal = await refused(FakeSource.text(editedGolden((root) {
        root['golfyBackup']['schemaVersion'] = 99;
      })));

      expect(refusal.reason, contains('newer version of Golfy'));
    });

    test('a container version this Golfy does not know', () async {
      final refusal = await refused(FakeSource.text(editedGolden((root) {
        root['golfyBackup']['formatVersion'] = 2;
      })));

      expect(refusal.reason, contains('format version 2'));
    });

    test('a file whose counts do not match its rows', () async {
      final refusal = await refused(FakeSource.text(editedGolden((root) {
        final counts = root['golfyBackup']['rowCounts'] as Map;
        counts['rounds'] = (counts['rounds'] as int) + 1;
      })));

      expect(refusal.reason, contains('incomplete or edited'));
    });

    test('rows that point at rows the file does not have', () async {
      final refusal = await refused(FakeSource.text(editedGolden((root) {
        final rounds = root['data']['rounds'] as List;
        (rounds.first as Map)['course_id'] = 999;
      })));

      expect(refusal.reason, contains('does not fit together'));
      expect(
        refusal.problems,
        contains('rounds row 1: course_id 999 is not in courses'),
      );
    });

    test('a file far too big to be a backup', () async {
      final refusal = await refused(
        FakeSource(const BackupTooLarge('holiday.mp4', 300 * 1024 * 1024)),
      );

      expect(refusal.reason, contains('holiday.mp4 is 300 MB'));
    });

    test('a picker that failed', () async {
      final refusal =
          await refused(FakeSource(const BackupPickFailed('no access')));

      expect(refusal.reason, contains('no access'));
    });
  });

  test('backing out of the picker changes nothing', () async {
    final before = await seedDevice();

    final prepared =
        await service(FakeSource(const BackupPickCancelled())).prepare();

    expect(prepared, isA<RestoreCancelled>());
    expect(await repository.readBackupPayload(), before);
  });

  group('readPickedBackup', () {
    test('reads a file within the limit', () async {
      // On dart:io an XFile's name is the last part of its path.
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode('{}')),
        path: 'golfy-backup.json',
      );

      final outcome = await readPickedBackup(file, maxBytes: 10);

      expect(outcome, isA<BackupPicked>());
      expect((outcome as BackupPicked).fileName, 'golfy-backup.json');
      expect(utf8.decode(outcome.bytes), '{}');
    });

    test('does not read a file over the limit', () async {
      final file = XFile.fromData(Uint8List(11), path: 'big.json');

      final outcome = await readPickedBackup(file, maxBytes: 10);

      expect(outcome, isA<BackupTooLarge>());
      expect((outcome as BackupTooLarge).length, 11);
    });
  });
}
