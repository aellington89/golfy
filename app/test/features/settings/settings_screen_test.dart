// Settings screen + Export action (#69).
//
// Pumps the real screen over an in-memory database with a fake destination, so
// the whole export runs — read, encode, self-check — without a share sheet or
// a save dialog anywhere near the test.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_destination.dart';
import 'package:golfy_app/data/backup/backup_provider.dart';
import 'package:golfy_app/data/backup/backup_service.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/settings/settings_screen.dart';

import '../../dao/_fixtures.dart';

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

void main() {
  late GolfyDatabase db;
  late TestFixtures fixtures;
  late FakeDestination destination;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    fixtures = TestFixtures(db);
    destination = FakeDestination();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap({
    List<RoundWithCourse> rounds = const [],
    List<Course> courses = const [],
    List<Event> events = const [],
  }) {
    return ProviderScope(
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
      ],
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

    testWidgets('says what restoring will need', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(
        find.textContaining('Restoring a backup is coming'),
        findsOneWidget,
      );
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
}
