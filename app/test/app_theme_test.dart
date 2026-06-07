import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golfy_app/app.dart';
import 'package:golfy_app/shell/app_shell.dart';

void main() {
  // Pumping GolfyApp mounts the real Rounds screen and its live drift stream,
  // so we use a single bounded pump (never pumpAndSettle) — the same approach
  // as widget_test.dart. We only need the first frame to read the theme.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GolfyApp()));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('wires up a light + dark theme driven by the system setting',
      (tester) async {
    await pumpApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    expect(app.theme!.brightness, Brightness.light);
    expect(app.darkTheme!.brightness, Brightness.dark);
  });

  testWidgets('renders the light scheme when the platform is light',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final context = tester.element(find.byType(AppShell));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('renders the dark scheme when the platform is dark',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    final context = tester.element(find.byType(AppShell));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
