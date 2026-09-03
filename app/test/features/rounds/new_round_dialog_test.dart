import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/courses/course_picker.dart';
import 'package:golfy_app/features/events/event_picker.dart';
import 'package:golfy_app/features/rounds/active_round_provider.dart';
import 'package:golfy_app/features/rounds/new_round_dialog.dart';
import 'package:golfy_app/shell/tab_index_provider.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<Course>> coursesController;
  late StreamController<List<Event>> eventsController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    coursesController = StreamController<List<Course>>.broadcast();
    eventsController = StreamController<List<Event>>.broadcast();
  });

  tearDown(() async {
    await coursesController.close();
    await eventsController.close();
    await db.close();
  });

  Widget wrap({
    List<RoundWithCourse> existing = const [],
    Event? initialEvent,
    void Function(int?)? onResult,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
        eventsStreamProvider.overrideWith((ref) => eventsController.stream),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<int>(
                      context: context,
                      builder: (_) => NewRoundDialog(
                        existingRounds: existing,
                        initialEvent: initialEvent,
                      ),
                    );
                    if (onResult != null) onResult(result);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // pumpAndSettle is safe here: no TextFormField is autofocused in the
  // dialog, so there's no cursor-blink timer to keep frames pending.
  // Bounded pumps were avoided because tester.pump() with no duration
  // doesn't advance animation clocks (FAB scale-in, sheet enter/exit).
  Future<void> openDialog(
    WidgetTester tester, {
    List<RoundWithCourse> existing = const [],
    Event? initialEvent,
    void Function(int?)? onResult,
  }) async {
    await tester.pumpWidget(wrap(
      existing: existing,
      initialEvent: initialEvent,
      onResult: onResult,
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> emitCourses(WidgetTester tester, List<Course> courses) async {
    coursesController.add(courses);
    await tester.pumpAndSettle();
  }

  Future<void> emitEvents(WidgetTester tester, List<Event> events) async {
    eventsController.add(events);
    await tester.pumpAndSettle();
  }

  Future<void> selectCourse(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(CoursePicker),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
  }

  // Opens the EventPicker sheet and taps the row with [name] (an existing event
  // or "No event / Casual round"). Requires events to have been emitted so the
  // picker is out of its loading state and rendering its tappable field.
  Future<void> selectEvent(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(EventPicker),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, name));
    await tester.pumpAndSettle();
  }

  String todayIso() {
    final t = DateTime.now();
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  ProviderContainer containerFor(WidgetTester tester) {
    return ProviderScope.containerOf(
      tester.element(find.byType(NewRoundDialog).first),
    );
  }

  testWidgets('submitting without a course shows error and does not insert',
      (tester) async {
    await openDialog(tester);
    await emitCourses(tester, const []);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Round'));
    await tester.pumpAndSettle();

    expect(find.text('Course is required'), findsOneWidget);
    expect(find.byType(NewRoundDialog), findsOneWidget);

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds, isEmpty);
  });

  testWidgets(
      'round number auto-increments to next after picking course with prior round',
      (tester) async {
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Pebble', gameTitle: 'PGA'),
    );
    final iso = todayIso();
    final existingRid = await db.roundDao.insert(
      RoundsCompanion.insert(date: iso, courseId: 1),
    );

    final existingRounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );

    await openDialog(tester, existing: existingRounds!);
    await emitCourses(
      tester,
      const [Course(id: 1, name: 'Pebble', gameTitle: 'PGA')],
    );

    // Initial value: 1 (no course selected yet)
    expect(find.text('1'), findsOneWidget);

    await selectCourse(tester, 'Pebble');

    // After course selection, auto-recompute sees existing round# 1 and
    // bumps the default to 2.
    expect(find.text('2'), findsOneWidget);
    expect(existingRid, 1);
  });

  testWidgets(
      'submitting a duplicate (date, course, round#) shows inline error',
      (tester) async {
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Pebble', gameTitle: 'PGA'),
    );
    final iso = todayIso();
    await db.roundDao.insert(
      RoundsCompanion.insert(date: iso, courseId: 1),
    );

    final existingRounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );

    await openDialog(tester, existing: existingRounds!);
    await emitCourses(
      tester,
      const [Course(id: 1, name: 'Pebble', gameTitle: 'PGA')],
    );

    await selectCourse(tester, 'Pebble');
    // Auto-default is 2 — decrement to 1 to collide with the existing round.
    await tester.tap(find.byKey(const ValueKey('round_number_dec')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start Round'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('already exists'),
      findsOneWidget,
    );
    expect(find.byType(NewRoundDialog), findsOneWidget);

    // Still just the one round from setup.
    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds, hasLength(1));
  });

  testWidgets(
      'valid input inserts row, sets activeRoundIdProvider, switches tab',
      (tester) async {
    int? popped;
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );

    await openDialog(tester, onResult: (id) => popped = id);
    await emitCourses(
      tester,
      const [Course(id: 1, name: 'Augusta', gameTitle: 'PGA')],
    );
    await selectCourse(tester, 'Augusta');

    // Grab the provider container while the dialog is still in the tree.
    final container = containerFor(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Round'));
    // Flush the real async insert before pumping frames.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byType(NewRoundDialog), findsNothing);
    expect(popped, isNotNull);

    expect(container.read(activeRoundIdProvider), popped);
    expect(container.read(tabIndexProvider), ShellTabs.holeEntry);

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds, hasLength(1));
    expect(rounds!.single.round.courseId, 1);
    expect(rounds.single.round.roundNumber, 1);
    // No event typed -> casual round.
    expect(rounds.single.round.eventId, isNull);
  });

  testWidgets('adding a new event via "Add new event…" creates and links it',
      (tester) async {
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );

    await openDialog(tester);
    await emitCourses(
      tester,
      const [Course(id: 1, name: 'Augusta', gameTitle: 'PGA')],
    );
    await emitEvents(tester, const []);
    await selectCourse(tester, 'Augusta');

    // Open the event picker and choose "Add new event…".
    await tester.tap(
      find.descendant(
        of: find.byType(EventPicker),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Add new event…'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'Club Championship',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    // Flush the real async insert, then let the add-event dialog close. Bounded
    // pumps (not pumpAndSettle) while its text field still holds focus.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.widgetWithText(FilledButton, 'Start Round'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final events = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(events, hasLength(1));
    expect(events!.single.name, 'Club Championship');

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds!.single.round.eventId, events.single.id);
    expect(rounds.single.event?.name, 'Club Championship');
  });

  testWidgets(
      'selecting an existing event links the round without creating a duplicate',
      (tester) async {
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final eventId = await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );
    final existingEvents =
        await tester.runAsync(() => db.eventDao.watchAll().first);

    await openDialog(tester);
    await emitCourses(
      tester,
      const [Course(id: 1, name: 'Augusta', gameTitle: 'PGA')],
    );
    await emitEvents(tester, existingEvents!);
    await selectCourse(tester, 'Augusta');
    await selectEvent(tester, 'Club Championship (Season 1)');

    await tester.tap(find.widgetWithText(FilledButton, 'Start Round'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // No second event created — the existing one was reused.
    final events = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(events, hasLength(1));

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds!.single.round.eventId, eventId);
  });

  testWidgets(
      'initialEvent pre-selects the event and links the started round',
      (tester) async {
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final eventId = await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );
    final event = await db.eventDao.getById(eventId);

    await openDialog(tester, initialEvent: event);
    await emitCourses(
      tester,
      const [Course(id: 1, name: 'Augusta', gameTitle: 'PGA')],
    );
    await emitEvents(tester, [event!]);

    // The picker shows the pre-selected event's title (no picking required).
    expect(find.text('Club Championship (Season 1)'), findsOneWidget);

    await selectCourse(tester, 'Augusta');
    final container = containerFor(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Round'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(container.read(tabIndexProvider), ShellTabs.holeEntry);

    final rounds = await tester.runAsync(
      () => db.roundDao.watchAllWithCourse().first,
    );
    expect(rounds!.single.round.eventId, eventId);
  });
}
