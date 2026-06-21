import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository.dart';
import '../../data/repository_provider.dart';
import '../../shell/tab_index_provider.dart';
import '../courses/course_picker.dart';
import 'active_round_provider.dart';

/// Modal dialog for starting a new round. On confirm, inserts a `rounds`
/// row, sets [activeRoundIdProvider] to the new id, switches the shell to
/// the Hole Entry tab, and pops with the new round id. Cancel pops with
/// `null` and leaves all state untouched.
///
/// Optionally associates the round with an event (#35): the Event field is a
/// typeahead over [existingEvents]; picking one links the round to it, a
/// brand-new typed name creates an event on submit, and an empty field leaves
/// the round casual (no event).
///
/// Validates that a course is selected, pre-checks [existingRounds] for a
/// duplicate `(date, courseId, roundNumber)` triple, and catches the
/// DB-level UNIQUE constraint as a safety net for the rare race.
/// The caller supplies the rounds + events snapshots so the dialog has no live
/// stream dependency — that keeps widget tests free of pending timers.
class NewRoundDialog extends ConsumerStatefulWidget {
  const NewRoundDialog({
    super.key,
    this.existingRounds = const [],
    this.existingEvents = const [],
  });

  final List<RoundWithCourse> existingRounds;

  /// Snapshot of existing events for the Event typeahead — passed in (rather
  /// than watched) so the dialog keeps no live stream dependency, mirroring
  /// [existingRounds].
  final List<Event> existingEvents;

  @override
  ConsumerState<NewRoundDialog> createState() => _NewRoundDialogState();
}

class _NewRoundDialogState extends ConsumerState<NewRoundDialog> {
  final _notesController = TextEditingController();

  /// Current text of the Event typeahead. Resolved to an event id on submit
  /// (matched against [widget.existingEvents] or inserted as a new event).
  String _eventText = '';

  Course? _course;
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
      // Resolved after the duplicate pre-check above so a rejected round never
      // leaves an orphan event behind.
      final eventId = await _resolveEventId(repo);
      final notes = _notesController.text.trim();
      final companion = RoundsCompanion.insert(
        date: _isoDate,
        courseId: course.id,
        roundNumber: Value(_roundNumber),
        eventId: eventId == null ? const Value.absent() : Value(eventId),
        notes: notes.isEmpty ? const Value.absent() : Value(notes),
      );
      final newId = await repo.insertRound(companion);
      if (!mounted) return;
      ref.read(activeRoundIdProvider.notifier).set(newId);
      ref.read(tabIndexProvider.notifier).set(1);
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

  /// Resolves the typed event name to an event id: empty -> `null` (casual);
  /// an existing name (case-insensitive) -> its id; a new name -> a freshly
  /// inserted event.
  Future<int?> _resolveEventId(GolfyRepository repo) async {
    final name = _eventText.trim();
    if (name.isEmpty) return null;
    for (final e in widget.existingEvents) {
      if (e.name.toLowerCase() == name.toLowerCase()) return e.id;
    }
    return repo.insertEvent(EventsCompanion.insert(name: name));
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
            const SizedBox(height: 12),
            Autocomplete<Event>(
              displayStringForOption: (e) => e.name,
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                if (query.isEmpty) return widget.existingEvents;
                return widget.existingEvents.where(
                  (e) => e.name.toLowerCase().contains(query),
                );
              },
              onSelected: (e) => _eventText = e.name,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  key: const ValueKey('event_field'),
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Event (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Pick an existing event or type a new one',
                  ),
                  enabled: !_submitting,
                  textInputAction: TextInputAction.next,
                  onChanged: (v) => _eventText = v,
                );
              },
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
