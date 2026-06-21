// Presentation helpers for an [Event]'s recorded result (#35). Kept widget-free
// and outside the data layer (mirrors features/stats/score_format.dart) so the
// grouped rounds list — and any later events UI — format results identically and
// unit-test without pumping a widget.

import '../../data/database.dart';

/// Formats an event's recorded result for a badge:
///   * missed cut    -> `"Cut"`
///   * a position     -> `"1st"` / `"2nd"` / …, tie-prefixed as `"T-3"`
///   * not recorded   -> `"—"` (em dash, matching the dashboard's no-data style)
String formatEventResult(Event event) {
  if (event.missedCut) return 'Cut';
  final position = event.finishPosition;
  if (position == null) return '—';
  return event.tied ? 'T-$position' : ordinal(position);
}

/// Whether [event] has a result worth showing as a badge (i.e. it is not in the
/// "not recorded yet" state). Lets the UI hide the badge entirely rather than
/// render an em dash where that would read oddly.
bool hasRecordedResult(Event event) =>
    event.missedCut || event.finishPosition != null;

/// English ordinal for a 1-based position: `1 -> "1st"`, `2 -> "2nd"`,
/// `3 -> "3rd"`, `4 -> "4th"`, the `11/12/13 -> "11th/12th/13th"` exceptions,
/// `21 -> "21st"`, and so on.
String ordinal(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
