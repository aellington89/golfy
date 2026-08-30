import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/round_with_course.dart';
import '../../../data/repository_provider.dart';
import '../../../shell/tab_index_provider.dart';
import '../active_round_provider.dart';
import '../delete_round.dart';
import '../edit_round_dialog.dart';
import 'hole_scorecard_card.dart';
import 'scorecard_totals_card.dart';

/// Read-only scorecard for a round. Lists all 18 holes with their stats plus
/// a totals summary, sourced from the same [holeResultsStreamProvider] the
/// Hole Entry form writes to. The AppBar's Edit action hands off to that form
/// (via [activeRoundIdProvider] + [tabIndexProvider]) with the round's data
/// already persisted, so editing resumes where the player left off.
///
/// Pushed as a full-screen route over the tab shell — back returns to the
/// Rounds list.
class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({super.key, required this.roundId});

  static const int _holeCount = 18;

  final int roundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundAsync = ref.watch(roundWithCourseProvider(roundId));
    final holesAsync = ref.watch(holeResultsStreamProvider(roundId));

    return Scaffold(
      appBar: AppBar(
        title: _ScorecardTitle(roundAsync: roundAsync),
        actions: [
          _DeleteButton(roundId: roundId),
          _EditButton(roundId: roundId),
          _EditDetailsButton(roundId: roundId),
        ],
      ),
      body: holesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load scorecard: $e')),
        data: (holes) {
          final byHole = {for (final h in holes) h.holeNumber: h};
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: _holeCount + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ScorecardTotalsCard(
                  key: const ValueKey('scorecard_totals'),
                  holes: holes,
                );
              }
              final holeNumber = index;
              return HoleScorecardCard(
                key: ValueKey('scorecard_hole_$holeNumber'),
                holeNumber: holeNumber,
                result: byHole[holeNumber],
              );
            },
          );
        },
      ),
    );
  }
}

/// AppBar title: course name over the round date. Reads the round
/// optimistically (`roundAsync.value`) with a plain "Scorecard" fallback so
/// the holes list never blocks on the round lookup. Mirrors the Hole Entry
/// screen's title pattern.
class _ScorecardTitle extends StatelessWidget {
  const _ScorecardTitle({required this.roundAsync});

  final AsyncValue<RoundWithCourse?> roundAsync;

  static final _displayFormat = DateFormat.yMMMMd();

  @override
  Widget build(BuildContext context) {
    final round = roundAsync.value;
    if (round == null) return const Text('Scorecard');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          round.courseName,
          style: Theme.of(context).textTheme.titleLarge,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          _formatDate(round.round.date),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static String _formatDate(String iso) {
    try {
      return _displayFormat.format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

/// "Edit scores": hands off to the Hole Entry tab to edit this round's holes.
/// The data is already persisted, so the form pre-fills from
/// [holeResultsStreamProvider]; we just point the shell at it and pop back to
/// reveal it. Distinct from [_EditDetailsButton], which edits the round's own
/// details (event, course, date, …).
class _EditButton extends ConsumerWidget {
  const _EditButton({required this.roundId});

  final int roundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('scorecard_edit_button'),
      icon: const Icon(Icons.edit_note),
      tooltip: 'Edit scores',
      onPressed: () {
        ref.read(activeRoundIdProvider.notifier).set(roundId);
        ref.read(tabIndexProvider.notifier).set(ShellTabs.holeEntry);
        Navigator.of(context).pop();
      },
    );
  }
}

/// "Edit round details": opens [EditRoundDialog] to change this round's event,
/// course, date, round number or notes — as opposed to [_EditButton]'s
/// "Edit scores" (hole entry). No-op until the round has loaded.
class _EditDetailsButton extends ConsumerWidget {
  const _EditDetailsButton({required this.roundId});

  final int roundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('scorecard_edit_details_button'),
      icon: const Icon(Icons.edit_outlined),
      tooltip: 'Edit round details',
      onPressed: () {
        final round = ref.read(roundWithCourseProvider(roundId)).value;
        if (round == null) return;
        openEditRoundDialog(context, ref, round);
      },
    );
  }
}

/// Confirms, then deletes this round (cascade-deleting its hole_results) and
/// pops back to the Rounds list. Clears [activeRoundIdProvider] when this was
/// the active round. Shares its confirmation dialog and delete logic with the
/// Rounds list row via [confirmDeleteRound] / [deleteRoundAndClearActive].
class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.roundId});

  final int roundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('scorecard_delete_button'),
      icon: const Icon(Icons.delete_outline),
      tooltip: 'Delete round',
      onPressed: () async {
        final courseName =
            ref.read(roundWithCourseProvider(roundId)).value?.courseName;
        final confirmed =
            await confirmDeleteRound(context, courseName: courseName);
        if (!confirmed) return;
        await deleteRoundAndClearActive(ref, roundId);
        if (context.mounted) Navigator.of(context).pop();
      },
    );
  }
}
