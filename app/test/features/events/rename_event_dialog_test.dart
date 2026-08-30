import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/events/rename_event_dialog.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Event ev(int id, String name) =>
      Event(id: id, name: name, tied: false, missedCut: false);

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
                      builder: (_) => RenameEventDialog(
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

  testWidgets('empty name shows a validation error and does not rename',
      (tester) async {
    final id =
        await db.eventDao.insert(EventsCompanion.insert(name: 'Original'));
    await openDialog(tester, event: ev(id, 'Original'));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('rename_event_save')));
    await settle(tester);

    expect(find.text('Required'), findsOneWidget);
    expect(find.byType(RenameEventDialog), findsOneWidget);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.name, 'Original');
  });

  testWidgets(
      'duplicate name (case-insensitive, excluding self) shows an error',
      (tester) async {
    final id =
        await db.eventDao.insert(EventsCompanion.insert(name: 'Original'));
    await db.eventDao.insert(EventsCompanion.insert(name: 'Major'));
    final existing = [ev(id, 'Original'), ev(2, 'Major')];

    await openDialog(tester, event: ev(id, 'Original'), existing: existing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'major',
    );
    await tester.tap(find.byKey(const ValueKey('rename_event_save')));
    await settle(tester);

    expect(find.text('Event already exists'), findsOneWidget);
    expect(find.byType(RenameEventDialog), findsOneWidget);
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.name, 'Original');
  });

  testWidgets('valid rename persists and pops with the updated Event',
      (tester) async {
    Event? popped;
    final id =
        await db.eventDao.insert(EventsCompanion.insert(name: 'Original'));
    await openDialog(
      tester,
      event: ev(id, 'Original'),
      onResult: (e) => popped = e,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Event Name'),
      'Renamed',
    );
    await tester.tap(find.byKey(const ValueKey('rename_event_save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);

    expect(find.byType(RenameEventDialog), findsNothing);
    expect(popped, isNotNull);
    expect(popped!.name, 'Renamed');
    final row = await tester.runAsync(() => db.eventDao.getById(id));
    expect(row!.name, 'Renamed');
  });

  testWidgets('renaming to the same name is a no-op that just closes',
      (tester) async {
    Event? popped;
    final id =
        await db.eventDao.insert(EventsCompanion.insert(name: 'Original'));
    await openDialog(
      tester,
      event: ev(id, 'Original'),
      onResult: (e) => popped = e,
    );

    await tester.tap(find.byKey(const ValueKey('rename_event_save')));
    await settle(tester);

    expect(find.byType(RenameEventDialog), findsNothing);
    expect(popped, isNotNull);
    expect(popped!.name, 'Original');
  });
}
