import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../shell/tab_index_provider.dart';
import '../courses/course_picker.dart';
import '../events/event_picker.dart';
import 'active_round_provider.dart';

/// Modal dialog for starting a new round. On confirm, inserts a `rounds`
/// row, sets [activeRoundIdProvider] to the new id, switches the shell to
/// the Hole Entry tab, and pops with the new round id. Cancel pops with
/// `null` and leaves all state untouched.
///
/// Optionally associates the round with an event (#35): the Event field is an
/// [EventPicker] (mirroring [CoursePicker]) — pick an existing event, choose
/// "No event / Casual round" to leave it casual, or create one via
/// "Add new event…". No event is selected by default, unless [initialEvent] is
/// supplied (e.g. opened from an event's detail screen), which pre-selects it.
///
/// Validates that a course is selected, pre-checks [existingRounds] for a
/// duplicate `(date, courseId, roundNumber)` triple, and catches the
/// DB-level UNIQUE constraint as a safety net for the rare race.
/// The caller supplies the rounds snapshot so the dialog has no live stream
/// dependency for the duplicate pre-check — that keeps widget tests free of
/// pending timers. The event list is sourced live from [eventsStreamProvider]
/// via the [EventPicker] (overridden with a manual stream in tests).
class NewRoundDialog extends ConsumerStatefulWidget {
  const NewRoundDialog({
    super.key,
    this.existingRounds = const [],
    this.initialEvent,
  });

  final List<RoundWithCourse> existingRounds;

  /// Event to pre-select in the [EventPicker], or `null` to start with no
  /// event (the default). Set when starting a round from an event's detail
  /// screen.
  final Event? initialEvent;

  @override
  ConsumerState<NewRoundDialog> createState() => _NewRoundDialogState();
}

class _NewRoundDialogState extends ConsumerState<NewRoundDialog> {
  final _notesController = TextEditingController();

  /// Currently-selected event, or `null` for a casual round. Set by the
  /// [EventPicker]; its id is written straight to the round on submit.
  Event? _event;

  Course? _course;

  /// The chosen yardage set for [_course] (#36), or null for "no set" — Hole
  /// Entry pre-fills yardages from it. Reset whenever the course changes.
  CourseSet? _courseSet;

  late DateTime _date;
  int _roundNumber = 1;
  bool _userOverrodeRoundNumber = false;
  bool _submitting = false;
  String? _courseError;
  String? _roundNumberError;

  static final _displayFormat = DateFormat.yMMMMd();
  static final _isoFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _event = widget.initialEvent;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String get _isoDate => _isoFormat.format(_date);

  int _autoRoundNumber(int courseId, String isoDate) {
    var max = 0;
    for (final r in widget.existingRounds) {
      if (r.round.courseId == courseId && r.round.date == isoDate) {
        if (r.round.roundNumber > max) max = r.round.roundNumber;
      }
    }
    return max + 1;
  }

  void _recomputeRoundNumber() {
    if (_userOverrodeRoundNumber) return;
    final c = _course;
    if (c == null) {
      _roundNumber = 1;
      return;
    }
    _roundNumber = _autoRoundNumber(c.id, _isoDate);
  }

  void _onCourseChanged(Course? course) {
    setState(() {
      _course = course;
      // A set belongs to a course, so it can't survive a course change.
      _courseSet = null;
      _courseError = null;
      _roundNumberError = null;
      _recomputeRoundNumber();
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
      _recomputeRoundNumber();
    });
  }

  void _incrementRoundNumber() {
    setState(() {
      _roundNumber += 1;
      _userOverrodeRoundNumber = true;
      _roundNumberError = null;
    });
  }

  void _decrementRoundNumber() {
    if (_roundNumber <= 1) return;
    setState(() {
      _roundNumber -= 1;
      _userOverrodeRoundNumber = true;
      _roundNumberError = null;
    });
  }

  bool _isDuplicate(int courseId) {
    return widget.existingRounds.any((r) =>
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
      final courseSetId = _courseSet?.id;
      final companion = RoundsCompanion.insert(
        date: _isoDate,
        courseId: course.id,
        roundNumber: Value(_roundNumber),
        eventId: eventId == null ? const Value.absent() : Value(eventId),
        courseSetId:
            courseSetId == null ? const Value.absent() : Value(courseSetId),
        notes: notes.isEmpty ? const Value.absent() : Value(notes),
      );
      final newId = await repo.insertRound(companion);
      if (!mounted) return;
      ref.read(activeRoundIdProvider.notifier).set(newId);
      ref.read(tabIndexProvider.notifier).set(ShellTabs.holeEntry);
      Navigator.of(context).pop(newId);
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
      title: const Text('New Round'),
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
            if (_course != null) ...[
              const SizedBox(height: 12),
              _SetPicker(
                courseId: _course!.id,
                value: _courseSet,
                onChanged: _submitting
                    ? (_) {}
                    : (s) => setState(() => _courseSet = s),
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
          onPressed: _submitting ? null : _submit,
          child: const Text('Start Round'),
        ),
      ],
    );
  }
}

/// Controlled dropdown of a course's yardage sets (#36) — the parent owns the
/// selected [CourseSet]. Always offers a "No set" choice (leaves the round's
/// yardages blank); when the course has no sets, that's the only option, with a
/// hint to add one on the course. Sourced live from [courseSetsStreamProvider].
class _SetPicker extends ConsumerWidget {
  const _SetPicker({
    required this.courseId,
    required this.value,
    required this.onChanged,
  });

  final int courseId;
  final CourseSet? value;
  final ValueChanged<CourseSet?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(courseSetsStreamProvider(courseId));
    return setsAsync.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Yardage set',
          border: OutlineInputBorder(),
        ),
        child: Text('Loading sets…'),
      ),
      error: (e, _) => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Yardage set',
          border: OutlineInputBorder(),
        ),
        child: Text('Could not load sets'),
      ),
      data: (sets) {
        // The selected set may have been deleted; fall back to "No set".
        final selectedId =
            sets.any((s) => s.id == value?.id) ? value?.id : null;
        return DropdownButtonFormField<int?>(
          key: const ValueKey('set_picker'),
          initialValue: selectedId,
          decoration: InputDecoration(
            labelText: 'Yardage set',
            border: const OutlineInputBorder(),
            helperText: sets.isEmpty
                ? 'No sets yet — add one on the course to pre-fill yardages'
                : null,
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('No set'),
            ),
            for (final s in sets)
              DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
          ],
          onChanged: (id) => onChanged(
            id == null ? null : sets.firstWhere((s) => s.id == id),
          ),
        );
      },
    );
  }
}
