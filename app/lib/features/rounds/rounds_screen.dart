import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import 'active_round_provider.dart';
import 'new_round_dialog.dart';

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
          if (rounds.isEmpty) return const _EmptyState();
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'No rounds yet. Tap + to start your first round.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
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
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        final repo = ref.read(repositoryProvider);
        final activeId = ref.read(activeRoundIdProvider);
        await repo.deleteRound(round.round.id);
        if (activeId == round.round.id) {
          ref.read(activeRoundIdProvider.notifier).clear();
        }
      },
      child: ListTile(
        title: Text(
          '${round.courseName} — Round ${round.round.roundNumber}',
        ),
        subtitle: Text(formattedDate),
        trailing: Text(
          '${round.holesEntered}/18',
          style: theme.textTheme.bodyMedium,
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

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete round?'),
        content: Text(
          'This will permanently delete the round at ${round.courseName} '
          'and any hole data entered for it.',
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
  }
}
