import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/widgets/empty_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders the icon and message', (tester) async {
    await tester.pumpWidget(wrap(
      const EmptyState(
        icon: Icons.golf_course_outlined,
        message: 'Nothing here yet.',
      ),
    ));

    expect(find.byIcon(Icons.golf_course_outlined), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('renders and wires up an action when one is supplied',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      EmptyState(
        icon: Icons.flag_outlined,
        message: 'No active round.',
        action: FilledButton(
          onPressed: () => tapped = true,
          child: const Text('Go'),
        ),
      ),
    ));

    expect(find.widgetWithText(FilledButton, 'Go'), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(tapped, isTrue);
  });

  testWidgets('omits the action area when none is supplied', (tester) async {
    await tester.pumpWidget(wrap(
      const EmptyState(
        icon: Icons.insights_outlined,
        message: 'No stats.',
      ),
    ));

    expect(find.byType(FilledButton), findsNothing);
  });
}
