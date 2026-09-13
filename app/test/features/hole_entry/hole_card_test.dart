import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/hole_entry/hole_card.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';

/// Stateful test harness that holds a [HoleDraft] and rebuilds when
/// [HoleCard.onChanged] fires — mirrors the real screen's ownership model.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.initial,
    this.savedDraft,
    this.onSave,
    this.courseSetName,
  });

  final HoleDraft initial;
  final HoleDraft? savedDraft;
  final VoidCallback? onSave;
  final String? courseSetName;

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
          courseSetName: widget.courseSetName,
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
  String? courseSetName,
}) async {
  // Default 800x600 test surface is shorter than the form. Resize so every
  // row — including the Shots section — is on-screen and tappable.
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_Harness(
    initial: initial,
    savedDraft: savedDraft,
    onSave: onSave,
    courseSetName: courseSetName,
  ));
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// Taps the segment with [label] inside the [n]th [SegmentedButton] on
/// screen. Required because [find.widgetWithText] returns the whole
/// segmented button (its center sits on the middle segment) which means
/// tapping it picks the wrong option.
Future<void> tapSegment(
  WidgetTester tester, {
  required int segmentedIndex,
  required String label,
}) async {
  final segmented = find.byType(SegmentedButton<int>).at(segmentedIndex);
  await tester.tap(find.descendant(of: segmented, matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// The club the shot row at [index] is currently *displaying* — as opposed to
/// what the draft holds. Distinguishing the two is the point of the
/// stale-dropdown regression test.
String? clubShown(WidgetTester tester, int index) {
  return tester
      .widget<DropdownButton<String?>>(
        find.byKey(ValueKey('shot_club_$index')),
      )
      .value;
}

void main() {
  group('HoleCard — par/fairway conditional', () {
    testWidgets('par=3 disables the fairway control and shows the N/A label',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial(par: 3));

      expect(find.text('Fairway hit (N/A on par 3)'), findsOneWidget);
      final segmented =
          tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>).at(1));
      expect(segmented.onSelectionChanged, isNull);
    });

    testWidgets('switching from par 3 to par 4 re-enables the fairway control',
        (tester) async {
      final state = await pumpCard(tester, initial: HoleDraft.initial(par: 3));

      await tapSegment(tester, segmentedIndex: 0, label: '4');

      expect(state.draft.par, 4);
      expect(find.text('Fairway hit'), findsOneWidget);
      final segmented =
          tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>).at(1));
      expect(segmented.onSelectionChanged, isNotNull);
    });

    testWidgets('switching from par 4 to par 3 wipes fairwayHit to null',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(fairwayHit: true),
      );
      expect(state.draft.fairwayHit, true);

      await tapSegment(tester, segmentedIndex: 0, label: '3');

      expect(state.draft.par, 3);
      expect(state.draft.fairwayHit, isNull);
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

  group('HoleCard — up/down + bunker conditionals', () {
    testWidgets('up/down success switch is disabled when attempt is false',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());

      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Up/Down success'),
      );
      expect(tile.onChanged, isNull);
    });

    testWidgets('turning up/down attempt off also clears recorded success',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial()
            .copyWith(upDownAttempt: true, upDownSuccess: true),
      );
      expect(state.draft.upDownSuccess, true);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Up/Down attempt'));
      await tester.pumpAndSettle();

      expect(state.draft.upDownAttempt, false);
      expect(state.draft.upDownSuccess, false);
    });

    testWidgets('sand save switch is disabled when bunker visited is false',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());

      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Sand save'),
      );
      expect(tile.onChanged, isNull);
    });

    testWidgets('turning bunker visited off also clears sand save',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial()
            .copyWith(bunkerVisited: true, sandSave: true),
      );
      expect(state.draft.sandSave, true);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Bunker visited'));
      await tester.pumpAndSettle();

      expect(state.draft.bunkerVisited, false);
      expect(state.draft.sandSave, false);
    });
  });

  group('HoleCard — up/down success vs putts (#37)', () {
    testWidgets('up/down success is disabled with a reason when putts > 1',
        (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(upDownAttempt: true, putts: 2),
      );

      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Up/Down success'),
      );
      expect(tile.onChanged, isNull);
      expect(find.text('N/A — 2+ putts'), findsOneWidget);
    });

    testWidgets('up/down success is enabled at 1 putt when attempt is on',
        (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(upDownAttempt: true, putts: 1),
      );

      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Up/Down success'),
      );
      expect(tile.onChanged, isNotNull);
    });

    testWidgets('raising putts above 1 clears recorded up/down success',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial()
            .copyWith(upDownAttempt: true, putts: 1, upDownSuccess: true),
      );
      expect(state.draft.upDownSuccess, true);

      await tester.tap(find.byKey(const ValueKey('Putts_inc')));
      await tester.pumpAndSettle();

      expect(state.draft.putts, 2);
      expect(state.draft.upDownSuccess, false);
    });
  });

  group('HoleCard — putts < score coupling (#37)', () {
    testWidgets('putts increment is disabled at putts == score - 1',
        (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4).copyWith(score: 4, putts: 3),
      );
      final btn =
          tester.widget<IconButton>(find.byKey(const ValueKey('Putts_inc')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('score decrement is disabled at score == putts + 1',
        (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4).copyWith(score: 3, putts: 2),
      );
      final btn =
          tester.widget<IconButton>(find.byKey(const ValueKey('Score_dec')));
      expect(btn.onPressed, isNull);
    });
  });

  group('HoleCard — steppers clamp at minimum', () {
    testWidgets('score decrement is disabled at score == 1', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(score: 1, putts: 0),
      );
      final btn = tester.widget<IconButton>(find.byKey(const ValueKey('Score_dec')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('putts decrement is disabled at putts == 0', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(putts: 0),
      );
      final btn = tester.widget<IconButton>(find.byKey(const ValueKey('Putts_dec')));
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

  group('HoleCard — saved indicator', () {
    testWidgets('shows "Saved" chip when draft matches savedDraft',
        (tester) async {
      final draft = HoleDraft.initial();
      await pumpCard(tester, initial: draft, savedDraft: draft);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Unsaved'), findsNothing);
    });

    testWidgets('shows "Unsaved" chip when draft differs from savedDraft',
        (tester) async {
      final saved = HoleDraft.initial();
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
    testWidgets('tapping Save Hole invokes the onSave callback',
        (tester) async {
      var saveCount = 0;
      await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        onSave: () => saveCount++,
      );
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

  group('HoleCard — shots (#22)', () {
    testWidgets('Add shot appends a shot row', (tester) async {
      final state = await pumpCard(tester, initial: HoleDraft.initial());
      expect(find.byKey(const ValueKey('shot_row_0')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('add_shot')));
      await tester.pump();

      expect(find.byKey(const ValueKey('shot_row_0')), findsOneWidget);
      expect(state.draft.shots, hasLength(1));
    });

    testWidgets('choosing a club + typing distance updates the draft',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(shots: const [ShotDraft()]),
      );
      // Club is a dropdown; open it and pick "Driver".
      await tester.tap(find.byKey(const ValueKey('shot_club_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver').last);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey('shot_distance_0')), '268');
      await tester.pump();

      expect(state.draft.shots.single.club, 'Driver');
      expect(state.draft.shots.single.distanceYards, 268);
    });

    testWidgets('deleting a shot removes it', (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(shots: const [
          ShotDraft(club: 'Driver'),
          ShotDraft(club: '7 iron'),
        ]),
      );
      await tester.tap(find.byKey(const ValueKey('shot_delete_0')));
      await tester.pump();

      expect(state.draft.shots, hasLength(1));
      expect(state.draft.shots.single.club, '7 iron');
    });

    testWidgets('shows a saved shot\'s club in the dropdown', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial()
            .copyWith(shots: const [ShotDraft(club: '5 Wood', distanceYards: 230)]),
      );
      expect(clubShown(tester, 0), '5 Wood');
    });

    testWidgets('deleting a shot refreshes the rows that shift up (#81)',
        (tester) async {
      // Rows are keyed by index, so deleting shot 1 moves shot 2's data into
      // row 0's widget state. A DropdownButtonFormField would keep displaying
      // the deleted club; the controlled DropdownButton must not.
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(shots: const [
          ShotDraft(club: 'Driver'),
          ShotDraft(club: '7 Iron'),
        ]),
      );
      await tester.tap(find.byKey(const ValueKey('shot_delete_0')));
      await tester.pumpAndSettle();

      expect(state.draft.shots.single.club, '7 Iron');
      expect(clubShown(tester, 0), '7 Iron');
    });
  });

  group('HoleCard — smarter shots (#81)', () {
    testWidgets('Add shot pre-fills the tee shot instead of a blank row',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4, yards: 420),
      );

      await tester.tap(find.byKey(const ValueKey('add_shot')));
      await tester.pumpAndSettle();

      final shot = state.draft.shots.single;
      expect(shot.lie, 'Tee');
      expect(shot.distanceYards, 420);
      expect(shot.club, 'Driver');
    });

    testWidgets('an overridden suggestion sticks across rebuilds',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4, yards: 420),
      );
      await tester.tap(find.byKey(const ValueKey('add_shot')));
      await tester.pumpAndSettle();
      expect(state.draft.shots.single.club, 'Driver');

      // Override the suggested club, then force a rebuild by touching an
      // unrelated field. The choice must survive.
      await tester.tap(find.byKey(const ValueKey('shot_club_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 Wood').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('Score_inc')));
      await tester.pumpAndSettle();

      expect(state.draft.shots.single.club, '3 Wood');
      expect(clubShown(tester, 0), '3 Wood');
    });

    testWidgets('typing a distance fills an empty club but never replaces one',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(shots: const [ShotDraft()]),
      );

      await tester.enterText(
          find.byKey(const ValueKey('shot_distance_0')), '150');
      await tester.pumpAndSettle();
      expect(state.draft.shots.single.club, '7 Iron');

      // A club the user picked is never overwritten by a later distance edit.
      await tester.tap(find.byKey(const ValueKey('shot_club_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9 Iron').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('shot_distance_0')), '120');
      await tester.pumpAndSettle();

      expect(state.draft.shots.single.club, '9 Iron');
    });

    testWidgets('Build from score scaffolds the whole hole, then hides itself',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4, yards: 420)
            .copyWith(score: 4, putts: 2, fairwayHit: true),
      );

      await tester.tap(find.byKey(const ValueKey('build_shots_from_score')));
      await tester.pumpAndSettle();

      expect(state.draft.shots, hasLength(4));
      expect(state.draft.shots.first.lie, 'Tee');
      expect(state.draft.shots.last.result, 'Holed');
      expect(find.byKey(const ValueKey('build_shots_from_score')), findsNothing,
          reason: 'rebuilding an edited list would destroy work');
    });

    testWidgets(
        'warns on a contradiction and clears when the user reconciles it',
        (tester) async {
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4, yards: 420).copyWith(shots: const [
          ShotDraft(club: 'Driver', lie: 'Tee'),
          ShotDraft(club: 'Sand Wedge', lie: 'Bunker'),
        ]),
      );
      expect(find.byKey(const ValueKey('shot_warnings')), findsOneWidget);

      // Turning "Bunker visited" on resolves it — without anything being saved.
      await tester.tap(find.widgetWithText(SwitchListTile, 'Bunker visited'));
      await tester.pumpAndSettle();

      expect(state.draft.bunkerVisited, isTrue);
      expect(find.byKey(const ValueKey('shot_warnings')), findsNothing);
    });

    testWidgets('a hole with no shots still saves', (tester) async {
      var saved = false;
      final state = await pumpCard(
        tester,
        initial: HoleDraft.initial(),
        onSave: () => saved = true,
      );

      expect(find.byKey(const ValueKey('shot_warnings')), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Save Hole'));
      await tester.pumpAndSettle();

      expect(saved, isTrue);
      expect(state.draft.shotInputs(), isEmpty);
    });
  });

  group('HoleCard — play-order layout (#34)', () {
    testWidgets(
        'fields follow play sequence: tee → approach → putting → score',
        (tester) async {
      // Par 4 so the fairway control is enabled and labelled "Fairway hit".
      await pumpCard(tester, initial: HoleDraft.initial());

      double dyText(String t) => tester.getTopLeft(find.text(t)).dy;
      double dyKey(String k) => tester.getTopLeft(find.byKey(ValueKey(k))).dy;

      final fairway = dyText('Fairway hit');
      final gir = dyText('GIR');
      final putts = dyKey('putts');
      final penalty = dyKey('penalty');
      final score = dyKey('score');

      expect(fairway, lessThan(gir));
      expect(gir, lessThan(putts));
      expect(putts, lessThan(penalty));
      // Score is the last scoring input — below every other stat.
      expect(penalty, lessThan(score));
    });

    testWidgets('stage section headers render in play order', (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());

      expect(find.text('Tee'), findsOneWidget);
      expect(find.text('Approach & Around the Green'), findsOneWidget);
      expect(find.text('Putting'), findsOneWidget);
      // "Score" labels both the section header and the score stepper.
      expect(find.text('Score'), findsNWidgets(2));

      double dy(Finder f) => tester.getTopLeft(f).dy;
      expect(
        dy(find.text('Tee')),
        lessThan(dy(find.text('Approach & Around the Green'))),
      );
      expect(
        dy(find.text('Approach & Around the Green')),
        lessThan(dy(find.text('Putting'))),
      );
      // The Score header (first "Score" in tree order) sits below Putting.
      expect(
        dy(find.text('Putting')),
        lessThan(dy(find.text('Score').first)),
      );
    });

    testWidgets('par 3 keeps the fairway control in the Tee section',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial(par: 3));

      // Still present, disabled, N/A label — the reorder didn't drop it.
      expect(find.text('Fairway hit (N/A on par 3)'), findsOneWidget);
      final segmented = tester.widget<SegmentedButton<int>>(
          find.byType(SegmentedButton<int>).at(1));
      expect(segmented.onSelectionChanged, isNull);

      // And it sits under "Tee", above the Approach header and GIR.
      double dy(Finder f) => tester.getTopLeft(f).dy;
      expect(
        dy(find.text('Fairway hit (N/A on par 3)')),
        lessThan(dy(find.text('Approach & Around the Green'))),
      );
      expect(
        dy(find.text('Approach & Around the Green')),
        lessThan(dy(find.text('GIR'))),
      );
    });

    testWidgets(
        'up/down success and sand save sit in the Score section, above penalty',
        (tester) async {
      await pumpCard(tester, initial: HoleDraft.initial());

      double dy(Finder f) => tester.getTopLeft(f).dy;
      // First "Score" in tree order is the section header.
      final scoreHeader = dy(find.text('Score').first);
      final upDownSuccess = dy(find.text('Up/Down success'));
      final sandSave = dy(find.text('Sand save'));
      final putts = dy(find.byKey(const ValueKey('putts')));
      final penalty = dy(find.byKey(const ValueKey('penalty')));

      // They've left the Approach group (now below Putts), and sit under the
      // Score header ordered success → sand save → penalty strokes.
      expect(putts, lessThan(scoreHeader));
      expect(scoreHeader, lessThan(upDownSuccess));
      expect(upDownSuccess, lessThan(sandSave));
      expect(sandSave, lessThan(penalty));
    });
  });

  group('HoleCard — which yardage set the round uses (#81)', () {
    testWidgets('labels the yards field with the set name', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial(par: 4, yards: 431),
        courseSetName: 'Blue tees',
      );

      // Naming it here puts it where the number it explains appears.
      expect(find.text('Yards · Blue tees'), findsOneWidget);
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
}
