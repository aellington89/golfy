import 'package:flutter/material.dart';

/// Shows the delete-course dialog and resolves to whether the caller should
/// proceed with the delete.
///
/// A course can only be deleted when **no round references it** — the
/// `rounds.course_id` foreign key is RESTRICT (unlike events, whose rounds are
/// detached). So when [roundCount] > 0 this shows an *informational* dialog
/// (single "OK", no delete) and resolves `false`; the round data must be moved
/// or removed first. When there are no rounds it shows a normal confirm and
/// resolves `true` on Delete. Deleting cascades the course's saved hole card.
Future<bool> confirmDeleteCourse(
  BuildContext context, {
  required String courseName,
  required int roundCount,
}) async {
  if (roundCount > 0) {
    final rounds = roundCount == 1 ? '1 round' : '$roundCount rounds';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Can't delete course"),
        content: Text(
          '"$courseName" has $rounds. Delete or move those rounds to another '
          'course first, then delete the course.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete course?'),
      content: Text(
        'This will delete "$courseName" and its saved hole card. It has no '
        'rounds, so no round or hole data is affected.',
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
