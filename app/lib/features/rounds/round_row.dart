import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/round_with_course.dart';
import '../../shell/tab_index_provider.dart';
import '../stats/score_color.dart';
import '../stats/score_format.dart';
import 'active_round_provider.dart';
import 'delete_round.dart';
import 'edit_round_dialog.dart';
import 'scorecard/scorecard_screen.dart';

/// A single round row: swipe-to-delete, tap-to-resume (sets the active round
/// and jumps to Hole Entry), an edit-details action, and a scorecard action.
/// Shared by the Rounds list and the event detail screen so both surfaces
/// behave identically. The `round_*_<id>` keys are relied on by widget tests.
class RoundRow extends ConsumerWidget {
  const RoundRow({super.key, required this.round});

  final RoundWithCourse round;

  static final _displayFormat = DateFormat.yMMMMd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formattedDate = _formatDate(round.round.date);

    return Dismissible(
      key: ValueKey('round_${round.round.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) =>
          confirmDeleteRound(context, courseName: round.courseName),
      onDismissed: (_) => deleteRoundAndClearActive(ref, round.round.id),
      child: ListTile(
        onTap: () {
          ref.read(activeRoundIdProvider.notifier).set(round.round.id);
          ref.read(tabIndexProvider.notifier).set(ShellTabs.holeEntry);
        },
        title: Text(
          '${round.courseName} — Round ${round.round.roundNumber}',
        ),
        subtitle: _RoundSubtitle(
          date: formattedDate,
          courseSetName: round.courseSetName,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (round.holesEntered > 0) ...[
              Text(
                formatRelativeToPar(round.relativeToPar),
                key: ValueKey('round_score_${round.round.id}'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scoreToParColor(round.relativeToPar, theme.colorScheme),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              '${round.holesEntered}/18',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 4),
            IconButton(
              key: ValueKey('round_edit_button_${round.round.id}'),
              icon: const Icon(Icons.edit_outlined),
              iconSize: 20,
              tooltip: 'Edit round',
              onPressed: () => openEditRoundDialog(context, ref, round),
            ),
            IconButton(
              key: ValueKey('scorecard_button_${round.round.id}'),
              icon: const Icon(Icons.scoreboard_outlined),
              iconSize: 20,
              tooltip: 'View scorecard',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScorecardScreen(roundId: round.round.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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

/// Date, plus the yardage set the round was played from when it has one (#81).
///
/// The set decides which yardages pre-fill the round's holes, so which one is
/// attached is worth seeing without opening the round. No set means none was
/// chosen — the absent ruler icon is the signal, rather than a "No yardage set"
/// caption on every casual round.
class _RoundSubtitle extends StatelessWidget {
  const _RoundSubtitle({required this.date, required this.courseSetName});

  final String date;
  final String? courseSetName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setName = courseSetName;
    if (setName == null) return Text(date);
    return Row(
      children: [
        Flexible(child: Text(date, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        Icon(Icons.straighten, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            setName,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
