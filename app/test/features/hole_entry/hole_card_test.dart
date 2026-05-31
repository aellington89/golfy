import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/features/hole_entry/hole_card.dart';
import 'package:golfy_app/features/hole_entry/hole_draft.dart';

/// Stateful test harness that holds a [HoleDraft] and rebuilds when
/// [HoleCard.onChanged] fires — mirrors the real screen's ownership model.
class _Harness extends StatefulWidget {
  const _Harness({required this.initial, this.savedDraft, this.onSave});

  final HoleDraft initial;
  final HoleDraft? savedDraft;
  final VoidCallback? onSave;

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
}) async {
  // Default 800x600 test surface is shorter than the form. Resize so every
  // row is on-screen and tappable without scrolling.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_Harness(
    initial: initial,
    savedDraft: savedDraft,
    onSave: onSave,
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

  group('HoleCard — steppers clamp at minimum', () {
    testWidgets('score decrement is disabled at score == 1', (tester) async {
      await pumpCard(
        tester,
        initial: HoleDraft.initial().copyWith(score: 1),
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
}
