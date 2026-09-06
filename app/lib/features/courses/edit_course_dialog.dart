import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// Modal dialog for editing a [course]'s identity — its **name** and **game
/// title** (#36). Pops with the updated [Course] on success, or `null` if the
/// user cancels. Mirrors [AddCourseDialog] / [EditEventDialog].
///
/// A course is identified by `(name, gameTitle)`, so both are editable. Validates
/// both are non-empty and pre-checks [existingCourses] for another course
/// sharing the new pair (case-insensitive, excluding this one); the schema-level
/// UNIQUE(name, game_title) is still caught as a safety net for the rare race.
/// The caller supplies the list so the dialog has no live stream dependency —
/// keeping widget tests free of pending stream timers.
class EditCourseDialog extends ConsumerStatefulWidget {
  const EditCourseDialog({
    super.key,
    required this.course,
    this.existingCourses = const [],
  });

  final Course course;
  final List<Course> existingCourses;

  @override
  ConsumerState<EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends ConsumerState<EditCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _gameTitleController;
  String? _nameError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.course.name);
    _gameTitleController = TextEditingController(text: widget.course.gameTitle);
  }

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

    // Nothing changed — don't touch the db; close with the original course.
    if (name == widget.course.name && gameTitle == widget.course.gameTitle) {
      Navigator.of(context).pop(widget.course);
      return;
    }

    final isDuplicate = widget.existingCourses.any((c) =>
        c.id != widget.course.id &&
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
      await ref.read(repositoryProvider).updateCourse(
            widget.course.id,
            CoursesCompanion(name: Value(name), gameTitle: Value(gameTitle)),
          );
      if (!mounted) return;
      Navigator.of(context).pop(
        widget.course.copyWith(name: name, gameTitle: gameTitle),
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
      title: const Text('Edit Course'),
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
          key: const ValueKey('edit_course_save'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
