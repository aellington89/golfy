import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/events/add_event_dialog.dart';
import 'package:golfy_app/features/events/event_picker.dart';

void main() {
  late GolfyDatabase db;
  // Stream backing [eventsStreamProvider] in tests. A manual controller (rather
  // than drift's stream) keeps flutter_test's fake clock happy — drift's stream
  // leaves a pending timer that fails the !timersPending invariant. Mirrors
  // course_picker_test.dart.
  late StreamController<List<Event>> eventsController;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
    eventsController = StreamController<List<Event>>.broadcast();
  });

  tearDown(() async {
    await eventsController.close();
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        eventsStreamProvider.overrideWith((ref) => eventsController.stream),
      ],
      child: const MaterialApp(home: _Holder()),
    );
  }

  Future<void> emit(WidgetTester tester, List<Event> events) async {
    eventsController.add(events);
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  Event event(int id, String name, {int season = 1}) =>
      Event(id: id, name: name, season: season, tied: false, missedCut: false);

  testWidgets('opens sheet and lists events sorted alphabetically by name',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, [
      event(1, 'Autumn Open'),
      event(2, 'Club Championship'),
      event(3, 'Spring Scramble'),
    ]);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    final tiles = find.byType(ListTile);
    // 1 "No event" clear row + 3 events + 1 "Add new event…".
    expect(tiles, findsNWidgets(5));

    final titles = tester
        .widgetList<ListTile>(tiles)
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles, [
      'No event / Casual round',
      'Autumn Open (Season 1)',
      'Club Championship (Season 1)',
      'Spring Scramble (Season 1)',
      'Add new event…',
    ]);
  });

  testWidgets('selecting an event updates the field', (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, [event(1, 'Club Championship')]);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Club Championship (Season 1)'));
    await tester.pumpAndSettle();

    // Field now shows the selected event name, not the casual placeholder.
    expect(find.text('Club Championship (Season 1)'), findsOneWidget);
    expect(find.text('No event (casual round)'), findsNothing);
  });

  testWidgets('selecting "No event / Casual round" clears the selection',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, [event(1, 'Club Championship')]);

    // Select an event first…
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Club Championship (Season 1)'));
    await tester.pumpAndSettle();
    expect(find.text('Club Championship (Season 1)'), findsOneWidget);

    // …then clear it back to casual via the "No event" row.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'No event / Casual round'));
    await tester.pumpAndSettle();

    expect(find.text('No event (casual round)'), findsOneWidget);
    expect(find.text('Club Championship (Season 1)'), findsNothing);
  });

  testWidgets('checkmark tracks the selected event (and "No event" when null)',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, [event(1, 'Autumn Open'), event(2, 'Club Championship')]);

    ListTile tileWithTitle(String title) =>
        tester.widget(find.widgetWithText(ListTile, title));

    // Nothing selected → the check sits on the "No event" row.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(tileWithTitle('No event / Casual round').trailing, isA<Icon>());
    expect(tileWithTitle('Club Championship (Season 1)').trailing, isNull);

    // Pick an event, reopen → the check moves to it and off "No event".
    await tester.tap(find.widgetWithText(ListTile, 'Club Championship (Season 1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(tileWithTitle('Club Championship (Season 1)').trailing, isA<Icon>());
    expect(tileWithTitle('No event / Casual round').trailing, isNull);
  });

  testWidgets(
      'selecting "Add new event…" opens dialog and selects the new event',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, const []);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Add new event…'));
    await tester.pumpAndSettle();

    expect(find.byType(AddEventDialog), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'Club Championship',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    // The insert future runs as real async; flush it before pumping frames.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    await settle(tester);

    expect(find.byType(AddEventDialog), findsNothing);
    // Picker label now shows the newly-added event as the selected value.
    expect(find.text('Club Championship (Season 1)'), findsOneWidget);

    // Event landed in the real db too.
    final rows = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(rows!.map((e) => e.name).toList(), ['Club Championship']);
  });

  testWidgets('reactively reflects new events emitted while mounted',
      (tester) async {
    await tester.pumpWidget(wrap());
    await emit(tester, const []);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Club Championship (Season 1)'), findsNothing);

    // Close the sheet, emit a new list, reopen.
    Navigator.of(tester.element(find.text('Add new event…'))).pop();
    await tester.pumpAndSettle();

    await emit(tester, [event(1, 'Club Championship')]);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Club Championship (Season 1)'), findsOneWidget);
  });
}

class _Holder extends StatefulWidget {
  const _Holder();

  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  Event? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: EventPicker(
          value: _selected,
          onChanged: (e) => setState(() => _selected = e),
        ),
      ),
    );
  }
}
