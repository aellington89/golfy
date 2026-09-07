import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models/event_stats.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../widgets/empty_state.dart';
import '../rounds/new_round_dialog.dart';
import '../rounds/round_row.dart';
import '../stats/score_color.dart';
import '../stats/score_format.dart';
import '../stats/stat_format.dart';
import 'delete_event.dart';
import 'edit_event_dialog.dart';
import 'edit_event_result_dialog.dart';
import 'event_result_badge.dart';
import 'event_result_format.dart';

enum _EventMenuAction { edit, delete }

/// Detail view for a single event (#42), pushed from the Events list and the
/// Rounds-tab event headers. Shows the event's result, a scoring summary, and
/// its rounds, with actions to add a round (event pre-selected), edit the
/// result, rename, or delete. Keyed by [eventId] and re-derived live from
/// [eventsStreamProvider], the keyed [roundsForEventProvider], and the keyed
/// [eventStatsStreamProvider], so edits elsewhere reflect here and a delete
/// collapses to a gone-state. Mirrors [ScorecardScreen], which is likewise
/// keyed by an id.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final int eventId;

  static Event? _findById(List<Event> events, int id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final roundsAsync = ref.watch(roundsForEventProvider(eventId));
    // The scoring card is DB-derived (#56); treat a not-yet-loaded aggregate as
    // "no data" so the card simply stays hidden until the first emission.
    final stats = ref.watch(eventStatsStreamProvider(eventId)).value ??
        EventStats.empty;

    return eventsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Failed to load event: $e')),
      ),
      data: (events) {
        final event = _findById(events, eventId);
        if (event == null) {
          // Deleted (here or elsewhere) — collapse to a simple gone-state.
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.event_busy_outlined,
              message: 'This event no longer exists.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(formatEventTitle(event)),
            actions: [
              PopupMenuButton<_EventMenuAction>(
                key: const ValueKey('event_detail_menu'),
                onSelected: (action) =>
                    _onMenuAction(context, ref, action, event, events),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _EventMenuAction.edit,
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: _EventMenuAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addRound(context, ref, event),
            icon: const Icon(Icons.add),
            label: const Text('Add round'),
          ),
          body: roundsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load rounds: $e')),
            data: (rounds) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  _ResultHeader(
                    event: event,
                    onEdit: () => showDialog<void>(
                      context: context,
                      builder: (_) => EditEventResultDialog(event: event),
                    ),
                  ),
                  if (stats.hasData) _EventStatsCard(stats: stats),
                  if (rounds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 32, 16, 16),
                      child: Text(
                        'No rounds in this event yet. '
                        'Tap "Add round" to add one.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final r in rounds) RoundRow(round: r),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onMenuAction(
    BuildContext context,
    WidgetRef ref,
    _EventMenuAction action,
    Event event,
    List<Event> events,
  ) async {
    switch (action) {
      case _EventMenuAction.edit:
        await showDialog<Event>(
          context: context,
          builder: (_) =>
              EditEventDialog(event: event, existingEvents: events),
        );
      case _EventMenuAction.delete:
        final count =
            ref.read(roundsForEventProvider(eventId)).value?.length ?? 0;
        final confirmed = await confirmDeleteEvent(
          context,
          eventName: formatEventTitle(event),
          roundCount: count,
        );
        if (!confirmed) return;
        await ref.read(repositoryProvider).deleteEvent(event.id);
        if (!context.mounted) return;
        Navigator.of(context).pop();
    }
  }

  Future<void> _addRound(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    // The dialog needs the FULL rounds list (not just this event's) for its
    // duplicate (date, course, round #) pre-check and auto round-numbering,
    // which are global concerns. The shell's IndexedStack keeps
    // roundsStreamProvider warm, so this one-time read is populated.
    final all = ref.read(roundsStreamProvider).value ??
        const <RoundWithCourse>[];
    final newId = await showDialog<int>(
      context: context,
      builder: (_) => NewRoundDialog(existingRounds: all, initialEvent: event),
    );
    // A started round switches the shell to Hole Entry underneath this pushed
    // screen; pop back so the user lands on it.
    if (newId != null && context.mounted) Navigator.of(context).pop();
  }
}

/// The event's result badge (or a "Not recorded" placeholder) with an
/// edit-result action. The action opens [EditEventResultDialog].
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.event, required this.onEdit});

  final Event event;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recorded = hasRecordedResult(event);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text('Result', style: theme.textTheme.titleMedium),
          const SizedBox(width: 12),
          if (recorded)
            EventResultBadge(event: event)
          else
            Text(
              'Not recorded',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          TextButton.icon(
            key: const ValueKey('event_detail_edit_result'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(recorded ? 'Edit' : 'Add'),
          ),
        ],
      ),
    );
  }
}

/// Per-event scoring summary card, styled to match the Dashboard's stat cards:
/// rounds scored, average score vs. par, and the best round. Sourced from the
/// DB-derived [EventStats] (#56); only shown when the event has at least one
/// scored round.
class _EventStatsCard extends StatelessWidget {
  const _EventStatsCard({required this.stats});

  final EventStats stats;

  static final _displayFormat = DateFormat.yMMMMd();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Colour the average to match its displayed value via the shared helper, so
    // this card agrees with the Dashboard and the Events list tiles.
    final avgColor = avgScoreVsParColor(stats.avgScoreVsPar, theme.colorScheme);
    final best = stats.bestRound;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event scoring', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _row(
              theme,
              'Rounds scored',
              '${stats.roundsScored}',
              valueKey: const ValueKey('event_stat_rounds'),
            ),
            _row(
              theme,
              'Avg score vs. par',
              formatSignedAverage(stats.avgScoreVsPar),
              valueKey: const ValueKey('event_stat_avg_vs_par'),
              color: avgColor,
            ),
            if (best != null)
              _row(
                theme,
                'Best round',
                formatRelativeToPar(best.toPar),
                valueKey: const ValueKey('event_stat_best'),
                color: scoreToParColor(best.toPar, theme.colorScheme),
                subtitle: '${best.courseName} · ${_formatDate(best.date)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    ThemeData theme,
    String label,
    String value, {
    Key? valueKey,
    Color? color,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            key: valueKey,
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
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
