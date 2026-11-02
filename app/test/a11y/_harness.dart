// Shared setup for the accessibility suite (#73): every top-level screen,
// seeded with enough data that each kind of widget it can show is on screen,
// pumped in the theme the app really ships, at a chosen brightness, text size
// and window size.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/app.dart';
import 'package:golfy_app/data/app_version.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/data/database_provider.dart';
import 'package:golfy_app/features/courses/course_setup_screen.dart';
import 'package:golfy_app/features/courses/courses_screen.dart';
import 'package:golfy_app/features/dashboard/dashboard_screen.dart';
import 'package:golfy_app/features/events/event_detail_screen.dart';
import 'package:golfy_app/features/events/events_screen.dart';
import 'package:golfy_app/features/hole_entry/hole_entry_screen.dart';
import 'package:golfy_app/features/rounds/active_round_provider.dart';
import 'package:golfy_app/features/rounds/new_round_dialog.dart';
import 'package:golfy_app/features/rounds/rounds_screen.dart';
import 'package:golfy_app/features/rounds/scorecard/scorecard_screen.dart';
import 'package:golfy_app/features/settings/settings_screen.dart';
import 'package:golfy_app/shell/app_drawer.dart';
import 'package:golfy_app/shell/app_shell.dart';

import '../dao/_fixtures.dart';

/// The ids [seedGolf] created.
class Seed {
  const Seed({
    required this.courseId,
    required this.eventId,
    required this.eventRoundId,
    required this.casualRoundId,
  });

  final int courseId;
  final int eventId;
  final int eventRoundId;
  final int casualRoundId;
}

/// A course with a tee set and a pin set, an event with a tied result, a round
/// in that event with a birdie, a par, a bogey and a double bogey (so every
/// score colour is on screen), and a casual round under par.
Future<Seed> seedGolf(TestFixtures fx) async {
  final courseId = await fx.insertCourse(
    name: 'Augusta National',
    gameTitle: 'PGA Tour 2K25',
  );
  await fx.insertCourseHoles(courseId);
  final tee = await fx.insertTeeSet(courseId);
  final pin = await fx.insertPinSet(courseId);
  await fx.insertCourseYards(tee);
  await fx.insertTeeToPinYards(tee, pin);

  final eventId = await fx.insertEvent(name: 'The Masters', season: 2);
  await fx.db.eventDao.setResult(eventId, finishPosition: 3, tied: true);

  final eventRoundId = await fx.insertRound(
    courseId,
    date: '2026-05-25',
    eventId: eventId,
    teeSetId: tee,
    pinSetId: pin,
  );
  await fx.upsertHole(eventRoundId, 1,
      par: 3, score: 2, putts: 1, fairwayHit: null);
  await fx.upsertHole(eventRoundId, 2);
  await fx.upsertHole(eventRoundId, 3, score: 5, gir: false, fairwayHit: false);
  await fx.upsertHole(eventRoundId, 4,
      par: 5, score: 7, gir: false, upDownAttempt: true);

  final casualRoundId = await fx.insertRound(courseId, date: '2026-05-20');
  await fx.upsertHole(casualRoundId, 1, score: 3, putts: 1);

  return Seed(
    courseId: courseId,
    eventId: eventId,
    eventRoundId: eventRoundId,
    casualRoundId: casualRoundId,
  );
}

/// What to pump for one screen, once its data is seeded.
class A11yTarget {
  const A11yTarget(
    this.home, {
    this.overrides = const [],
    this.prepare,
    this.interact,
  });

  final Widget home;

  /// Provider overrides beyond the database (e.g. Settings' app version).
  final List<Override> overrides;

  /// Runs on the container before the first pump (e.g. Hole Entry's active
  /// round).
  final void Function(ProviderContainer container)? prepare;

  /// Runs after the screen settles, to bring widgets on screen that only an
  /// interaction shows (e.g. a deletable shot on the hole card).
  final Future<void> Function(WidgetTester tester)? interact;
}

/// One screen the suite visits.
class A11yScreen {
  const A11yScreen(this.name, this.build);

  final String name;
  final Future<A11yTarget> Function(TestFixtures fx) build;
}

/// Every screen a user can reach, in the order of the core flow and then the
/// rest. A new screen belongs here.
final List<A11yScreen> a11yScreens = [
  A11yScreen('App shell', (fx) async {
    await seedGolf(fx);
    return const A11yTarget(AppShell());
  }),
  A11yScreen('Rounds', (fx) async {
    await seedGolf(fx);
    return const A11yTarget(RoundsScreen());
  }),
  A11yScreen('New round dialog', (fx) async {
    await seedGolf(fx);
    return const A11yTarget(
      Scaffold(body: NewRoundDialog(existingRounds: [])),
    );
  }),
  A11yScreen('Hole Entry', (fx) async {
    final seed = await seedGolf(fx);
    return A11yTarget(
      const HoleEntryScreen(),
      prepare: (c) =>
          c.read(activeRoundIdProvider.notifier).set(seed.casualRoundId),
      // Hole 2 is unsaved; an approach shot brings a deletable shot card,
      // with its lie, club and distance fields, on screen.
      interact: (tester) async {
        await tester.tap(find.byKey(const ValueKey('hole_chip_2')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('add_shot')).last);
        await tester.tap(find.byKey(const ValueKey('add_shot')).last);
        await tester.pumpAndSettle();
      },
    );
  }),
  A11yScreen('Scorecard', (fx) async {
    final seed = await seedGolf(fx);
    return A11yTarget(ScorecardScreen(roundId: seed.eventRoundId));
  }),
  A11yScreen('Dashboard', (fx) async {
    await seedGolf(fx);
    return const A11yTarget(DashboardScreen());
  }),
  A11yScreen('Events', (fx) async {
    await seedGolf(fx);
    return const A11yTarget(EventsScreen());
  }),
  A11yScreen('Event detail', (fx) async {
    final seed = await seedGolf(fx);
    return A11yTarget(EventDetailScreen(eventId: seed.eventId));
  }),
  A11yScreen('Courses', (fx) async {
    await seedGolf(fx);
    return const A11yTarget(CoursesScreen());
  }),
  A11yScreen('Course setup', (fx) async {
    final seed = await seedGolf(fx);
    return A11yTarget(CourseSetupScreen(courseId: seed.courseId));
  }),
  A11yScreen('Settings', (fx) async {
    await seedGolf(fx);
    return A11yTarget(
      const SettingsScreen(),
      overrides: [
        appVersionProvider.overrideWithValue(
          const AsyncData(AppVersion(version: '0.10.0', buildNumber: '51')),
        ),
      ],
    );
  }),
  A11yScreen('Drawer', (fx) async {
    return const A11yTarget(Scaffold(body: AppDrawer()));
  }),
];

/// A fresh in-memory database and its fixtures, closed after the test.
TestFixtures freshFixtures() {
  final db = GolfyDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return TestFixtures(db);
}

/// Seeds and pumps [screen] in the app's theme for [brightness], at
/// [textScale], in a window of [size] logical pixels, and lets its drift
/// streams deliver their first frame.
Future<void> pumpA11yScreen(
  WidgetTester tester,
  A11yScreen screen, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final fx = freshFixtures();
  final target = await screen.build(fx);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(fx.db),
      ...target.overrides,
    ],
  );
  addTearDown(container.dispose);
  target.prepare?.call(container);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: golfyTheme(brightness), home: target.home),
  ));
  await settle(tester);
  await target.interact?.call(tester);
}

/// Lets the drift streams deliver, then settles the frame. Twice, because the
/// Hole Entry screen's streams depend on one another.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }
}
