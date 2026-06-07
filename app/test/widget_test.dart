import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golfy_app/app.dart';

void main() {
  testWidgets('App shell shows the 3-tab bottom navigation bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GolfyApp()));
    // The Rounds screen now subscribes to a live drift stream, so we can't
    // use pumpAndSettle here — a single bounded pump is enough to render
    // the bottom nav bar, which is what this smoke test cares about. Per-
    // screen behavior is covered in feature/* test files.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Rounds'), findsWidgets);
    expect(find.text('Hole Entry'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
  });
}
