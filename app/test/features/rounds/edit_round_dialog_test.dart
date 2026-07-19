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
import 'package:golfy_app/features/events/event_picker.dart';
import 'package:golfy_app/features/rounds/edit_round_dialog.dart';

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

  // Builds a RoundWithCourse to feed the dialog. Mirrors the row model the
  // rounds list passes in; hand-built so the test controls every field.
  RoundWithCourse makeRound({
    required int id,
    int courseId = 1,
    String courseName = 'Augusta',
    String date = '2026-04-01',
    int roundNumber = 1,
    String? notes,
    Event? event,
  }) {
    return RoundWithCourse(
      round: Round(
        id: id,
        date: date,
        courseId: courseId,
        roundNumber: roundNumber,
        notes: notes,
        eventId: event?.id,
      ),
      courseName: courseName,
      event: event,
      holesEntered: 0,
      totalScore: 0,
      totalPar: 0,
    );
  }

  Event makeEvent({int id = 1, String name = 'Club Championship'}) =>
      Event(id: id, name: name, tied: false, missedCut: false);

  Widget wrap({
    required RoundWithCourse round,
    List<RoundWithCourse> existingRounds = const [],
    List<Course> existingCourses = const [],
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
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => EditRoundDialog(
                      round: round,
                      existingRounds: existingRounds,
                      existingCourses: existingCourses,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> openDialog(
    WidgetTester tester, {
    required RoundWithCourse round,
    List<RoundWithCourse> existingRounds = const [],
    List<Event> existingEvents = const [],
    List<Course> existingCourses = const [],
  }) async {
    await tester.pumpWidget(wrap(
      round: round,
      existingRounds: existingRounds,
      existingCourses: existingCourses,
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    // Feed the pickers' streams. The pre-selected course/event come from the
    // round + snapshots, but emit so the pickers aren't stuck loading (and so
    // the event sheet lists these events).
    coursesController.add(existingCourses);
    eventsController.add(existingEvents);
    await tester.pumpAndSettle();
  }

  // Opens the EventPicker sheet and taps the row with [name] (an existing event
  // or "No event / Casual round"). Requires events to have been emitted.
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

  // Flushes the real async write against the in-memory db before pumping.
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills fields from the round', (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    final event = makeEvent(id: 7, name: 'Club Championship');
    final round = makeRound(
      id: 1,
      roundNumber: 3,
      notes: 'breezy',
      event: event,
    );

    await openDialog(
      tester,
      round: round,
      existingCourses: const [course],
      existingEvents: [event],
    );

    // Course name in the course picker, event name in the event picker, the
    // round's number in the stepper, and its notes in the notes field.
    expect(find.text('Augusta'), findsOneWidget);
    expect(find.text('Club Championship'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('breezy'), findsOneWidget);
  });

  testWidgets('attaching a new event to a casual round links and creates it',
      (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    // Course first — the round's courseId FK needs it to exist.
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(date: '2026-04-01', courseId: 1),
    );
    final round = makeRound(id: rid);

    await openDialog(tester, round: round, existingCourses: const [course]);

    // Open the event picker → "Add new event…" → name it.
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
    // Flush the insert, then let the add-event dialog close (bounded pumps
    // while its text field still holds focus).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    expect(find.byType(EditRoundDialog), findsNothing);

    final events = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(events!.map((e) => e.name), contains('Club Championship'));

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.eventId, isNotNull);
  });

  testWidgets('selecting an existing event reuses it without a duplicate',
      (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final eid = await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(date: '2026-04-01', courseId: 1),
    );
    final event = makeEvent(id: eid, name: 'Club Championship');
    final round = makeRound(id: rid);

    await openDialog(
      tester,
      round: round,
      existingCourses: const [course],
      existingEvents: [event],
    );

    await selectEvent(tester, 'Club Championship');

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    // No second event created — the existing one was reused.
    final events = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(events, hasLength(1));

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.eventId, eid);
  });

  testWidgets('clearing the event field detaches the round', (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final eid = await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(
        date: '2026-04-01',
        courseId: 1,
        eventId: Value(eid),
      ),
    );
    final event = makeEvent(id: eid, name: 'Club Championship');
    final round = makeRound(id: rid, event: event);

    await openDialog(
      tester,
      round: round,
      existingCourses: const [course],
      existingEvents: [event],
    );

    // Field starts pre-filled with the event; choose "No event" to detach.
    await selectEvent(tester, 'No event / Casual round');

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.eventId, isNull);
  });

  testWidgets(
      'editing into an existing (date, course, round#) shows an inline error',
      (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final r1 = await db.roundDao.insert(RoundsCompanion.insert(
        date: '2026-04-01', courseId: 1, roundNumber: const Value(1)));
    final r2 = await db.roundDao.insert(RoundsCompanion.insert(
        date: '2026-04-01', courseId: 1, roundNumber: const Value(2)));
    final existing = [
      makeRound(id: r1, roundNumber: 1),
      makeRound(id: r2, roundNumber: 2),
    ];

    // Editing r2, decrement its number to 1 to collide with r1.
    await openDialog(
      tester,
      round: existing[1],
      existingRounds: existing,
      existingCourses: const [course],
    );

    await tester.tap(find.byKey(const ValueKey('round_number_dec')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.byType(EditRoundDialog), findsOneWidget);

    // r2 is untouched in the db (still round number 2).
    final row = await tester.runAsync(() => db.roundDao.getById(r2));
    expect(row!.roundNumber, 2);
  });

  testWidgets('editing notes persists', (tester) async {
    const course = Course(id: 1, name: 'Augusta', gameTitle: 'PGA');
    await db.courseDao.insert(
      CoursesCompanion.insert(name: 'Augusta', gameTitle: 'PGA'),
    );
    final rid = await db.roundDao.insert(
      RoundsCompanion.insert(date: '2026-04-01', courseId: 1),
    );
    final round = makeRound(id: rid);

    await openDialog(tester, round: round, existingCourses: const [course]);

    // Notes is now the only TextFormField in the dialog (the event field is a
    // picker, not a text field).
    await tester.enterText(
      find.byType(TextFormField).last,
      'gusty back nine',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit_round_save')));
    await flush(tester);

    final row = await tester.runAsync(() => db.roundDao.getById(rid));
    expect(row!.notes, 'gusty back nine');
  });
}
