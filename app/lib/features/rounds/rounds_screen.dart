import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../shell/tab_index_provider.dart';
import '../../widgets/empty_state.dart';
import '../stats/score_color.dart';
import '../stats/score_format.dart';
import 'active_round_provider.dart';
import 'delete_round.dart';
import 'new_round_dialog.dart';
import 'scorecard/scorecard_screen.dart';

class RoundsScreen extends ConsumerWidget {
  const RoundsScreen({super.key});

  static final _displayFormat = DateFormat.yMMMMd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundsAsync = ref.watch(roundsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rounds')),
      floatingActionButton: roundsAsync.when(
        loading: () => null,
        error: (_, _) => null,
        data: (rounds) => FloatingActionButton(
          onPressed: () => _openNewRoundDialog(context, rounds),
          child: const Icon(Icons.add),
        ),
      ),
      body: roundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load rounds: $e')),
        data: (rounds) {
          if (rounds.isEmpty) {
            return const EmptyState(
              icon: Icons.golf_course_outlined,
              message: 'No rounds yet. Tap + to start your first round.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rounds.length,
            separatorBuilder: (_, _) => const Divider(height: 0),
            itemBuilder: (context, i) => _RoundRow(round: rounds[i]),
          );
        },
      ),
    );
  }

  Future<void> _openNewRoundDialog(
    BuildContext context,
    List<RoundWithCourse> rounds,
  ) async {
    await showDialog<int>(
      context: context,
      builder: (_) => NewRoundDialog(existingRounds: rounds),
    );
  }
}

class _RoundRow extends ConsumerWidget {
  const _RoundRow({required this.round});

  final RoundWithCourse round;

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
          ref.read(tabIndexProvider.notifier).set(1);
        },
        title: Text(
          '${round.courseName} — Round ${round.round.roundNumber}',
        ),
        subtitle: Text(formattedDate),
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
              key: ValueKey('scorecard_button_${round.round.id}'),
              icon: const Icon(Icons.scoreboard_outlined),
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
      return RoundsScreen._displayFormat.format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
