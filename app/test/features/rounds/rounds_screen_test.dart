import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/events/edit_event_result_dialog.dart';
import 'package:golfy_app/features/rounds/active_round_provider.dart';
import 'package:golfy_app/features/rounds/edit_round_dialog.dart';
import 'package:golfy_app/features/rounds/new_round_dialog.dart';
import 'package:golfy_app/features/rounds/rounds_screen.dart';
import 'package:golfy_app/widgets/empty_state.dart';
import 'package:golfy_app/features/rounds/scorecard/scorecard_screen.dart';
import 'package:golfy_app/shell/tab_index_provider.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<RoundWithCourse>> roundsController;
  late StreamController<List<Course>> coursesController;
  late StreamController<List<Event>> eventsController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    roundsController = StreamController<List<RoundWithCourse>>.broadcast();
    coursesController = StreamController<List<Course>>.broadcast();
    eventsController = StreamController<List<Event>>.broadcast();
  });

  tearDown(() async {
    await roundsController.close();
    await coursesController.close();
    await eventsController.close();
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        roundsStreamProvider
            .overrideWith((ref) => roundsController.stream),
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
        // The New/Edit Round dialogs opened from this screen embed an
        // EventPicker that watches eventsStreamProvider; override it with a
        // manual stream so it doesn't spin up a live drift watcher (whose
        // pending timer fails flutter_test's !timersPending invariant).
        eventsStreamProvider.overrideWith((ref) => eventsController.stream),
      ],
      child: const MaterialApp(home: RoundsScreen()),
    );
  }

  // pumpAndSettle is safe here: this screen has no autofocused
  // TextFormField, so there's no cursor-blink timer to keep frames pending.
  Future<void> emitRounds(
    WidgetTester tester,
    List<RoundWithCourse> rounds,
  ) async {
    roundsController.add(rounds);
    await tester.pumpAndSettle();
  }

  Future<void> emitCourses(
    WidgetTester tester,
    List<Course> courses,
  ) async {
    coursesController.add(courses);
    await tester.pumpAndSettle();
  }

  Event makeEvent({
    int id = 1,
    String name = 'Club Championship',
    int season = 1,
    int? finishPosition,
    bool tied = false,
    bool missedCut = false,
  }) {
    return Event(
      id: id,
      name: name,
      season: season,
      finishPosition: finishPosition,
      tied: tied,
      missedCut: missedCut,
    );
  }

  RoundWithCourse makeRound({
    int id = 1,
    int courseId = 1,
    String courseName = 'Pebble',
    String date = '2026-05-25',
    int roundNumber = 1,
    int holesEntered = 0,
    int totalScore = 0,
    int totalPar = 0,
    Event? event,
  }) {
    return RoundWithCourse(
      round: Round(
        id: id,
        date: date,
        courseId: courseId,
        roundNumber: roundNumber,
        eventId: event?.id,
      ),
      courseName: courseName,
      event: event,
      holesEntered: holesEntered,
      totalScore: totalScore,
      totalPar: totalPar,
    );
  }

  testWidgets('empty state copy renders when there are no rounds',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, const []);

    expect(
      find.text('No rounds yet. Tap + to start your first round.'),
      findsOneWidget,
    );
    // Scoped to the empty state — the AppBar's "Manage courses" action uses the
    // same golf icon, so an unscoped finder would match both.
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byIcon(Icons.golf_course_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'row shows course name with round number, formatted date, and X/18',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(
        date: '2026-05-25',
        roundNumber: 2,
        holesEntered: 12,
        totalScore: 50,
        totalPar: 48,
      ),
    ]);

    expect(find.text('Pebble — Round 2'), findsOneWidget);
    expect(find.text('May 25, 2026'), findsOneWidget);
    expect(find.text('12/18'), findsOneWidget);
  });

  testWidgets('row shows a +N score badge for an over-par round',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(id: 3, holesEntered: 18, totalScore: 75, totalPar: 72),
    ]);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('round_score_3'))).data,
      '+3',
    );
  });

  testWidgets('row shows E for an even-par round', (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(id: 4, holesEntered: 18, totalScore: 72, totalPar: 72),
    ]);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('round_score_4'))).data,
      'E',
    );
  });

  testWidgets('row shows -N and a green badge for an under-par round',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(id: 5, holesEntered: 18, totalScore: 70, totalPar: 72),
    ]);

    final badge = tester.widget<Text>(
      find.byKey(const ValueKey('round_score_5')),
    );
    expect(badge.data, '-2');
    expect(badge.style?.color, Colors.green.shade700);
  });

  testWidgets('partial round shows the score for entered holes only',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(id: 6, holesEntered: 12, totalScore: 50, totalPar: 48),
    ]);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('round_score_6'))).data,
      '+2',
    );
    // X/18 still communicates the round is incomplete.
    expect(find.text('12/18'), findsOneWidget);
  });

  testWidgets('empty round shows no score badge, just 0/18', (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(id: 7, holesEntered: 0),
    ]);

    expect(find.byKey(const ValueKey('round_score_7')), findsNothing);
    expect(find.text('0/18'), findsOneWidget);
  });

  testWidgets('FAB opens the New Round dialog', (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, const []);
    await emitCourses(tester, const []);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(NewRoundDialog), findsOneWidget);
  });

  testWidgets('row edit button opens the Edit Round dialog', (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound(id: 5, courseName: 'Pebble')]);
    await emitCourses(
      tester,
      const [Course(id: 1, name: 'Pebble', gameTitle: 'PGA')],
    );

    await tester.tap(find.byKey(const ValueKey('round_edit_button_5')));
    // openEditRoundDialog awaits repo.watchCoursesByName().first on the real
    // db to pre-select the course, so flush real async before settling.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byType(EditRoundDialog), findsOneWidget);
  });

  testWidgets(
      'swipe-to-delete with confirm removes the round and clears active id',
      (tester) async {
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Pebble', gameTitle: 'PGA'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(
        date: '2026-05-25',
        courseId: 1,
        roundNumber: const Value(1),
      ),
    );

    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound(id: rid, holesEntered: 0)]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoundsScreen)),
    );
    container.read(activeRoundIdProvider.notifier).set(rid);
    expect(container.read(activeRoundIdProvider), rid);

    await tester.drag(
      find.textContaining('Pebble'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete round?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await emitRounds(tester, const []);

    expect(find.textContaining('Pebble'), findsNothing);
    expect(container.read(activeRoundIdProvider), isNull);

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds, isEmpty);
  });

  testWidgets(
      'tapping a round row sets activeRoundId and switches to Hole Entry tab',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound(id: 42, courseName: 'Pebble')]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(RoundsScreen)),
    );
    expect(container.read(activeRoundIdProvider), isNull);
    expect(container.read(tabIndexProvider), 0);

    await tester.tap(find.textContaining('Pebble'));
    await tester.pump();

    expect(container.read(activeRoundIdProvider), 42);
    expect(container.read(tabIndexProvider), ShellTabs.holeEntry);
  });

  testWidgets(
      'tapping the scorecard icon opens the scorecard without resuming',
      (tester) async {
    // Own the container explicitly and dispose it in a tearDown (real async)
    // so the scorecard's live drift streams drain their close timers without
    // tripping the fake-async pending-timer check.
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        roundsStreamProvider.overrideWith((ref) => roundsController.stream),
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoundsScreen()),
      ),
    );
    roundsController.add([makeRound(id: 7, courseName: 'Pebble')]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('scorecard_button_7')));
    await tester.pump();
    // Let the scorecard's hole stream deliver before settling the transition.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ScorecardScreen), findsOneWidget);
    // The icon opens the read-only view; it must NOT trigger tap-to-resume.
    expect(container.read(tabIndexProvider), 0);
    expect(container.read(activeRoundIdProvider), isNull);
  });

  testWidgets('swipe-to-delete with cancel keeps the row', (tester) async {
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound()]);

    await tester.drag(
      find.textContaining('Pebble'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete round?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pebble'), findsOneWidget);
  });

  testWidgets('groups rounds under event headers with a separate casual group',
      (tester) async {
    final event = makeEvent(id: 9, name: 'Club Championship');
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [
      makeRound(id: 1, date: '2026-05-25', courseName: 'Pebble', event: event),
      makeRound(id: 2, date: '2026-05-24', courseName: 'Augusta', event: event),
      makeRound(id: 3, date: '2026-05-23', courseName: 'Spyglass'),
    ]);

    // One event header for the two tournament rounds, plus a casual group.
    expect(find.byKey(const ValueKey('event_header_9')), findsOneWidget);
    expect(find.text('Club Championship (Season 1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('event_header_casual')), findsOneWidget);
    expect(find.text('No event'), findsOneWidget);
    // Every round still renders.
    expect(find.textContaining('Pebble'), findsOneWidget);
    expect(find.textContaining('Augusta'), findsOneWidget);
    expect(find.textContaining('Spyglass'), findsOneWidget);
  });

  testWidgets('event header shows the recorded result badge', (tester) async {
    final event = makeEvent(id: 9, name: 'Club Championship', finishPosition: 1);
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound(id: 1, event: event)]);

    expect(find.byKey(const ValueKey('event_result_badge_9')), findsOneWidget);
    expect(find.text('1st'), findsOneWidget);
  });

  testWidgets('tapping a header edit action opens the result dialog',
      (tester) async {
    final event = makeEvent(id: 9, name: 'Club Championship');
    await tester.pumpWidget(wrap());
    await emitRounds(tester, [makeRound(id: 1, event: event)]);

    await tester.tap(find.byKey(const ValueKey('event_result_edit_9')));
    await tester.pumpAndSettle();

    expect(find.byType(EditEventResultDialog), findsOneWidget);
  });
}
