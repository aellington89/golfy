import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../shell/tab_index_provider.dart';
import '../courses/add_set_dialog.dart';
import '../courses/course_template.dart';
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

  /// The chosen tee set and pin set for [_course] — together the round's
  /// yardage set — each null for none. Hole Entry pre-fills each hole's yards
  /// from them: tee-to-pin with both, course yards with a tee set alone. Reset
  /// whenever the course changes.
  int? _teeSetId;
  int? _pinSetId;

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
      // Sets belong to a course, so they can't survive a course change.
      _teeSetId = null;
      _pinSetId = null;
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
      final companion = RoundsCompanion.insert(
        date: _isoDate,
        courseId: course.id,
        roundNumber: Value(_roundNumber),
        eventId: eventId == null ? const Value.absent() : Value(eventId),
        teeSetId: Value(_teeSetId),
        pinSetId: Value(_pinSetId),
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
                kind: CourseSetKind.tee,
                courseId: _course!.id,
                valueId: _teeSetId,
                onChanged: _submitting
                    ? (_) {}
                    : (id) => setState(() => _teeSetId = id),
              ),
              const SizedBox(height: 12),
              _SetPicker(
                kind: CourseSetKind.pin,
                courseId: _course!.id,
                valueId: _pinSetId,
                onChanged: _submitting
                    ? (_) {}
                    : (id) => setState(() => _pinSetId = id),
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

/// Sentinel for a picker's "Add new …" row; no real set id is negative.
const int _addNewSetSentinel = -1;

/// Controlled dropdown of a course's tee sets or pin sets — the parent owns
/// the selected id. Always offers a "No tee set" / "No pin set" choice; when
/// the course has none, that's the only option, with a hint. Sourced live from
/// [teeSetsStreamProvider] or [pinSetsStreamProvider].
class _SetPicker extends ConsumerWidget {
  const _SetPicker({
    required this.kind,
    required this.courseId,
    required this.valueId,
    required this.onChanged,
  });

  final CourseSetKind kind;
  final int courseId;
  final int? valueId;
  final ValueChanged<int?> onChanged;

  String get _label => switch (kind) {
        CourseSetKind.tee => 'Tee set',
        CourseSetKind.pin => 'Pin set',
      };

  /// Creates a set and selects it.
  ///
  /// Unlike the course editor — which stages a copied tee set's course yards
  /// as unsaved changes for review — a copy made here is written immediately:
  /// there is no editor open to hold it, and the alternative is starting the
  /// round against a tee set with no yards at all. A set created blank is
  /// still useful: "Update course as I play" fills it in hole by hole as the
  /// round is entered.
  Future<void> _createSet(
    BuildContext context,
    WidgetRef ref,
    List<ExistingSet> existing,
  ) async {
    final spec = await showDialog<NewCourseSet>(
      context: context,
      builder: (_) => AddSetDialog(kind: kind, existing: existing),
    );
    if (spec == null) return;
    final repo = ref.read(repositoryProvider);
    try {
      final int id;
      switch (kind) {
        case CourseSetKind.tee:
          id = await repo.insertTeeSet(
            TeeSetsCompanion.insert(courseId: courseId, name: spec.name),
          );
          final source = spec.copyFromSetId;
          if (source != null) {
            final rows = await repo.getCourseYards(source);
            final byHole = {for (final y in rows) y.holeNumber: y.yards};
            final yards = applyYardOffset(
              [for (var h = 1; h <= 18; h++) byHole[h] ?? 0],
              spec.offsetYards,
            );
            await repo.replaceCourseYards(id, [
              for (var h = 1; h <= 18; h++)
                CourseYardsCompanion.insert(
                  teeSetId: id,
                  holeNumber: h,
                  yards: yards[h - 1],
                ),
            ]);
          }
        case CourseSetKind.pin:
          id = await repo.insertPinSet(
            PinSetsCompanion.insert(courseId: courseId, name: spec.name),
          );
      }
      onChanged(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A ${kind.noun} named "${spec.name}" already exists'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = switch (kind) {
      CourseSetKind.tee => ref.watch(teeSetsStreamProvider(courseId)).whenData(
          (sets) => [for (final s in sets) (id: s.id, name: s.name)]),
      CourseSetKind.pin => ref.watch(pinSetsStreamProvider(courseId)).whenData(
          (sets) => [for (final s in sets) (id: s.id, name: s.name)]),
    };
    return setsAsync.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(
          labelText: _label,
          border: const OutlineInputBorder(),
        ),
        child: const Text('Loading sets…'),
      ),
      error: (e, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: _label,
          border: const OutlineInputBorder(),
        ),
        child: const Text('Could not load sets'),
      ),
      data: (sets) {
        // The selected set may have been deleted; fall back to none.
        final selectedId =
            sets.any((s) => s.id == valueId) ? valueId : null;
        return DropdownButtonFormField<int?>(
          key: ValueKey('${kind.name}_set_picker'),
          initialValue: selectedId,
          decoration: InputDecoration(
            labelText: _label,
            border: const OutlineInputBorder(),
            helperText: sets.isEmpty
                ? switch (kind) {
                    CourseSetKind.tee =>
                      'No tee sets yet — add one to pre-fill this round’s '
                          'yardages',
                    CourseSetKind.pin =>
                      'No pin sets yet — without one, holes pre-fill with the '
                          'tee set’s course yards',
                  }
                : null,
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('No ${kind.noun}'),
            ),
            for (final s in sets)
              DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
            // Mirrors the "Add new…" affordance on the course and event
            // pickers: a set you have not recorded yet shouldn't send you out
            // of the dialog to the course editor and back.
            DropdownMenuItem<int?>(
              value: _addNewSetSentinel,
              child: Text('Add new ${kind.noun}…'),
            ),
          ],
          onChanged: (id) {
            if (id == _addNewSetSentinel) {
              _createSet(context, ref, sets);
              return;
            }
            onChanged(id);
          },
        );
      },
    );
  }
}
