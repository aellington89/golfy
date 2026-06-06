import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_provider.dart';
import 'active_round_provider.dart';

/// Shared delete-round behaviour used by both the Rounds list (#9 swipe row)
/// and the scorecard screen (#11 AppBar action). Keeping the confirmation copy
/// and the delete-and-clear-active logic in one place means the two surfaces
/// can't drift apart — they ask the same question and clean up the same state.

/// Shows the "Delete round?" confirmation dialog and resolves to whether the
/// user tapped Delete. [courseName] is woven into the body when known; the
/// scorecard may briefly have no round loaded, in which case the copy omits it.
Future<bool> confirmDeleteRound(
  BuildContext context, {
  String? courseName,
}) async {
  final where = courseName == null ? '' : ' at $courseName';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete round?'),
      content: Text(
        'This will permanently delete the round$where and any hole data '
        'entered for it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Deletes [roundId] (cascade-deleting its hole_results via the schema FK) and
/// clears [activeRoundIdProvider] only when that round was the active one, so a
/// stale id never points the Hole Entry tab at a deleted round.
Future<void> deleteRoundAndClearActive(WidgetRef ref, int roundId) async {
  final repo = ref.read(repositoryProvider);
  final wasActive = ref.read(activeRoundIdProvider) == roundId;
  await repo.deleteRound(roundId);
  if (wasActive) {
    ref.read(activeRoundIdProvider.notifier).clear();
  }
}
