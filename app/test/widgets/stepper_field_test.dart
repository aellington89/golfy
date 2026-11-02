import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/widgets/stepper_field.dart';

void main() {
  /// A stepper over a real counter, floored at [min].
  Future<ValueNotifier<int>> pump(
    WidgetTester tester, {
    int start = 4,
    int min = 1,
  }) async {
    final value = ValueNotifier(start);
    addTearDown(value.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: value,
          builder: (_, v, _) => StepperField(
            label: 'Score',
            value: v,
            decreaseKey: const ValueKey('dec'),
            increaseKey: const ValueKey('inc'),
            onDecrease: v <= min ? null : () => value.value--,
            onIncrease: () => value.value++,
          ),
        ),
      ),
    ));
    return value;
  }

  testWidgets('the buttons step the value and say what they do',
      (tester) async {
    final value = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('inc')));
    await tester.pump();
    expect(value.value, 5);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dec')));
    await tester.pump();
    expect(value.value, 4);

    expect(find.byTooltip('Increase score'), findsOneWidget);
    expect(find.byTooltip('Decrease score'), findsOneWidget);
  });

  // #73: the number is one item with its name, adjustable with TalkBack's
  // swipe up / down, and a live region so a change is announced.
  testWidgets('the value is a named, adjustable live region', (tester) async {
    final semantics = tester.ensureSemantics();
    final value = await pump(tester);

    final node = find.semantics.byLabel('Score');
    expect(
      tester.getSemantics(find.text('4')),
      isSemantics(
        label: 'Score',
        value: '4',
        increasedValue: '5',
        decreasedValue: '3',
        isLiveRegion: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );

    tester.semantics.increase(node);
    await tester.pump();
    expect(value.value, 5);

    tester.semantics.decrease(node);
    await tester.pump();
    expect(value.value, 4);
    semantics.dispose();
  });

  testWidgets('at the floor, decrease is gone from the button and the node',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, start: 1);

    expect(
      tester.widget<IconButton>(find.byKey(const ValueKey('dec'))).onPressed,
      isNull,
    );
    final SemanticsNode node = tester.getSemantics(find.text('1'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    semantics.dispose();
  });
}
