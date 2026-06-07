import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// Modal dialog for adding a new course. Pops with the newly-inserted
/// [Course] on success, or `null` if the user cancels.
///
/// Validates Name + Game Title are non-empty and pre-checks
/// [existingCourses] for a duplicate `(name, gameTitle)` pair; the DB-level
/// UNIQUE constraint is still caught as a safety net for the rare race.
/// The caller supplies the list so the dialog has no live stream
/// dependency — that keeps widget tests free of pending stream timers.
class AddCourseDialog extends ConsumerStatefulWidget {
  const AddCourseDialog({super.key, this.existingCourses = const []});

  final List<Course> existingCourses;

  @override
  ConsumerState<AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends ConsumerState<AddCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gameTitleController = TextEditingController();
  String? _nameError;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _gameTitleController.dispose();
    super.dispose();
  }

  void _clearNameError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();
    final gameTitle = _gameTitleController.text.trim();

    final isDuplicate = widget.existingCourses.any((c) =>
        c.name.toLowerCase() == name.toLowerCase() &&
        c.gameTitle.toLowerCase() == gameTitle.toLowerCase());
    if (isDuplicate) {
      setState(() => _nameError = 'Course already exists');
      return;
    }

    setState(() {
      _submitting = true;
      _nameError = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final id = await repo.insertCourse(
        CoursesCompanion.insert(name: name, gameTitle: gameTitle),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        Course(id: id, name: name, gameTitle: gameTitle),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _nameError = 'Course already exists';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Course'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Course Name',
                errorText: _nameError,
              ),
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (_) => _clearNameError(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gameTitleController,
              decoration: const InputDecoration(labelText: 'Game Title'),
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (_) => _clearNameError(),
              onFieldSubmitted: (_) => _submit(),
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}
