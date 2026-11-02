import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/hole_entry/hole_card.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';
import 'package:golfy_app/features/hole_entry/hole_rules.dart';

/// Stateful test harness that holds a [HoleDraft] and rebuilds when
/// [HoleCard.onChanged] fires — mirrors the real screen's ownership model.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.initial,
    this.savedDraft,
    this.onSave,
    this.yardageSetName,
    this.strokeIndex,
    this.onStrokeIndexChanged,
    this.strokeIndexClashWith,
  });

  final HoleDraft initial;
  final HoleDraft? savedDraft;
  final VoidCallback? onSave;
  final String? yardageSetName;
  final int? strokeIndex;
  final ValueChanged<int?>? onStrokeIndexChanged;
  final int? strokeIndexClashWith;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late HoleDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  HoleDraft get draft => _draft;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: HoleCard(
          holeNumber: 1,
          draft: _draft,
          savedDraft: widget.savedDraft,
          yardageSetName: widget.yardageSetName,
          strokeIndex: widget.strokeIndex,
          onStrokeIndexChanged: widget.onStrokeIndexChanged,
          strokeIndexClashWith: widget.strokeIndexClashWith,
          onChanged: (d) => setState(() => _draft = d),
          onSave: widget.onSave ?? () {},
        ),
      ),
    );
  }
}

// ignore: library_private_types_in_public_api
Future<_HarnessState> pumpCard(
  WidgetTester tester, {
  required HoleDraft initial,
  HoleDraft? savedDraft,
  VoidCallback? onSave,
  String? yardageSetName,
  int? strokeIndex,
  ValueChanged<int?>? onStrokeIndexChanged,
  int? strokeIndexClashWith,
}) async {
  // Default 800x600 test surface is shorter than the form. Resize so every
  // row — shot cards included — is on-screen and tappable.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_Harness(
    initial: initial,
    savedDraft: savedDraft,
    onSave: onSave,
    yardageSetName: yardageSetName,
    strokeIndex: strokeIndex,
    onStrokeIndexChanged: onStrokeIndexChanged,
    strokeIndexClashWith: strokeIndexClashWith,
  ));
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// Taps the par segment [label] ("3" / "4" / "5"). Required because
/// [find.widgetWithText] returns the whole segmented button (its center sits
/// on the middle segment), which means tapping it picks the wrong option.
Future<void> tapPar(WidgetTester tester, String label) async {
  final par = find.byType(SegmentedButton<int>).first;
  await tester.tap(find.descendant(of: par, matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Answers the tee shot's "Fairway hit?" / "Green hit?" with Yes or No.
Future<void> answerTee(WidgetTester tester, {required bool hit}) async {
  await tester.tap(find.descendant(
    of: find.byKey(const ValueKey('tee_result')),
    matching: find.text(hit ? 'Yes' : 'No'),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// Picks [option] from the dropdown keyed [key].
Future<void> pick(WidgetTester tester, String key, String option) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// What the dropdown keyed [key] is currently *displaying* — as opposed to
/// what the draft holds. Distinguishing the two is the point of the
/// stale-dropdown regression test.
String? shown(WidgetTester tester, String key) => tester
    .widget<DropdownButton<String?>>(find.byKey(ValueKey(key)))
    .value;

String distanceShown(WidgetTester tester, int index) => tester
    .widget<TextField>(find.byKey(ValueKey('shot_distance_$index')))
    .controller!
    .text;

String puttDistanceShown(WidgetTester tester, int index) => tester
    .widget<TextField>(find.byKey(ValueKey('putt_distance_$index')))
    .controller!
    .text;

/// [n] putts with nothing entered about them.
List<ShotDraft> putts(int n) => List.filled(n, const ShotDraft.putt());

SwitchListTile switchTile(WidgetTester tester, String label) =>
    tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label));

double dy(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

/// A par 4 whose tee shot has been answered "fairway hit" — the simplest
/// hole that can be saved: tee, fairway, one putt.
HoleDraft answeredPar4({int yards = 420}) =>
    answerTeeShot(HoleDraft.initial(par: 4, yards: yards), true);

void main() {
  group('HoleCard — the tee shot result', () {
    testWidgets('a par 4 asks about the fairway, with nothing pre-selected',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());

      expect(find.text('Fairway hit?'), findsOneWidget);
      final result = tester.widget<SegmentedButton<bool>>(
          find.byKey(const ValueKey('tee_result')));
      expect(result.selected, isEmpty);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('a par 3 asks about the green instead, and that is GIR',
        (tester) async {
      final state = await pumpCard(tester, initial: HoleDraft.initial(par: 3));

      expect(find.text('Green hit?'), findsOneWidget);
      expect(find.text('Fairway hit?'), findsNothing);
      // GIR on a par 3 *is* this answer, so there's no separate switch.
      expect(find.widgetWithText(SwitchListTile, 'GIR'), findsNothing);

      await answerTee(tester, hit: true);
      expect(state.draft.gir, isTrue);
      expect(state.draft.fairwayHit, isNull);
    });

    testWidgets('switching from par 4 to par 3 clears the fairway answer',
        (tester) async {
      final state = await pumpCard(tester, initial: HoleDraft.initial());
      await answerTee(tester, hit: true);
      expect(state.draft.fairwayHit, isTrue);

      await tapPar(tester, '3');

      expect(state.draft.par, 3);
      expect(state.draft.fairwayHit, isNull);
      expect(find.text('Green hit?'), findsOneWidget);
    });

    testWidgets('Save Hole will not save until it is answered',
        (tester) async {
      var saves = 0;
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        onSave: () => saves++,
      );
      // Before a save is tried, it reads as a to-do rather than an error.
      expect(find.text('Before saving'), findsOneWidget);
      expect(find.text('Required before saving'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
      await tester.pumpAndSettle();

      expect(saves, 0);
      expect(find.text("Can't save yet"), findsOneWidget);
      expect(find.text('Required before saving'), findsOneWidget);
      expect(find.textContaining("Can't save yet."), findsOneWidget,
          reason: 'the snackbar says why');

      await answerTee(tester, hit: false);
      expect(find.byKey(const ValueKey('hole_errors')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
      await tester.pumpAndSettle();

      expect(saves, 1);
      expect(state.draft.fairwayHit, isFalse);
    });
  });

  group('HoleCard — shots live in their sections', () {
    testWidgets('sections run hole → tee shot → approach → putting → score',
        (tester) async {
      await pumpCard(tester, initial: answeredPar4());

      final hole = dy(tester, find.text('Hole'));
      final tee = dy(tester, find.text('Tee shot'));
      final teeShot = dy(tester, find.byKey(const ValueKey('shot_row_0')));
      final teeResult = dy(tester, find.byKey(const ValueKey('tee_result')));
      final approach = dy(tester, find.text('Approach & around the green'));
      final shot2 = dy(tester, find.byKey(const ValueKey('shot_row_1')));
      final gir = dy(tester, find.text('GIR'));
      final putting = dy(tester, find.text('Putting'));
      final putt = dy(tester, find.byKey(const ValueKey('putt_row_0')));
      final addPutt = dy(tester, find.byKey(const ValueKey('add_putt')));
      // "Score" labels both the section header and the score stepper.
      final scoreHeader = dy(tester, find.text('Score').first);
      final penalty = dy(tester, find.byKey(const ValueKey('penalty')));
      final score = dy(tester, find.byKey(const ValueKey('score')));

      expect(hole, lessThan(tee));
      expect(tee, lessThan(teeShot));
      expect(teeShot, lessThan(teeResult));
      expect(teeResult, lessThan(approach));
      expect(approach, lessThan(shot2));
      expect(shot2, lessThan(gir));
      expect(gir, lessThan(putting));
      expect(putting, lessThan(putt));
      expect(putt, lessThan(addPutt));
      expect(addPutt, lessThan(scoreHeader));
      expect(scoreHeader, lessThan(penalty));
      // Score is the last scoring input — below every other stat.
      expect(penalty, lessThan(score));
    });

    testWidgets('the tee shot is from the tee, and cannot be removed',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial(yards: 420));

      expect(find.byKey(const ValueKey('shot_row_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('shot_lie_0')), findsNothing);
      expect(find.byKey(const ValueKey('shot_delete_0')), findsNothing);
    });

    testWidgets('Fairway hit Yes lays out shot 2 from the fairway',
        (tester) async {
      final state = await pumpCard(tester, initial: HoleDraft.initial());
      expect(find.byKey(const ValueKey('shot_row_1')), findsNothing);

      await answerTee(tester, hit: true);

      expect(state.draft.shots, hasLength(2));
      expect(shown(tester, 'shot_lie_1'), 'Fairway');
    });

    testWidgets('Fairway hit No lays it out from the rough instead',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());
      await answerTee(tester, hit: false);
      expect(shown(tester, 'shot_lie_1'), 'Light Rough');
    });

    testWidgets('changing the answer moves shot 2 to match', (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());
      await answerTee(tester, hit: false);
      await answerTee(tester, hit: true);
      expect(shown(tester, 'shot_lie_1'), 'Fairway');
      expect(find.byKey(const ValueKey('shot_row_2')), findsNothing);
    });

    testWidgets('only the tee shot arrives with a distance', (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial(yards: 420));
      await answerTee(tester, hit: true);
      await tapKey(tester, 'add_shot');

      expect(distanceShown(tester, 0), '420');
      expect(distanceShown(tester, 1), '');
      expect(distanceShown(tester, 2), '');
    });

    testWidgets('no club is suggested — not laid out, not from a distance',
        (tester) async {
      final state =
          await pumpCard(tester, initial: HoleDraft.initial(yards: 420));
      await answerTee(tester, hit: true);
      expect(shown(tester, 'shot_club_0'), isNull);
      expect(shown(tester, 'shot_club_1'), isNull);

      await tester.enterText(
          find.byKey(const ValueKey('shot_distance_1')), '150');
      await tester.pumpAndSettle();

      expect(state.draft.shots[1].distanceYards, 150);
      expect(state.draft.shots[1].club, isNull);
    });

    testWidgets('choosing a club + typing a distance updates the draft',
        (tester) async {
      final state = await pumpCard(tester, initial: HoleDraft.initial());
      await pick(tester, 'shot_club_0', 'Driver');
      await tester.enterText(
          find.byKey(const ValueKey('shot_distance_0')), '268');
      await tester.pump();

      expect(state.draft.shots.first.club, 'Driver');
      expect(state.draft.shots.first.distanceYards, 268);
    });

    testWidgets('editing the yards carries the tee shot distance along',
        (tester) async {
      final state =
          await pumpCard(tester, initial: HoleDraft.initial(yards: 400));
      await tester.enterText(find.byKey(const ValueKey('yards')), '455');
      await tester.pumpAndSettle();
      expect(state.draft.shots.first.distanceYards, 455);
      expect(distanceShown(tester, 0), '455');
    });

    testWidgets('Add shot and remove shot move the score with them',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      expect(state.draft.score, 3);

      await tapKey(tester, 'add_shot');
      expect(state.draft.shots, hasLength(3));
      expect(state.draft.score, 4);

      await tapKey(tester, 'shot_delete_2');
      expect(state.draft.shots, hasLength(2));
      expect(state.draft.score, 3);
    });

    testWidgets('deleting a shot refreshes the rows that shift up (#81)',
        (tester) async {
      // Rows are keyed by index, so deleting shot 2 moves shot 3's data into
      // row 1's widget state. A DropdownButtonFormField would keep displaying
      // the deleted club; the controlled DropdownButton must not.
      final state = await pumpCard(
        tester,
        initial: answeredPar4().copyWith(shots: const [
          ShotDraft(lie: 'Tee'),
          ShotDraft(club: '5 Wood', lie: 'Fairway'),
          ShotDraft(club: '7 Iron', lie: 'Deep Rough'),
        ]),
      );
      await tapKey(tester, 'shot_delete_1');

      expect(state.draft.shots[1].club, '7 Iron');
      expect(shown(tester, 'shot_club_1'), '7 Iron');
      expect(shown(tester, 'shot_lie_1'), 'Deep Rough');
    });

    testWidgets('marking a shot as a penalty counts the stroke',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      await tapKey(tester, 'shot_penalty_1');

      expect(state.draft.shots[1].result, 'Penalty');
      expect(state.draft.penaltyStrokes, 1);
      expect(state.draft.score, 4);
    });

    testWidgets('the last shot is badged Holed when there are no putts',
        (tester) async {
      await pumpCard(tester, initial: answeredPar4());
      expect(find.byKey(const ValueKey('shot_holed_1')), findsNothing);

      await tapKey(tester, 'putt_delete_0');

      expect(find.byKey(const ValueKey('shot_holed_1')), findsOneWidget);
    });
  });

  group('HoleCard — putts are rows', () {
    testWidgets('a fresh hole lays out one putt, holed, numbered after the shots',
        (tester) async {
      await pumpCard(tester, initial: answeredPar4());

      final row = find.byKey(const ValueKey('putt_row_0'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Putt 1  ·  Shot 3')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('putt_holed_0')), findsOneWidget);
      expect(puttDistanceShown(tester, 0), isEmpty);
      expect(find.byKey(const ValueKey('putt_row_1')), findsNothing);
    });

    testWidgets('a putt asks only for its distance to the hole, in feet',
        (tester) async {
      await pumpCard(tester, initial: answeredPar4());

      final row = find.byKey(const ValueKey('putt_row_0'));
      expect(find.descendant(of: row, matching: find.text('ft')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('To hole')),
          findsOneWidget);
      expect(
        find.descendant(
            of: row, matching: find.byType(DropdownButton<String?>)),
        findsNothing,
      );
    });

    testWidgets('Add putt adds a row and a stroke; only the last is Holed',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());

      await tapKey(tester, 'add_putt');

      expect(state.draft.putts, 2);
      expect(state.draft.score, 4);
      expect(find.byKey(const ValueKey('putt_row_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('putt_holed_0')), findsNothing);
      expect(find.byKey(const ValueKey('putt_holed_1')), findsOneWidget);
      expect(find.text('Putt 2  ·  Shot 4'), findsOneWidget);
    });

    testWidgets('typing a distance records it in feet, and clearing unsets it',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());

      await tester.enterText(
          find.byKey(const ValueKey('putt_distance_0')), '14');
      await tester.pumpAndSettle();
      expect(state.draft.puttShots.single.distanceFeet, 14);
      expect(state.draft.puttShots.single.distanceYards, isNull);
      expect(state.draft.score, 3, reason: 'a distance is not a stroke');

      await tester.enterText(find.byKey(const ValueKey('putt_distance_0')), '');
      await tester.pumpAndSettle();
      expect(state.draft.puttShots.single.distanceFeet, isNull);
    });

    testWidgets('removing a putt refreshes the rows that shift up',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: answeredPar4().copyWith(score: 4, puttShots: const [
          ShotDraft.putt(distanceFeet: 30),
          ShotDraft.putt(distanceFeet: 3),
        ]),
      );
      expect(puttDistanceShown(tester, 0), '30');

      await tapKey(tester, 'putt_delete_0');

      expect(state.draft.puttShots, const [ShotDraft.putt(distanceFeet: 3)]);
      expect(state.draft.score, 3);
      expect(puttDistanceShown(tester, 0), '3');
      expect(find.byKey(const ValueKey('putt_row_1')), findsNothing);
    });

    testWidgets('a holed putt fits a phone-width card', (tester) async {
      // The header carries the label, the Holed badge and the remove button;
      // at a phone's width the label is what gives way, not the row.
      await pumpCard(tester, initial: answeredPar4());
      tester.view.physicalSize = const Size(360, 3000);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('putt_holed_0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no putts the section says so, and a putt can come back',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      expect(find.byKey(const ValueKey('no_putts')), findsNothing);

      await tapKey(tester, 'putt_delete_0');
      expect(state.draft.putts, 0);
      expect(find.byKey(const ValueKey('no_putts')), findsOneWidget);

      await tapKey(tester, 'add_putt');
      expect(state.draft.putts, 1);
      expect(find.byKey(const ValueKey('no_putts')), findsNothing);
    });
  });

  group('HoleCard — GIR follows the shots', () {
    testWidgets('fairway then green is a GIR on a par 4', (tester) async {
      final state = await pumpCard(tester, initial: HoleDraft.initial());
      await answerTee(tester, hit: true);

      expect(state.draft.gir, isTrue);
      expect(switchTile(tester, 'GIR').value, isTrue);
    });

    testWidgets('a third shot before putting turns it off and locks it',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      await tapKey(tester, 'add_shot');

      expect(state.draft.gir, isFalse);
      final tile = switchTile(tester, 'GIR');
      expect(tile.onChanged, isNull);
      expect(find.text('N/A — 3 strokes before putting'), findsOneWidget);
    });
  });

  group('HoleCard — up & down', () {
    testWidgets('success only appears once an attempt is recorded',
        (tester) async {
      await pumpCard(tester, initial: answeredPar4());
      expect(find.text('Up/Down success'), findsNothing);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Up/Down attempt'));
      await tester.pumpAndSettle();

      expect(find.text('Up/Down success'), findsOneWidget);
      // It sits with the putts that decide it.
      expect(
        dy(tester, find.byKey(const ValueKey('putt_row_0'))),
        lessThan(dy(tester, find.text('Up/Down success'))),
      );
    });

    testWidgets('an attempt with one putt is selected as a success',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      expect(state.draft.putts, 1);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Up/Down attempt'));
      await tester.pumpAndSettle();

      expect(state.draft.upDownSuccess, isTrue);
      expect(switchTile(tester, 'Up/Down success').value, isTrue);
    });

    testWidgets('a second putt clears it and says why', (tester) async {
      final state = await pumpCard(
        tester,
        initial: applyEdit(
          answeredPar4(),
          answeredPar4().copyWith(upDownAttempt: true),
        ),
      );
      expect(state.draft.upDownSuccess, isTrue);

      await tapKey(tester, 'add_putt');

      expect(state.draft.putts, 2);
      expect(state.draft.upDownSuccess, isFalse);
      expect(switchTile(tester, 'Up/Down success').onChanged, isNull);
      expect(find.text('N/A — 2+ putts'), findsOneWidget);

      // And back down to one putt selects it again.
      await tapKey(tester, 'putt_delete_1');
      expect(state.draft.upDownSuccess, isTrue);
    });

    testWidgets('turning the attempt off clears and hides the success',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: applyEdit(
          answeredPar4(),
          answeredPar4().copyWith(upDownAttempt: true),
        ),
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Up/Down attempt'));
      await tester.pumpAndSettle();

      expect(state.draft.upDownAttempt, isFalse);
      expect(state.draft.upDownSuccess, isFalse);
      expect(find.text('Up/Down success'), findsNothing);
    });
  });

  group('HoleCard — bunkers', () {
    testWidgets('sand save only appears once a bunker is visited',
        (tester) async {
      await pumpCard(tester, initial: answeredPar4());
      expect(find.text('Sand save'), findsNothing);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Bunker visited'));
      await tester.pumpAndSettle();

      expect(find.text('Sand save'), findsOneWidget);
    });

    testWidgets('a shot from a bunker turns bunker visited on and holds it',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      await pick(tester, 'shot_lie_1', 'Bunker');

      expect(state.draft.bunkerVisited, isTrue);
      expect(switchTile(tester, 'Bunker visited').onChanged, isNull);
      // Out of the bunker and one putt: a sand save, selected for you.
      expect(state.draft.sandSave, isTrue);
    });

    testWidgets('turning bunker visited off also clears sand save',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: answeredPar4().copyWith(bunkerVisited: true, sandSave: true),
      );
      await tester.tap(find.widgetWithText(SwitchListTile, 'Bunker visited'));
      await tester.pumpAndSettle();

      expect(state.draft.bunkerVisited, isFalse);
      expect(state.draft.sandSave, isFalse);
    });
  });

  group('HoleCard — score', () {
    testWidgets('counts itself from the strokes, and shows the sum',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      expect(find.text('2 shots + 1 putt'), findsOneWidget);

      await tapKey(tester, 'add_putt');
      await tapKey(tester, 'Penalty strokes_inc');

      expect(state.draft.score, 5);
      expect(find.text('2 shots + 2 putts + 1 penalty'), findsOneWidget);
    });

    testWidgets('a score that disagrees with the strokes blocks the save',
        (tester) async {
      var saves = 0;
      final state = await pumpCard(
        tester,
        initial: answeredPar4(),
        onSave: () => saves++,
      );
      await tapKey(tester, 'Score_inc');
      await tapKey(tester, 'Score_inc');

      expect(state.draft.score, 5);
      expect(find.text('The strokes add up to 3'), findsOneWidget);
      expect(find.textContaining('Score is 5'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
      await tester.pumpAndSettle();
      expect(saves, 0);
    });

    testWidgets('"Add 2 shots" fills the gap so it saves', (tester) async {
      var saves = 0;
      final state = await pumpCard(
        tester,
        initial: answeredPar4(),
        onSave: () => saves++,
      );
      await tapKey(tester, 'Score_inc');
      await tapKey(tester, 'Score_inc');
      expect(find.text('Add 2 shots'), findsOneWidget);

      await tapKey(tester, 'fix_add_shots');

      expect(state.draft.shots, hasLength(4));
      expect(state.draft.score, 5);
      expect(find.byKey(const ValueKey('hole_errors')), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
      await tester.pumpAndSettle();
      expect(saves, 1);
    });

    testWidgets('"Make the score 3" takes the strokes at their word',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      await tapKey(tester, 'Score_inc');

      await tapKey(tester, 'fix_match_score');

      expect(state.draft.score, 3);
      expect(find.byKey(const ValueKey('hole_errors')), findsNothing);
    });

    testWidgets('a shot from the green is flagged, and can become a putt',
        (tester) async {
      final state = await pumpCard(tester, initial: answeredPar4());
      await tapKey(tester, 'add_shot');
      await pick(tester, 'shot_lie_2', 'Green');

      expect(find.byKey(const ValueKey('hole_warnings')), findsOneWidget);
      await tapKey(tester, 'fix_count_as_putt');

      expect(state.draft.shots, hasLength(2));
      expect(state.draft.putts, 2);
      expect(find.byKey(const ValueKey('putt_row_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('hole_warnings')), findsNothing);
    });
  });

  group('HoleCard — steppers clamp at minimum', () {
    testWidgets('score decrement is disabled at score == putts + 1',
        (tester) async {
      await pumpCard(
        tester,
        initial:
            HoleDraft.initial(par: 4).copyWith(score: 3, puttShots: putts(2)),
      );
      final btn =
          tester.widget<IconButton>(find.byKey(const ValueKey('Score_dec')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('score decrement is disabled at score == 1', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(score: 1, puttShots: const []),
      );
      final btn = tester.widget<IconButton>(find.byKey(const ValueKey('Score_dec')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('penalty decrement is disabled at penaltyStrokes == 0',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());
      final btn = tester
          .widget<IconButton>(find.byKey(const ValueKey('Penalty strokes_dec')));
      expect(btn.onPressed, isNull);
    });
  });

  group('HoleCard — yards (#36)', () {
    testWidgets('shows the auto-filled yards value', (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial(par: 4, yards: 420));
      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('yards')));
      expect(field.controller!.text, '420');
    });

    testWidgets('a zero-yard hole shows an empty field, not "0"',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial(yards: 0));
      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('yards')));
      expect(field.controller!.text, '');
    });

    testWidgets('editing yards updates the draft', (tester) async {
      final state =
          await pumpCard(tester, initial: HoleDraft.initial(yards: 400));
      await tester.enterText(find.byKey(const ValueKey('yards')), '455');
      await tester.pump();
      expect(state.draft.yards, 455);
    });

    testWidgets('clearing yards stores 0', (tester) async {
      final state =
          await pumpCard(tester, initial: HoleDraft.initial(yards: 400));
      await tester.enterText(find.byKey(const ValueKey('yards')), '');
      await tester.pump();
      expect(state.draft.yards, 0);
    });
  });

  group('HoleCard — saved indicator', () {
    testWidgets('shows "Saved" chip when draft matches savedDraft',
        (tester) async {
      final draft = answeredPar4();
      await pumpCard(tester, initial: draft, savedDraft: draft);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Unsaved'), findsNothing);
    });

    testWidgets('shows "Unsaved" chip when draft differs from savedDraft',
        (tester) async {
      final saved = answeredPar4();
      final dirty = saved.copyWith(score: 5);
      await pumpCard(tester, initial: dirty, savedDraft: saved);
      expect(find.text('Unsaved'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('shows neither chip when hole has never been saved',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Unsaved'), findsNothing);
    });
  });

  group('HoleCard — Save button', () {
    testWidgets('tapping Save Hole on a complete hole invokes onSave',
        (tester) async {
      var saveCount = 0;
      await pumpCard(
        tester,
        initial: answeredPar4(),
        onSave: () => saveCount++,
      );
      expect(find.byKey(const ValueKey('hole_errors')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
      await tester.pump();
      expect(saveCount, 1);
    });
  });

  group('HoleCard — prev/next chevrons', () {
    testWidgets('prev chevron is disabled when onPrev is null',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());
      final btn =
          tester.widget<IconButton>(find.byKey(const ValueKey('hole_prev')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('next chevron is disabled when onNext is null',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());
      final btn =
          tester.widget<IconButton>(find.byKey(const ValueKey('hole_next')));
      expect(btn.onPressed, isNull);
    });
  });

  group('HoleCard — which yardage set the round uses (#81)', () {
    testWidgets('labels the yards field with the set name', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4, yards: 431),
        yardageSetName: 'Blue · Sunday pins',
      );

      // Naming it here puts it where the number it explains appears.
      expect(find.text('Yards · Blue · Sunday pins'), findsOneWidget);
    });

    testWidgets('explains a blank yardage when the round has no set',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());

      expect(find.text('Yards'), findsOneWidget);
      expect(
        find.text('No yardage set on this round — yardages are not pre-filled'),
        findsOneWidget,
      );
    });
  });

  group('HoleCard — stroke index (#81)', () {
    testWidgets('is absent unless the host wires it up', (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());
      expect(find.byKey(const ValueKey('stroke_index')), findsNothing);
    });

    testWidgets('shows the course value and says where it saves',
        (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        strokeIndex: 7,
        onStrokeIndexChanged: (_) {},
      );

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('stroke_index')),
      );
      expect(field.controller!.text, '7');
      // The one field here that edits the course rather than the round.
      expect(find.text('Saved on the course, not this round'), findsOneWidget);
    });

    testWidgets('reports edits as a parsed value', (tester) async {
      int? seen;
      await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        strokeIndex: null,
        onStrokeIndexChanged: (v) => seen = v,
      );

      await tester.enterText(
          find.byKey(const ValueKey('stroke_index')), '12');
      await tester.pumpAndSettle();
      expect(seen, 12);

      await tester.enterText(find.byKey(const ValueKey('stroke_index')), '');
      await tester.pumpAndSettle();
      expect(seen, isNull);
    });

    testWidgets('flags a value outside 1-18', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        strokeIndex: 19,
        onStrokeIndexChanged: (_) {},
      );
      expect(find.text('Must be 1-18'), findsOneWidget);
    });

    testWidgets('flags a stroke index another hole already uses',
        (tester) async {
      // The card shows one hole at a time, so a clash in a set that must be a
      // permutation of 1..18 would otherwise go unnoticed.
      await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        strokeIndex: 7,
        strokeIndexClashWith: 12,
        onStrokeIndexChanged: (_) {},
      );
      expect(find.text('Already used on hole 12'), findsOneWidget);
    });

    testWidgets('sits in the Hole section with par and yards', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        strokeIndex: 7,
        onStrokeIndexChanged: (_) {},
      );

      expect(
        dy(tester, find.text('Hole')),
        lessThan(dy(tester, find.byKey(const ValueKey('stroke_index')))),
      );
      expect(
        dy(tester, find.byKey(const ValueKey('stroke_index'))),
        lessThan(dy(tester, find.text('Tee shot'))),
      );
    });

    testWidgets('an unsaved stroke index shows the Unsaved chip',
        (tester) async {
      // Stroke index is not part of the draft, so without this the chip would
      // read Saved while an edit was still pending.
      final draft = HoleDraft.initial();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoleCard(
            holeNumber: 1,
            draft: draft,
            savedDraft: draft,
            strokeIndex: 7,
            strokeIndexDirty: true,
            onStrokeIndexChanged: (_) {},
            onChanged: (_) {},
            onSave: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
    });
  });

  // #73: a dropdown's empty choice is drawn as a dash; it reads "None", with
  // the field's name.
  testWidgets('an empty club reads "Club, None"', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, initial: HoleDraft.initial());

    expect(find.bySemanticsLabel('Club\nNone'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the hole and its sections are headings', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, initial: HoleDraft.initial());

    for (final title in const ['Hole 1', 'Hole', 'Tee shot', 'Putting', 'Score']) {
      expect(
        tester.getSemantics(find.text(title).first),
        isSemantics(label: title, isHeader: true),
        reason: title,
      );
    }
    semantics.dispose();
  });

  // #73: every control on the card, the issue panel's fix buttons and a
  // deletable shot and putt included, is at least 48 dp to tap.
  testWidgets('every control on the card meets the 48 dp tap target',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, initial: answeredPar4());
    await tapKey(tester, 'add_shot');
    await tapKey(tester, 'Score_inc');
    await tapKey(tester, 'Score_inc');
    expect(find.byKey(const ValueKey('fix_add_shots')), findsOneWidget);
    expect(find.byKey(const ValueKey('shot_delete_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('putt_delete_0')), findsOneWidget);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  // #73: TalkBack moves down the card in the order a hole is played: the
  // hole (announced as a live region), each section's heading before its
  // fields, and the Save row last.
  testWidgets('a screen reader meets the card in playing order',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, initial: HoleDraft.initial());

    expect(
      tester.semantics.simulatedAccessibilityTraversal(),
      containsAllInOrder(<Matcher>[
        isSemantics(label: 'Hole 1', isHeader: true, isLiveRegion: true),
        isSemantics(label: 'Hole', isHeader: true),
        isSemantics(label: 'Par 4', isSelected: true),
        isSemantics(label: 'Tee shot', isHeader: true),
        isSemantics(label: 'Approach & around the green', isHeader: true),
        isSemantics(label: 'Putting', isHeader: true),
        isSemantics(label: 'Score', isHeader: true),
        isSemantics(label: 'Penalty strokes', value: '0'),
        isSemantics(tooltip: 'Previous hole'),
        isSemantics(label: 'Save Hole'),
        isSemantics(tooltip: 'Next hole'),
      ]),
    );
    semantics.dispose();
  });
}
