import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';
import 'package:golfy_app/features/rounds/scorecard/hole_scorecard_card.dart';

HoleResult hole({
  int par = 4,
  int score = 4,
  bool? fairwayHit = true,
  bool gir = true,
  int putts = 2,
  bool upDownAttempt = false,
  bool upDownSuccess = false,
}) {
  return HoleResult(
    id: 1,
    roundId: 1,
    holeNumber: 4,
    par: par,
    score: score,
    yards: 400,
    fairwayHit: fairwayHit,
    gir: gir,
    putts: putts,
    upDownAttempt: upDownAttempt,
    upDownSuccess: upDownSuccess,
    penaltyStrokes: 0,
    bunkerVisited: false,
    sandSave: false,
  );
}

void main() {
  // #73: the row's cells ("FW ✓", "U/D —") read as letters and symbol names,
  // so a screen reader gets one sentence instead.
  group('spokenHoleSummary', () {
    test('a hole not entered yet', () {
      expect(spokenHoleSummary(4, null), 'Hole 4, not entered.');
    });

    test('a bogey reads its name and its score to par', () {
      expect(
        spokenHoleSummary(4, hole(score: 5, fairwayHit: false, gir: false)),
        'Hole 4, par 4. Score 5, bogey, 1 over par. Fairway missed. '
        'Green in regulation missed. 2 putts. No up and down.',
      );
    });

    test('a par says even par once, not "par, even par"', () {
      expect(
        spokenHoleSummary(4, hole()),
        'Hole 4, par 4. Score 4, even par. Fairway hit. '
        'Green in regulation. 2 putts. No up and down.',
      );
    });

    test('a par 3 leaves the fairway out, as the card shows N/A', () {
      expect(
        spokenHoleSummary(4, hole(par: 3, score: 2, fairwayHit: null, putts: 1)),
        'Hole 4, par 3. Score 2, birdie, 1 under par. '
        'Green in regulation. 1 putt. No up and down.',
      );
    });

    test('an unrecorded fairway on a par 4 says so', () {
      expect(
        spokenHoleSummary(4, hole(fairwayHit: null)),
        contains('Fairway not recorded.'),
      );
    });

    test('an up and down made or missed', () {
      expect(
        spokenHoleSummary(
          4,
          hole(gir: false, putts: 1, upDownAttempt: true, upDownSuccess: true),
        ),
        contains('Up and down made.'),
      );
      expect(
        spokenHoleSummary(4, hole(gir: false, upDownAttempt: true)),
        contains('Up and down missed.'),
      );
    });

    test('past quadruple bogey there is no name, only the number', () {
      expect(
        spokenHoleSummary(4, hole(score: 9, gir: false)),
        contains('Score 9, 5 over par.'),
      );
    });
  });

  testWidgets('the card is one screen-reader item carrying the summary',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final result = hole(score: 5, fairwayHit: false, gir: false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HoleScorecardCard(
          key: const ValueKey('card'),
          holeNumber: 4,
          result: result,
        ),
      ),
    ));

    expect(
      tester.getSemantics(find.byKey(const ValueKey('card'))),
      matchesSemantics(label: spokenHoleSummary(4, result)),
    );
    // The cells themselves are not read on their own.
    expect(find.bySemanticsLabel('FW'), findsNothing);
    expect(find.bySemanticsLabel('✗'), findsNothing);
    semantics.dispose();
  });
}
