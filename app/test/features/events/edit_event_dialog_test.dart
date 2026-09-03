import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/events/edit_event_dialog.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Event ev(int id, String name, {int season = 1}) =>
      Event(id: id, name: name, season: season, tied: false, missedCut: false);

  Widget wrap({
    required Event event,
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
                      builder: (_) => EditEventDialog(
                        event: event,
                        existingEvents: existing,
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

  // Bounded pump — entering text focuses the field, whose cursor-blink keeps
  // pumpAndSettle from ever settling.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  Future<void> openDialog(
    WidgetTester tester, {
    required Event event,
    List<Event> existing = const [],
    void Function(Event?)? onResult,
  }) async {
    await tester.pumpWidget(
      wrap(event: event, existing: existing, onResult: onResult),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
  }

  Future<int> seed(String name, {int season = 1}) => db.eventDao
      .insert(EventsCompanion.insert(name: name, season: Value(season)));

  testWidgets('empty name shows a validation error and does not save',
      (tester) async {
    final id = await seed('Original');
    await openDialog(tester, event: ev(id, 'Original'));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('edit_event_save')));
    await settle(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(find.byType(EditEventDialog), findsOneWidget);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.name, 'Original');
  });

  testWidgets('a non-positive season shows a validation error and does not save',
      (tester) async {
    final id = await seed('Original');
    await openDialog(tester, event: ev(id, 'Original'));

    await tester.enterText(find.widgetWithText(TextFormField, 'Season'), '0');
    await tester.tap(find.byKey(const ValueKey('edit_event_save')));
    await settle(tester);

    expect(find.text('Enter a season of 1 or more'), findsOneWidget);
    expect(find.byType(EditEventDialog), findsOneWidget);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.season, 1);
  });

  testWidgets(
      'renaming onto an existing (name, season) (case-insensitive, excluding '
      'self) shows an error', (tester) async {
    final id = await seed('Original');
    await seed('Major');
    final existing = [ev(id, 'Original'), ev(2, 'Major')];

    await openDialog(tester, event: ev(id, 'Original'), existing: existing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'major',
    );
    await tester.tap(find.byKey(const ValueKey('edit_event_save')));
    await settle(tester);

    expect(find.text('Season 1 already exists'), findsOneWidget);
    expect(find.byType(EditEventDialog), findsOneWidget);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.name, 'Original');
  });

  testWidgets('changing the season onto an existing occurrence shows an error',
      (tester) async {
    final id = await seed('Major');
    await seed('Major', season: 2);
    final existing = [ev(id, 'Major'), ev(2, 'Major', season: 2)];

    await openDialog(tester, event: ev(id, 'Major'), existing: existing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Season'), '2');
    await tester.tap(find.byKey(const ValueKey('edit_event_save')));
    await settle(tester);

    expect(find.text('Season 2 already exists'), findsOneWidget);
    expect(find.byType(EditEventDialog), findsOneWidget);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.season, 1);
  });

  testWidgets('valid rename persists and pops with the updated Event',
      (tester) async {
    Event? popped;
    final id = await seed('Original');
    await openDialog(
      tester,
      event: ev(id, 'Original'),
      onResult: (e) => popped = e,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'Renamed',
    );
    await tester.tap(find.byKey(const ValueKey('edit_event_save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    expect(find.byType(EditEventDialog), findsNothing);
    expect(popped, isNotNull);
    expect(popped!.name, 'Renamed');
    expect(popped!.season, 1);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.name, 'Renamed');
    expect(row.season, 1);
  });

  testWidgets('editing the season persists and pops with the updated Event (#47)',
      (tester) async {
    Event? popped;
    final id = await seed('Club Championship');
    await openDialog(
      tester,
      event: ev(id, 'Club Championship'),
      onResult: (e) => popped = e,
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Season'), '3');
    await tester.tap(find.byKey(const ValueKey('edit_event_save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    expect(find.byType(EditEventDialog), findsNothing);
    expect(popped, isNotNull);
    expect(popped!.name, 'Club Championship');
    expect(popped!.season, 3);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.season, 3);
  });

  testWidgets('no change (same name and season) is a no-op that just closes',
      (tester) async {
    Event? popped;
    final id = await seed('Original');
    await openDialog(
      tester,
      event: ev(id, 'Original'),
      onResult: (e) => popped = e,
    );

    await tester.tap(find.byKey(const ValueKey('edit_event_save')));
    await settle(tester);

    expect(find.byType(EditEventDialog), findsNothing);
    expect(popped, isNotNull);
    expect(popped!.name, 'Original');
    expect(popped!.season, 1);
  });
}
