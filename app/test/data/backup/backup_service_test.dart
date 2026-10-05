// Export orchestration (#69) — BackupService against a recording fake
// destination, so no share sheet and no save dialog is involved.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_destination.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
import 'package:golfy_app/data/backup/backup_service.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/repository.dart';

import '../../dao/_fixtures.dart';

/// Records what it was handed and returns whatever it was told to.
class FakeDestination implements BackupDestination {
  FakeDestination([this.outcome = const BackupSaveOutcome.shared()]);

  BackupSaveOutcome outcome;
  int calls = 0;
  String? fileName;
  String? contents;

  @override
  Future<BackupSaveOutcome> save({
    required String fileName,
    required String contents,
  }) async {
    calls++;
    this.fileName = fileName;
    this.contents = contents;
    return outcome;
  }
}

/// A destination that blows up, standing in for a full disk or a revoked
/// permission.
class ThrowingDestination implements BackupDestination {
  @override
  Future<BackupSaveOutcome> save({
    required String fileName,
    required String contents,
  }) async {
    return const BackupSaveOutcome.failed('disk full');
  }
}

/// Returns a payload that would not survive a restore: a round pointing at a
/// course that is not in the file. The database's own foreign keys make this
/// unreachable in practice, which is the point — it stands in for data gone
/// odd, or for a bug in the referential check itself.
class UnsoundRepository extends GolfyRepository {
  UnsoundRepository(super.db);

  @override
  Future<BackupPayload> readBackupPayload() async {
    return const BackupPayload.empty().copyWith(
      rounds: const [
        Round(id: 1, date: '2026-05-19', courseId: 404, roundNumber: 1),
      ],
    );
  }
}

/// Stands in for a database that cannot be read — a locked file, a corrupt
/// page, a disk that went away mid-read.
class UnreadableRepository extends GolfyRepository {
  UnreadableRepository(super.db);

  @override
  Future<BackupPayload> readBackupPayload() =>
      Future.error(StateError('database is locked'));
}

void main() {
  late GolfyDatabase db;
  late TestFixtures fixtures;
  late GolfyRepository repository;
  final when = DateTime(2026, 10, 3, 14, 32, 7);

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fixtures = TestFixtures(db);
    repository = GolfyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  BackupService service(
    BackupDestination destination, {
    GolfyRepository? repo,
    DateTime? clock,
  }) {
    return BackupService(
      repository: repo ?? repository,
      destination: destination,
      readAppVersion: () async => '0.4.0+38',
      clock: () => clock ?? when,
      platformName: 'android',
    );
  }

  group('the file it hands over', () {
    test('is named for the local date and time, to the minute', () async {
      final destination = FakeDestination();

      final result = await service(destination).createBackup();

      expect(result.fileName, 'golfy-backup-20261003-1432.json');
      expect(destination.fileName, 'golfy-backup-20261003-1432.json');
    });

    test('pads single-digit months, days, hours and minutes', () {
      expect(
        backupFileName(DateTime(2026, 1, 2, 3, 4)),
        'golfy-backup-20260102-0304.json',
      );
    });

    test('carries every row in the database', () async {
      final expected = await fixtures.seedFullBackupFixture();
      final destination = FakeDestination();

      final result = await service(destination).createBackup();

      expect(result.rowCounts, expected);
      expect(result.totalRows, expected.values.reduce((a, b) => a + b));

      final decoded = BackupCodec.decode(destination.contents!);
      expect(decoded.payload.rowCounts, expected);
      expect(decoded.payload, await db.backupDao.readAll());
    });

    test('states the app version, the platform and the time in UTC',
        () async {
      final destination = FakeDestination();

      await service(destination).createBackup();

      final manifest = BackupCodec.decode(destination.contents!).manifest;
      expect(manifest.appVersion, '0.4.0+38');
      expect(manifest.platform, 'android');
      expect(manifest.exportedAt, when.toUtc());
      expect(manifest.exportedAt.isUtc, isTrue);
      expect(manifest.schemaVersion, db.schemaVersion);
    });

    test('is produced for an empty database too', () async {
      final destination = FakeDestination();

      final result = await service(destination).createBackup();

      expect(result.isSuccess, isTrue);
      expect(result.totalRows, 0);
      expect(
        BackupCodec.decode(destination.contents!).payload.isEmpty,
        isTrue,
      );
    });
  });

  group('what it reports', () {
    test('shared, when the share sheet accepted it', () async {
      final result = await service(FakeDestination()).createBackup();

      expect(result.status, BackupSaveStatus.shared);
      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
    });

    test('saved, with the path, when a save dialog wrote it', () async {
      final result = await service(
        FakeDestination(const BackupSaveOutcome.saved(r'C:\golf\backup.json')),
      ).createBackup();

      expect(result.status, BackupSaveStatus.saved);
      expect(result.location, r'C:\golf\backup.json');
      expect(result.isSuccess, isTrue);
    });

    test('cancelled, when the user backed out', () async {
      final result = await service(
        FakeDestination(const BackupSaveOutcome.cancelled()),
      ).createBackup();

      expect(result.status, BackupSaveStatus.cancelled);
      expect(result.isSuccess, isFalse);
      expect(result.error, isNull);
    });

    test('failed, passing on what the platform said', () async {
      final result = await service(ThrowingDestination()).createBackup();

      expect(result.status, BackupSaveStatus.failed);
      expect(result.error, 'disk full');
      expect(result.isSuccess, isFalse);
    });

    test('failed, rather than throwing, when the database cannot be read',
        () async {
      final result = await service(
        FakeDestination(),
        repo: UnreadableRepository(db),
      ).createBackup();

      expect(result.status, BackupSaveStatus.failed);
      expect(result.error, contains('could not read your data'));
      expect(result.error, contains('database is locked'));
      // Nothing is handed to the platform when there is nothing to hand over.
      expect(result.totalRows, 0);
    });
  });

  test('checks the file reads back before handing it over', () async {
    // The codec is tested in general; this is the service proving *this* file,
    // on this data, so a backup that could not be imported is never produced.
    await fixtures.seedFullBackupFixture();
    final destination = FakeDestination();

    await service(destination).createBackup();

    final bundle = BackupCodec.decode(destination.contents!);
    expect(bundle.payload, await db.backupDao.readAll());
    expect(bundle.payload.validate(), isEmpty);
  });

  test('still produces a file when the data itself looks unsound', () async {
    // Export's job is to be faithful, not to be the gatekeeper: refusing to
    // write a file because the rows in it would trouble a *restore* would deny
    // the user the one copy of their data they asked for — and that copy is
    // where any diagnosis would start. #70 is where the referential check is
    // asked, with a readable reason and an untouched database.
    final destination = FakeDestination();

    final result = await service(
      destination,
      repo: UnsoundRepository(db),
    ).createBackup();

    expect(result.isSuccess, isTrue);
    expect(result.rowCounts['rounds'], 1);

    final bundle = BackupCodec.decode(destination.contents!);
    expect(bundle.payload.rounds.single.courseId, 404);
    // The file is faithful, and honest about what a restore would find in it.
    expect(bundle.payload.validate(), isNotEmpty);
  });

  test('the destination is called exactly once per export', () async {
    final destination = FakeDestination();

    await service(destination).createBackup();

    expect(destination.calls, 1);
  });
}
