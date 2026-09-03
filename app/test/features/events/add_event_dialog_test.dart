import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/events/add_event_dialog.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap({
    List<Event> existing = const [],
    void Function(Event?)? onResult,
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<Event>(
                      context: context,
                      builder: (_) => AddEventDialog(existingEvents: existing),
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

  // Bounded pump — a focused TextFormField keeps the cursor-blink animation
  // running indefinitely, so pumpAndSettle would hang.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  Future<void> openDialog(
    WidgetTester tester, {
    List<Event> existing = const [],
    void Function(Event?)? onResult,
  }) async {
    await tester.pumpWidget(wrap(existing: existing, onResult: onResult));
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  testWidgets('empty name shows validation error and does not insert',
      (tester) async {
    await openDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(find.byType(AddEventDialog), findsOneWidget);

    final rows = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(rows, isEmpty);
  });

  testWidgets(
      'duplicate name + season (case-insensitive) shows error and does not '
      'insert again', (tester) async {
    const existing = [
      Event(
        id: 1,
        name: 'Club Championship',
        season: 1,
        tied: false,
        missedCut: false,
      ),
    ];
    await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );

    await openDialog(tester, existing: existing);

    // Different casing still collides — that's the whole point of the picker.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'club championship',
    );
    await settle(tester);
    // Typing an existing name auto-advances the season to the next unused one
    // (2); type the taken season 1 back in to force the collision.
    await tester.enterText(find.widgetWithText(TextFormField, 'Season'), '1');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Season 1 already exists'), findsOneWidget);
    expect(find.byType(AddEventDialog), findsOneWidget);

    final rows = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(rows, hasLength(1));
  });

  testWidgets(
      'typing an existing name auto-suggests the next season and inserts it '
      '(#47)', (tester) async {
    const existing = [
      Event(
        id: 1,
        name: 'Club Championship',
        season: 1,
        tied: false,
        missedCut: false,
      ),
    ];
    await db.eventDao.insert(
      EventsCompanion.insert(name: 'Club Championship'),
    );

    Event? popped;
    await openDialog(tester, existing: existing, onResult: (e) => popped = e);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'Club Championship',
    );
    await settle(tester);
    // The season auto-advanced to 2 (next unused for this name).
    expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(popped, isNotNull);
    expect(popped!.name, 'Club Championship');
    expect(popped!.season, 2);

    final rows = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(
      rows!.map((e) => (e.name, e.season)).toList(),
      [('Club Championship', 1), ('Club Championship', 2)],
    );
  });

  testWidgets('valid input inserts a season-1 row and pops with the new Event',
      (tester) async {
    Event? popped;
    await openDialog(tester, onResult: (e) => popped = e);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'Club Championship',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.byType(AddEventDialog), findsNothing);
    expect(popped, isNotNull);
    expect(popped!.name, 'Club Championship');
    expect(popped!.season, 1);

    final rows = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(rows!.map((e) => (e.name, e.season)).toList(),
        [('Club Championship', 1)]);
  });

  testWidgets('a non-positive / non-numeric season is rejected (#47)',
      (tester) async {
    await openDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'Club Championship',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Season'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(find.text('Enter a season of 1 or more'), findsOneWidget);
    expect(find.byType(AddEventDialog), findsOneWidget);

    final rows = await tester.runAsync(() => db.eventDao.watchAll().first);
    expect(rows, isEmpty);
  });
}
