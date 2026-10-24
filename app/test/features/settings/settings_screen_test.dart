// Settings screen + Export action (#69) + Restore action (#70).
//
// Pumps the real screen over an in-memory database with a fake destination
// and a fake source, so the whole export runs — read, encode, self-check — and
// the whole restore runs — read, check, confirm, replace — without a share
// sheet, a save dialog or a file picker anywhere near the test.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_destination.dart';
import 'package:golfy_app/data/backup/backup_provider.dart';
import 'package:golfy_app/data/backup/backup_service.dart';
import 'package:golfy_app/data/backup/backup_source.dart';
import 'package:golfy_app/data/backup/restore_service.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/rounds/active_round_provider.dart';
import 'package:golfy_app/features/settings/restore_confirm_dialog.dart';
import 'package:golfy_app/features/settings/settings_screen.dart';

import '../../dao/_fixtures.dart';
import '../../data/backup/_sample.dart';

class FakeDestination implements BackupDestination {
  FakeDestination([this.outcome = const BackupSaveOutcome.shared()]);

  BackupSaveOutcome outcome;
  int calls = 0;
  String? fileName;
  String? contents;

  /// When set, `save` waits on this — for asserting the in-flight state.
  Completer<void>? gate;

  @override
  Future<BackupSaveOutcome> save({
    required String fileName,
    required String contents,
  }) async {
    calls++;
    this.fileName = fileName;
    this.contents = contents;
    if (gate != null) await gate!.future;
    return outcome;
  }
}

/// Hands the restore whatever it was told to, standing in for the picker.
class FakeSource implements BackupSource {
  FakeSource([this.outcome = const BackupPickCancelled()]);

  BackupPickOutcome outcome;
  int calls = 0;

  /// When set, `pick` waits on this — for asserting the in-flight state.
  Completer<void>? gate;

  void holds(String contents, {String fileName = 'golfy-backup.json'}) {
    outcome =
        BackupPicked(fileName, Uint8List.fromList(utf8.encode(contents)));
  }

  @override
  Future<BackupPickOutcome> pick() async {
    calls++;
    if (gate != null) await gate!.future;
    return outcome;
  }
}

void main() {
  late GolfyDatabase db;
  late TestFixtures fixtures;
  late FakeDestination destination;
  late FakeSource source;
  late ProviderContainer container;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fixtures = TestFixtures(db);
    destination = FakeDestination();
    source = FakeSource();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap({
    List<RoundWithCourse> rounds = const [],
    List<Course> courses = const [],
    List<Event> events = const [],
  }) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        roundsStreamProvider.overrideWith((ref) => Stream.value(rounds)),
        coursesStreamProvider.overrideWith((ref) => Stream.value(courses)),
        eventsStreamProvider.overrideWith((ref) => Stream.value(events)),
        coursesByNameStreamProvider
            .overrideWith((ref) => Stream.value(const <Course>[])),
        backupDestinationProvider.overrideWithValue(destination),
        // The real service, minus the two things a test cannot have: the
        // platform's package info and the actual time.
        backupServiceProvider.overrideWith((ref) => BackupService(
              repository: GolfyRepository(db),
              destination: destination,
              readAppVersion: () async => '0.4.0+38',
              clock: () => DateTime(2026, 10, 3, 14, 32),
              platformName: 'android',
            )),
        backupSourceProvider.overrideWithValue(source),
        restoreServiceProvider.overrideWith((ref) => RestoreService(
              repository: GolfyRepository(db),
              source: source,
            )),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  Course course(int id) =>
      Course(id: id, name: 'Pebble $id', gameTitle: 'PGA Tour 2K25');

  Event event(int id) =>
      Event(id: id, name: 'Event $id', season: 1, tied: false, missedCut: false);

  RoundWithCourse round(int id) => RoundWithCourse(
        round: Round(id: id, date: '2026-05-19', courseId: 1, roundNumber: 1),
        courseName: 'Pebble 1',
        event: null,
        holesEntered: 18,
        totalScore: 72,
        totalPar: 72,
      );

  Finder tile() => find.byKey(const ValueKey('settings_export_tile'));

  group('the screen', () {
    testWidgets('shows the Data section and what a backup is', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);
      expect(
        find.textContaining('you choose where it goes'),
        findsOneWidget,
      );
      expect(find.text('Back up your data'), findsOneWidget);
    });

    testWidgets('offers to restore, and says what restoring does',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Restore from a backup'), findsOneWidget);
      expect(
        find.textContaining('Restoring replaces everything on this device'),
        findsOneWidget,
      );
      expect(find.textContaining('coming in a later update'), findsNothing);
    });

    testWidgets('counts what is about to be saved', (tester) async {
      await tester.pumpWidget(wrap(
        rounds: [round(1), round(2), round(3)],
        courses: [course(1), course(2)],
        events: [event(1)],
      ));
      await tester.pump();

      expect(find.text('3 rounds · 2 courses · 1 event'), findsOneWidget);
    });

    testWidgets('says so when there is nothing recorded yet', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });
  });

  group('exporting', () {
    testWidgets('hands the platform a named file holding the data',
        (tester) async {
      await fixtures.seedFullBackupFixture();
      await tester.pumpWidget(wrap(rounds: [round(1)], courses: [course(1)]));
      await tester.pump();

      await tester.tap(tile());
      await tester.pumpAndSettle();

      expect(destination.calls, 1);
      expect(destination.fileName, 'golfy-backup-20261003-1432.json');
      final decoded = BackupCodec.decode(destination.contents!);
      expect(decoded.payload.rowCounts['hole_results'], 26);
      expect(decoded.payload.validate(), isEmpty);
    });

    testWidgets('confirms with the file name when it was shared',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(tile());
      await tester.pumpAndSettle();

      expect(
        find.text('Backup created · golfy-backup-20261003-1432.json'),
        findsOneWidget,
      );
    });

    testWidgets('confirms with the path when it was saved', (tester) async {
      destination.outcome =
          const BackupSaveOutcome.saved(r'C:\golf\golfy-backup.json');
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(tile());
      await tester.pumpAndSettle();

      expect(
        find.text(r'Backup saved · C:\golf\golfy-backup.json'),
        findsOneWidget,
      );
    });

    testWidgets('says nothing was saved when the user backs out',
        (tester) async {
      destination.outcome = const BackupSaveOutcome.cancelled();
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(tile());
      await tester.pumpAndSettle();

      expect(
        find.text('Backup cancelled — nothing saved'),
        findsOneWidget,
      );
    });

    testWidgets('reports a failure and offers to try again', (tester) async {
      destination.outcome = const BackupSaveOutcome.failed('disk full');
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(tile());
      await tester.pumpAndSettle();

      expect(find.text('Backup failed — disk full'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      destination.outcome = const BackupSaveOutcome.shared();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(destination.calls, 2);
      expect(
        find.text('Backup created · golfy-backup-20261003-1432.json'),
        findsOneWidget,
      );
    });

    testWidgets('shows progress and ignores a second tap while working',
        (tester) async {
      destination.gate = Completer<void>();
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(tile());
      await tester.pump();

      expect(
        find.byKey(const ValueKey('settings_export_progress')),
        findsOneWidget,
      );

      // A second tap while the first is in flight must not start another.
      await tester.tap(tile(), warnIfMissed: false);
      await tester.pump();
      expect(destination.calls, 1);

      destination.gate!.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_export_progress')),
        findsNothing,
      );
      expect(destination.calls, 1);
    });
  });

  group('restoring', () {
    Finder restoreTile() => find.byKey(const ValueKey('settings_restore_tile'));

    /// Something already on the device, which a restore replaces.
    Future<void> seedDevice() async {
      final course = await fixtures.insertCourse(name: 'Augusta');
      final round = await fixtures.insertRound(course, date: '2026-01-10');
      await fixtures.upsertHole(round, 1);
    }

    testWidgets('backing out of the picker changes nothing', (tester) async {
      await seedDevice();
      final before = await db.backupDao.readAll();
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(restoreTile());
      await tester.pumpAndSettle();

      expect(source.calls, 1);
      expect(find.text('Restore cancelled — nothing changed'), findsOneWidget);
      expect(await db.backupDao.readAll(), before);
    });

    testWidgets('shows progress and ignores a second tap while working',
        (tester) async {
      source.gate = Completer<void>();
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(restoreTile());
      await tester.pump();

      expect(find.byKey(const ValueKey('settings_restore_progress')),
          findsOneWidget);
      await tester.tap(restoreTile(), warnIfMissed: false);
      await tester.pump();
      expect(source.calls, 1);

      source.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings_restore_progress')),
          findsNothing);
      expect(source.calls, 1);
    });

    testWidgets('a file that cannot be restored is refused with its reason',
        (tester) async {
      await seedDevice();
      final before = await db.backupDao.readAll();
      source.holds('golf is fun');
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(restoreTile());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('restore_refused_dialog')),
          findsOneWidget);
      expect(find.textContaining('not valid JSON'), findsOneWidget);
      expect(find.text('Nothing on this device was changed.'), findsOneWidget);
      expect(await db.backupDao.readAll(), before);
    });

    testWidgets('asks first, showing the file beside the device',
        (tester) async {
      await seedDevice();
      source.holds(encodeSample());
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(restoreTile());
      await tester.pumpAndSettle();

      expect(find.text('Replace everything on this device?'), findsOneWidget);
      expect(find.text('golfy-backup.json'), findsOneWidget);
      expect(find.textContaining('by Golfy 0.4.0+38 on Android'),
          findsOneWidget);
      expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('restore_confirm_file_counts')))
            .data,
        countsSummary(samplePayload().rowCounts),
      );
      expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('restore_confirm_device_counts')))
            .data,
        '1 round · 1 course · 0 events · 1 hole · 0 shots',
      );
      expect(find.textContaining("can't be undone"), findsOneWidget);
    });

    testWidgets('cancelling the question changes nothing', (tester) async {
      await seedDevice();
      final before = await db.backupDao.readAll();
      source.holds(encodeSample());
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(restoreTile());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('restore_confirm_cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Restore cancelled — nothing changed'), findsOneWidget);
      expect(await db.backupDao.readAll(), before);
    });

    testWidgets('replacing restores the file and closes the open round',
        (tester) async {
      await seedDevice();
      source.holds(encodeSample());
      await tester.pumpWidget(wrap());
      await tester.pump();
      container.read(activeRoundIdProvider.notifier).set(1);

      await tester.tap(restoreTile());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('restore_confirm_replace')));
      await tester.pumpAndSettle();

      expect(
        find.text('Restored · ${countsSummary(samplePayload().rowCounts)}'),
        findsOneWidget,
      );
      expect(await db.backupDao.readAll(), samplePayload());
      expect(container.read(activeRoundIdProvider), isNull);
    });

    testWidgets('an empty device is asked more gently, and restored',
        (tester) async {
      source.holds(encodeSample());
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(restoreTile());
      await tester.pumpAndSettle();

      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.text('Nothing recorded yet'), findsWidgets);
      expect(find.byKey(const ValueKey('restore_confirm_backup_first')),
          findsNothing);

      await tester.tap(find.byKey(const ValueKey('restore_confirm_replace')));
      await tester.pumpAndSettle();

      expect(await db.backupDao.readAll(), samplePayload());
    });

    testWidgets('backing up first exports what is here and replaces nothing',
        (tester) async {
      await seedDevice();
      final before = await db.backupDao.readAll();
      source.holds(encodeSample());
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(restoreTile());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('restore_confirm_backup_first')));
      await tester.pumpAndSettle();

      expect(destination.calls, 1);
      expect(BackupCodec.decode(destination.contents!).payload, before);
      expect(
        find.text('Backup created · golfy-backup-20261003-1432.json'),
        findsOneWidget,
      );
      expect(await db.backupDao.readAll(), before);
    });
  });
}
