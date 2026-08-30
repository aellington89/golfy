import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/events/add_event_dialog.dart';
import 'package:golfy_app/features/events/event_detail_screen.dart';
import 'package:golfy_app/features/events/events_screen.dart';

void main() {
  late GolfyDatabase db;
  late StreamController<List<Event>> eventsController;
  late StreamController<List<RoundWithCourse>> roundsController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    eventsController = StreamController<List<Event>>.broadcast();
    roundsController = StreamController<List<RoundWithCourse>>.broadcast();
  });

  tearDown(() async {
    await eventsController.close();
    await roundsController.close();
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        eventsStreamProvider.overrideWith((ref) => eventsController.stream),
        roundsStreamProvider.overrideWith((ref) => roundsController.stream),
      ],
      child: const MaterialApp(home: EventsScreen()),
    );
  }

  Event makeEvent({
    int id = 1,
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

  RoundWithCourse makeRound({required int id, required Event event}) {
    return RoundWithCourse(
      round: Round(
        id: id,
        date: '2026-05-25',
        courseId: 1,
        roundNumber: 1,
        eventId: event.id,
      ),
      courseName: 'Pebble',
      event: event,
      holesEntered: 0,
      totalScore: 0,
      totalPar: 0,
    );
  }

  Future<void> emit(
    WidgetTester tester, {
    List<Event> events = const [],
    List<RoundWithCourse> rounds = const [],
  }) async {
    eventsController.add(events);
    roundsController.add(rounds);
    await tester.pumpAndSettle();
  }

  testWidgets('empty state when there are no events', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester);

    expect(find.text('No events yet. Tap + to create one.'), findsOneWidget);
  });

  testWidgets('lists an event with its result badge and round count',
      (tester) async {
    final event = makeEvent(id: 9, name: 'Club Championship', finishPosition: 1);
    await tester.pumpWidget(wrap());
    await emit(
      tester,
      events: [event],
      rounds: [makeRound(id: 1, event: event), makeRound(id: 2, event: event)],
    );

    expect(find.text('Club Championship'), findsOneWidget);
    expect(find.byKey(const ValueKey('event_result_badge_9')), findsOneWidget);
    expect(find.text('1st'), findsOneWidget);
    expect(find.text('2 rounds'), findsOneWidget);
  });

  testWidgets('an event with no rounds reads "No rounds yet"', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, events: [makeEvent(id: 9, name: 'Empty Event')]);

    expect(find.text('No rounds yet'), findsOneWidget);
  });

  testWidgets('FAB opens the Add Event dialog', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AddEventDialog), findsOneWidget);
  });

  testWidgets('tapping an event opens its detail screen', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, events: [makeEvent(id: 9, name: 'Club Championship')]);

    await tester.tap(find.byKey(const ValueKey('event_tile_9')));
    // The pushed detail screen's own streams stay in loading (broadcast streams
    // don't replay), so bounded-pump the route transition rather than settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(EventDetailScreen), findsOneWidget);
  });
}
