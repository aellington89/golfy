import 'package:flutter/material.dart';

import '../../data/database.dart';
import 'event_result_format.dart';

/// Pill showing an event's recorded result ("1st", "T-3", "Cut"). A win is
/// highlighted with the primary container; other placements use the secondary
/// container; a missed cut is a muted, outlined pill. Shared by the Rounds-tab
/// event headers, the Events list, and the event detail header so every result
/// badge reads identically. Callers gate on [hasRecordedResult] before showing
/// one — a not-recorded event has no badge.
class EventResultBadge extends StatelessWidget {
  const EventResultBadge({super.key, required this.event});

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
