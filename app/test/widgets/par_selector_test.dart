import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/widgets/par_selector.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int value,
    required ValueChanged<int> onChanged,
    String labelText = 'Par',
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ParSelector(
          value: value,
          onChanged: onChanged,
          labelText: labelText,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('offers 3, 4 and 5 as a segmented button', (tester) async {
    await pump(tester, value: 4, onChanged: (_) {});

    // A segmented button, not a dropdown: all three options are visible at once
    // (the split this widget exists to remove — #81).
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('marks the current par as selected', (tester) async {
    await pump(tester, value: 5, onChanged: (_) {});

    final segmented =
        tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>));
    expect(segmented.selected, {5});
  });

  testWidgets('reports the tapped par', (tester) async {
    int? picked;
    await pump(tester, value: 4, onChanged: (v) => picked = v);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(picked, 3);
  });

  testWidgets('renders the supplied label', (tester) async {
    await pump(tester, value: 4, onChanged: (_) {}, labelText: 'Hole par');
    expect(find.text('Hole par'), findsOneWidget);
  });
}
