import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../widgets/empty_state.dart';
import '../events/edit_event_result_dialog.dart';
import '../events/event_detail_screen.dart';
import '../events/event_result_badge.dart';
import '../events/event_result_format.dart';
import 'new_round_dialog.dart';
import 'round_row.dart';

class RoundsScreen extends ConsumerWidget {
  const RoundsScreen({super.key});

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
                _RoundRowItem(:final round) => RoundRow(round: round),
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
    await showDialog<int>(
      context: context,
      builder: (_) => NewRoundDialog(existingRounds: rounds),
    );
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
/// event — an edit action that opens the [EditEventResultDialog]. For a real
/// event the name/badge area also taps through to the [EventDetailScreen]; the
/// edit-result button stays separate so its tap isn't swallowed.
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
          Expanded(
            child: event == null
                ? _content(theme, null)
                : InkWell(
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EventDetailScreen(eventId: event.id),
                      ),
                    ),
                    child: _content(theme, event),
                  ),
          ),
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

  /// The icon + name (+ result badge) row shared by the casual and real-event
  /// headers. Extracted so only the real-event variant is wrapped in the
  /// tap-through [InkWell].
  Widget _content(ThemeData theme, Event? event) {
    return Row(
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
          EventResultBadge(event: event),
        ],
      ],
    );
  }
}
