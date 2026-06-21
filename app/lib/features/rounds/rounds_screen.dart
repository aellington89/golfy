import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../shell/tab_index_provider.dart';
import '../../widgets/empty_state.dart';
import '../events/edit_event_result_dialog.dart';
import '../events/event_result_format.dart';
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
          final items = _groupByEvent(rounds);
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return switch (item) {
                _EventHeaderItem(:final event) => _EventHeader(event: event),
                _RoundRowItem(:final round) => _RoundRow(round: round),
              };
            },
          );
        },
      ),
    );
  }

  Future<void> _openNewRoundDialog(
    BuildContext context,
    List<RoundWithCourse> rounds,
  ) async {
    // Distinct events currently attached to any round, for the dialog's
    // typeahead — derived from the same snapshot so the dialog keeps no live
    // stream dependency.
    final events = <int, Event>{};
    for (final r in rounds) {
      final e = r.event;
      if (e != null) events[e.id] = e;
    }
    await showDialog<int>(
      context: context,
      builder: (_) => NewRoundDialog(
        existingRounds: rounds,
        existingEvents: events.values.toList(),
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

/// One entry in the grouped rounds list: an [_EventHeaderItem] section header or
/// a [_RoundRowItem] round row. Flattening into these lets a single
/// [ListView.builder] render headers and rows together.
sealed class _RoundsListItem {
  const _RoundsListItem();
}

class _EventHeaderItem extends _RoundsListItem {
  const _EventHeaderItem(this.event);

  /// The event for this section, or `null` for the casual ("No event") group.
  final Event? event;
}

class _RoundRowItem extends _RoundsListItem {
  const _RoundRowItem(this.round);

  final RoundWithCourse round;
}

/// Flattens [rounds] (already newest-first) into header + row items grouped by
/// event. A group's position is fixed by its first-appearing round, which —
/// because the input is date-descending — orders groups by most-recent round
/// date; rounds stay date-descending within each group. Casual rounds (no
/// event) form a "No event" group, ordered amongst the rest the same way.
List<_RoundsListItem> _groupByEvent(List<RoundWithCourse> rounds) {
  final order = <int?>[];
  final groups = <int?, List<RoundWithCourse>>{};
  final eventByKey = <int?, Event?>{};
  for (final r in rounds) {
    final key = r.event?.id;
    if (!groups.containsKey(key)) {
      order.add(key);
      groups[key] = [];
      eventByKey[key] = r.event;
    }
    groups[key]!.add(r);
  }
  final items = <_RoundsListItem>[];
  for (final key in order) {
    items.add(_EventHeaderItem(eventByKey[key]));
    for (final r in groups[key]!) {
      items.add(_RoundRowItem(r));
    }
  }
  return items;
}

/// Section header for a group of rounds: the event name (or "No event" for
/// casual rounds), its recorded-result badge when present, and — for a real
/// event — an edit action that opens the [EditEventResultDialog].
class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.event});

  final Event? event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = this.event;
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          Icon(
            event == null
                ? Icons.golf_course_outlined
                : Icons.emoji_events_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event?.name ?? 'No event',
              key: event == null
                  ? const ValueKey('event_header_casual')
                  : ValueKey('event_header_${event.id}'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (event != null && hasRecordedResult(event)) ...[
            const SizedBox(width: 8),
            _ResultBadge(event: event),
          ],
          if (event != null)
            IconButton(
              key: ValueKey('event_result_edit_${event.id}'),
              icon: const Icon(Icons.edit_outlined),
              iconSize: 20,
              tooltip: 'Edit result',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EditEventResultDialog(event: event),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill showing an event's recorded result ("1st", "T-3", "Cut"). A win is
/// highlighted with the primary container; other placements use the secondary
/// container; a missed cut is a muted, outlined pill.
class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cut = event.missedCut;
    final isWin = !cut && !event.tied && event.finishPosition == 1;
    final Color bg;
    final Color fg;
    if (cut) {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant;
    } else if (isWin) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = scheme.secondaryContainer;
      fg = scheme.onSecondaryContainer;
    }
    return Container(
      key: ValueKey('event_result_badge_${event.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: cut ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Text(
        formatEventResult(event),
        style: theme.textTheme.labelMedium
            ?.copyWith(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
