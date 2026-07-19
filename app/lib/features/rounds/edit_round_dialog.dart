import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../courses/course_picker.dart';
import '../events/event_picker.dart';

/// Modal dialog for editing an existing round's details (#45): its course,
/// event, date, round number and notes. Mirrors [NewRoundDialog]'s form — the
/// same [CoursePicker], [EventPicker] and round-number stepper — but writes an
/// UPDATE via the repository's `updateRound` and, on confirm, simply pops.
/// The rounds stream re-emits on its own, so the list regroups under the new
/// event automatically. Cancel pops and leaves the round untouched.
///
/// This is how a round created without an event gets one attached (and how a
/// wrong course / date / round number is corrected) without deleting and
/// re-creating the round — its hole_results are preserved across the edit.
///
/// Like [NewRoundDialog], the caller supplies the rounds / courses snapshots so
/// the dialog has no live stream dependency for those, keeping widget tests
/// free of pending timers; the event list comes live from [eventsStreamProvider]
/// via the [EventPicker]. Two edit-specific differences from New Round:
///   * the round number is *not* auto-recomputed when course / date change —
///     the round keeps its existing number unless the user steps it; and
///   * the duplicate `(date, courseId, roundNumber)` pre-check excludes the
///     round being edited, so a round never collides with itself.
class EditRoundDialog extends ConsumerStatefulWidget {
  const EditRoundDialog({
    super.key,
    required this.round,
    this.existingRounds = const [],
    this.existingCourses = const [],
  });

  /// The round being edited, with its current course name and optional event.
  final RoundWithCourse round;

  final List<RoundWithCourse> existingRounds;

  /// Snapshot of existing courses, used to resolve the round's current
  /// [Course] for the [CoursePicker]'s initial value ([RoundWithCourse] only
  /// carries the course *name*, but the picker needs the row).
  final List<Course> existingCourses;

  @override
  ConsumerState<EditRoundDialog> createState() => _EditRoundDialogState();
}

class _EditRoundDialogState extends ConsumerState<EditRoundDialog> {
  late final TextEditingController _notesController;

  /// Currently-selected event, or `null` for a casual round. Seeded from the
  /// round's current event; its id is written to the round on submit.
  Event? _event;

  Course? _course;
  late DateTime _date;
  late int _roundNumber;
  bool _submitting = false;
  String? _courseError;
  String? _roundNumberError;

  static final _displayFormat = DateFormat.yMMMMd();
  static final _isoFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final r = widget.round;
    _course = _courseFor(r.round.courseId);
    _event = r.event;
    _date = DateTime.tryParse(r.round.date) ?? DateTime.now();
    _roundNumber = r.round.roundNumber;
    _notesController = TextEditingController(text: r.round.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Resolves the round's stored course id to a [Course] from the injected
  /// snapshot, so the picker opens pre-selected. Returns null if the snapshot
  /// somehow lacks it (the picker then shows "Select a course").
  Course? _courseFor(int courseId) {
    for (final c in widget.existingCourses) {
      if (c.id == courseId) return c;
    }
    return null;
  }

  String get _isoDate => _isoFormat.format(_date);

  void _onCourseChanged(Course? course) {
    setState(() {
      _course = course;
      _courseError = null;
      _roundNumberError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _roundNumberError = null;
    });
  }

  void _incrementRoundNumber() {
    setState(() {
      _roundNumber += 1;
      _roundNumberError = null;
    });
  }

  void _decrementRoundNumber() {
    if (_roundNumber <= 1) return;
    setState(() {
      _roundNumber -= 1;
      _roundNumberError = null;
    });
  }

  /// True if another round (not this one) already occupies this
  /// `(date, courseId, roundNumber)` triple.
  bool _isDuplicate(int courseId) {
    final selfId = widget.round.round.id;
    return widget.existingRounds.any((r) =>
        r.round.id != selfId &&
        r.round.courseId == courseId &&
        r.round.date == _isoDate &&
        r.round.roundNumber == _roundNumber);
  }

  Future<void> _submit() async {
    final course = _course;
    if (course == null) {
      setState(() => _courseError = 'Course is required');
      return;
    }
    if (_isDuplicate(course.id)) {
      setState(() => _roundNumberError =
          'A round with this course, date, and round number already exists');
      return;
    }

    setState(() {
      _submitting = true;
      _roundNumberError = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final eventId = _event?.id;
      final notes = _notesController.text.trim();
      final companion = RoundsCompanion(
        date: Value(_isoDate),
        courseId: Value(course.id),
        roundNumber: Value(_roundNumber),
        // Value(null) explicitly clears the event when "No event" is chosen.
        eventId: Value(eventId),
        notes: Value(notes.isEmpty ? null : notes),
      );
      await repo.updateRound(widget.round.round.id, companion);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _roundNumberError =
            'A round with this course, date, and round number already exists';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Edit Round'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoursePicker(
              value: _course,
              onChanged: _submitting ? (_) {} : _onCourseChanged,
            ),
            if (_courseError != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  _courseError!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 12),
            EventPicker(
              value: _event,
              onChanged: _submitting
                  ? (_) {}
                  : (e) => setState(() => _event = e),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _submitting ? null : _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_displayFormat.format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Round number',
                border: const OutlineInputBorder(),
                errorText: _roundNumberError,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('round_number_dec'),
                    onPressed: _submitting || _roundNumber <= 1
                        ? null
                        : _decrementRoundNumber,
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$_roundNumber',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('round_number_inc'),
                    onPressed: _submitting ? null : _incrementRoundNumber,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('edit_round_save'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Opens [EditRoundDialog] for [round], gathering the rounds / courses
/// snapshots it needs. Shared by the rounds-list row and the scorecard so both
/// entry points behave identically. Awaits the courses list first so the
/// [CoursePicker] opens pre-selected on the round's current course. (The event
/// list is sourced live by the [EventPicker] from [eventsStreamProvider].)
Future<void> openEditRoundDialog(
  BuildContext context,
  WidgetRef ref,
  RoundWithCourse round,
) async {
  final repo = ref.read(repositoryProvider);
  final rounds = ref.read(roundsStreamProvider).value ?? const [];
  final courses = await repo.watchCoursesByName().first;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => EditRoundDialog(
      round: round,
      existingRounds: rounds,
      existingCourses: courses,
    ),
  );
}
