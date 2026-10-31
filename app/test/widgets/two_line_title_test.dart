import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/widgets/two_line_title.dart';

void main() {
  Future<void> pump(WidgetTester tester, {double textScale = 1.0}) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            toolbarHeight: TwoLineTitle.toolbarHeight(context),
            title: const TwoLineTitle(
              title: 'Augusta National',
              subtitle: 'May 25, 2026',
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('keeps the standard toolbar height at the default text size',
      (tester) async {
    await pump(tester);

    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });

  // #73: a 56 dp toolbar clipped the second line at a large text size.
  testWidgets('grows the toolbar so both lines fit at 2× text',
      (tester) async {
    await pump(tester, textScale: 2.0);

    final bar = tester.getRect(find.byType(AppBar));
    expect(bar.height, greaterThan(kToolbarHeight));
    expect(tester.getRect(find.text('Augusta National')).top,
        greaterThanOrEqualTo(bar.top));
    expect(tester.getRect(find.text('May 25, 2026')).bottom,
        lessThanOrEqualTo(bar.bottom));
  });
}
