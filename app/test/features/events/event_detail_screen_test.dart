import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/event_stats.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/events/edit_event_result_dialog.dart';
import 'package:golfy_app/features/events/event_detail_screen.dart';
import 'package:golfy_app/features/events/edit_event_dialog.dart';
import 'package:golfy_app/features/rounds/new_round_dialog.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<Event>> eventsController;
  // The full rounds stream — the screen reads it only for the Add-round dialog's
  // (global) duplicate / auto-number pre-check.
  late StreamController<List<RoundWithCourse>> roundsController;
  // The keyed per-event rounds (roundsForEventProvider) — backs the body list
  // and the delete-confirmation round count.
  late StreamController<List<RoundWithCourse>> eventRoundsController;
  // The keyed per-event scoring aggregate (eventStatsStreamProvider) — backs the
  // summary card (#56).
  late StreamController<EventStats> statsController;
  late StreamController<List<Course>> coursesController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    eventsController = StreamController<List<Event>>.broadcast();
    roundsController = StreamController<List<RoundWithCourse>>.broadcast();
    eventRoundsController = StreamController<List<RoundWithCourse>>.broadcast();
    statsController = StreamController<EventStats>.broadcast();
    coursesController = StreamController<List<Course>>.broadcast();
  });

  tearDown(() async {
    await eventsController.close();
    await roundsController.close();
    await eventRoundsController.close();
    await statsController.close();
    await coursesController.close();
    await db.close();
  });

  Widget wrap(int eventId) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        eventsStreamProvider.overrideWith((ref) => eventsController.stream),
        roundsStreamProvider.overrideWith((ref) => roundsController.stream),
        roundsForEventProvider(eventId)
            .overrideWith((ref) => eventRoundsController.stream),
        eventStatsStreamProvider(eventId)
            .overrideWith((ref) => statsController.stream),
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
    int season = 1,
    int? finishPosition,
    bool tied = false,
    bool missedCut = false,
  }) =>
      Event(
        id: id,
        name: name,
        season: season,
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

  /// Pushes a frame of state onto the overridden providers. [eventRounds]
  /// defaults to [rounds] (the common case where the body list mirrors what is
  /// seeded); pass it explicitly to make the keyed body list differ from the
  /// full rounds stream. [stats] backs the summary card.
  Future<void> emit(
    WidgetTester tester, {
    required List<Event> events,
    List<RoundWithCourse> rounds = const [],
    List<RoundWithCourse>? eventRounds,
    EventStats stats = EventStats.empty,
  }) async {
    eventsController.add(events);
    roundsController.add(rounds);
    eventRoundsController.add(eventRounds ?? rounds);
    statsController.add(stats);
    await tester.pumpAndSettle();
  }

  testWidgets('renders the event name, result badge, and only its rounds',
      (tester) async {
    final event = makeEvent(id: 9, finishPosition: 1);
    await tester.pumpWidget(wrap(9));
    // The full stream carries a casual round too; the body must render only the
    // keyed per-event rounds, so the casual one never appears.
    await emit(
      tester,
      events: [event],
      rounds: [
        makeRound(id: 1, courseName: 'Pebble', event: event),
        makeRound(id: 2, courseName: 'Casual Course'),
      ],
      eventRounds: [makeRound(id: 1, courseName: 'Pebble', event: event)],
    );

    expect(find.text('Club Championship (Season 1)'),
        findsWidgets); // AppBar title
    expect(find.byKey(const ValueKey('event_result_badge_9')), findsOneWidget);
    expect(find.text('Pebble — Round 1'), findsOneWidget); // the round row
    expect(find.textContaining('Casual Course'), findsNothing);
  });

  testWidgets('shows the event scoring summary', (tester) async {
    final event = makeEvent(id: 9);
    await tester.pumpWidget(wrap(9));
    await emit(
      tester,
      events: [event],
      eventRounds: [
        makeRound(id: 1, event: event),
        makeRound(id: 2, event: event),
      ],
      stats: const EventStats(
        roundsScored: 2,
        holesPlayed: 36,
        avgScorePerRound: 72.5,
        avgScoreVsPar: 0.5,
        bestRound: BestRound(
          roundId: 2,
          courseName: 'Pebble',
          date: '2026-05-25',
          toPar: -2,
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('event_stat_rounds'))).data,
      '2',
    );
    // Best round comes straight from the aggregate: -2.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('event_stat_best'))).data,
      '-2',
    );
  });

  testWidgets('empty event shows the no-rounds hint and no stats card',
      (tester) async {
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [makeEvent(id: 9)]); // no rounds, empty stats

    expect(find.textContaining('No rounds in this event yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('event_stat_rounds')), findsNothing);
  });

  testWidgets('Edit result opens the result dialog', (tester) async {
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [makeEvent(id: 9)]);

    await tester.tap(find.byKey(const ValueKey('event_detail_edit_result')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(EditEventResultDialog), findsOneWidget);
  });

  testWidgets('overflow -> Edit opens the edit dialog', (tester) async {
    await tester.pumpWidget(wrap(9));
    await emit(tester, events: [makeEvent(id: 9)]);

    await tester.tap(find.byKey(const ValueKey('event_detail_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(EditEventDialog), findsOneWidget);
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
    await emit(tester, events: [event]);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NewRoundDialog), findsOneWidget);
    // The embedded EventPicker shows the pre-selected event's title.
    expect(find.text('Club Championship (Season 1)'), findsWidgets);
  });
}
