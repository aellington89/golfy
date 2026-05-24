import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:golfy_app/app.dart';

void main() {
  testWidgets('App shell shows 3 tabs and renders the Rounds screen by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GolfyApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Rounds'), findsWidgets);
    expect(find.text('Hole Entry'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('List of rounds will appear here.'), findsOneWidget);
  });
}
