import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/events/edit_event_result_dialog.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap(Event event) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => EditEventResultDialog(event: event),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, Event event) async {
    await tester.pumpWidget(wrap(event));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('event_result_save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('saving a finishing position persists it', (tester) async {
    final id = await db.eventDao.insert(EventsCompanion.insert(name: 'Major'));
    final event = (await db.eventDao.getById(id))!;

    await open(tester, event);
    await tester.enterText(
      find.byKey(const ValueKey('event_position_field')),
      '2',
    );
    await tapSave(tester);

    final saved = await tester.runAsync(() => db.eventDao.getById(id));
    expect(saved!.finishPosition, 2);
    expect(saved.tied, isFalse);
    expect(saved.missedCut, isFalse);
  });

  testWidgets('missed cut disables the position field and saves a cut',
      (tester) async {
    final id = await db.eventDao.insert(EventsCompanion.insert(name: 'Major'));
    final event = (await db.eventDao.getById(id))!;

    await open(tester, event);
    await tester.tap(find.byKey(const ValueKey('event_missed_cut_switch')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('event_position_field')),
    );
    expect(field.enabled, isFalse);

    await tapSave(tester);

    final saved = await tester.runAsync(() => db.eventDao.getById(id));
    expect(saved!.missedCut, isTrue);
    expect(saved.finishPosition, isNull);
  });

  testWidgets('pre-fills from an already-recorded result', (tester) async {
    final id = await db.eventDao.insert(EventsCompanion.insert(name: 'Major'));
    await db.eventDao.setResult(id, finishPosition: 3, tied: true);
    final event = (await db.eventDao.getById(id))!;

    await open(tester, event);

    expect(find.text('3'), findsOneWidget); // position field pre-filled
    final tiedSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('event_tied_switch')),
    );
    expect(tiedSwitch.value, isTrue);
  });
}
