import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/events/edit_event_result_dialog.dart';
import 'package:golfy_app/features/events/event_detail_screen.dart';
import 'package:golfy_app/features/events/rename_event_dialog.dart';
import 'package:golfy_app/features/rounds/new_round_dialog.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<Event>> eventsController;
  late StreamController<List<RoundWithCourse>> roundsController;
  late StreamController<List<Course>> coursesController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    eventsController = StreamController<List<Event>>.broadcast();
    roundsController = StreamController<List<RoundWithCourse>>.broadcast();
    coursesController = StreamController<List<Course>>.broadcast();
  });

  tearDown(() async {
    await eventsController.close();
    await roundsController.close();
    await coursesController.close();
    await db.close();
  });

  Widget wrap(int eventId) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        eventsStreamProvider.overrideWith((ref) => eventsController.stream),
        roundsStreamProvider.overrideWith((ref) => roundsController.stream),
        // The Add-round dialog embeds a CoursePicker watching this — override
        // it so it doesn't open a live drift watcher.
        coursesByNameStreamProvider
            .overrideWith((ref) => coursesController.stream),
      ],
      child: MaterialApp(home: EventDetailScreen(eventId: eventId)),
    );
  }

  Event makeEvent({
    int id = 9,
    String name = 'Club Championship',
    int? finishPosition,
    bool tied = false,
    bool missedCut = false,
  }) =>
      Event(
        id: id,
        name: name,
        finishPosition: finishPosition,
        tied: tied,
        missedCut: missedCut,
      );

  RoundWithCourse makeRound({
    required int id,
    Event? event,
    String courseName = 'Pebble',
    int roundNumber = 1,
    int holesEntered = 18,
    int totalScore = 72,
    int totalPar = 72,
  }) {
    return RoundWithCourse(
      round: Round(
        id: id,
        date: '2026-05-25',
        courseId: 1,
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

  Future<void> emit(
    WidgetTester tester, {
    required List<Event> events,
    List<RoundWithCourse> rounds = const [],
  }) async {
    eventsController.add(events);
    roundsController.add(rounds);
    await tester.pumpAndSettle();
  }

  testWidgets('renders the event name, result badge, and only its rounds',
      (tester) async {
    final event = makeEvent(id: 9, finishPosition: 1);
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [event], rounds: [
      makeRound(id: 1, courseName: 'Pebble', event: event),
      makeRound(id: 2, courseName: 'Casual Course'), // casual — excluded
    ]);

    expect(find.text('Club Championship'), findsWidgets); // AppBar title
    expect(find.byKey(const ValueKey('event_result_badge_9')), findsOneWidget);
    expect(find.text('Pebble — Round 1'), findsOneWidget); // the round row
    expect(find.textContaining('Casual Course'), findsNothing);
  });

  testWidgets('shows the event scoring summary', (tester) async {
    final event = makeEvent(id: 9);
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [event], rounds: [
      makeRound(id: 1, event: event, totalScore: 75, totalPar: 72), // +3
      makeRound(id: 2, event: event, totalScore: 70, totalPar: 72), // -2
    ]);

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('event_stat_rounds'))).data,
      '2',
    );
    // Best of +3 / -2 is -2.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('event_stat_best'))).data,
      '-2',
    );
  });

  testWidgets('empty event shows the no-rounds hint and no stats card',
      (tester) async {
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [makeEvent(id: 9)], rounds: const []);

    expect(find.textContaining('No rounds in this event yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('event_stat_rounds')), findsNothing);
  });

  testWidgets('Edit result opens the result dialog', (tester) async {
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [makeEvent(id: 9)], rounds: const []);

    await tester.tap(find.byKey(const ValueKey('event_detail_edit_result')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(EditEventResultDialog), findsOneWidget);
  });

  testWidgets('overflow -> Rename opens the rename dialog', (tester) async {
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [makeEvent(id: 9)], rounds: const []);

    await tester.tap(find.byKey(const ValueKey('event_detail_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(RenameEventDialog), findsOneWidget);
  });

  testWidgets('overflow -> Delete shows kept-rounds copy and deletes the event',
      (tester) async {
    final eid =
        await db.eventDao.insert(EventsCompanion.insert(name: 'Club Champ'));
    final event = await db.eventDao.getById(eid);

    await tester.pumpWidget(wrap(eid));
    await emit(
      tester,
      events: [event!],
      rounds: [makeRound(id: 1, event: event)],
    );

    await tester.tap(find.byKey(const ValueKey('event_detail_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete event?'), findsOneWidget);
    expect(find.textContaining('will be kept'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(await tester.runAsync(() => db.eventDao.getById(eid)), isNull);
  });

  testWidgets('Add round opens the New Round dialog with the event preselected',
      (tester) async {
    final event = makeEvent(id: 9);
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [event], rounds: const []);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NewRoundDialog), findsOneWidget);
    // The embedded EventPicker shows the pre-selected event's name.
    expect(find.text('Club Championship'), findsWidgets);
  });
}
