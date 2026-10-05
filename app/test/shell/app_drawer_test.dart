import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/data/models/round_with_course.dart';
import 'package:golfy_app/data/repository_provider.dart';
import 'package:golfy_app/features/courses/courses_screen.dart';
import 'package:golfy_app/features/settings/settings_screen.dart';
import 'package:golfy_app/shell/app_drawer.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // The pushed screens watch these; feed single-value streams so none of
        // them opens a live drift watch on the test db.
        coursesByNameStreamProvider
            .overrideWith((ref) => Stream.value(const <Course>[])),
        roundsStreamProvider
            .overrideWith((ref) => Stream.value(const <RoundWithCourse>[])),
        // SettingsScreen's backup tile counts these (#69).
        coursesStreamProvider
            .overrideWith((ref) => Stream.value(const <Course>[])),
        eventsStreamProvider
            .overrideWith((ref) => Stream.value(const <Event>[])),
      ],
      child: MaterialApp(
        home: Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(title: const Text('Home')),
          body: const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('drawer has a Courses entry that opens the courses screen',
      (tester) async {
    await tester.pumpWidget(wrap());

    // Open the drawer via the AppBar hamburger.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('drawer_courses')), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer_courses')));
    await tester.pumpAndSettle();

    // Landed on the courses management screen (empty here).
    expect(find.byType(CoursesScreen), findsOneWidget);
    expect(find.text('No courses yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('drawer has a Settings entry that opens the settings screen',
      (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('drawer_settings')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer_settings')));
    await tester.pumpAndSettle();

    // Landed on Settings, which is where the backup action lives (#69).
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Back up your data'), findsOneWidget);
  });
}
