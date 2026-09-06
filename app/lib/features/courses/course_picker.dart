import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';
import 'add_course_dialog.dart';
import 'courses_screen.dart';

/// Controlled course picker: parent owns the selected [Course] and supplies
/// [value] + [onChanged]. Tapping the field opens a modal sheet listing all
/// courses (sorted alphabetically by name); the last entry is
/// "+ Add new course…" which launches [AddCourseDialog] and selects the
/// newly-created course on success.
class CoursePicker extends ConsumerWidget {
  const CoursePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Course',
  });

  final Course? value;
  final ValueChanged<Course?> onChanged;
  final String labelText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesByNameStreamProvider);
    final theme = Theme.of(context);

    final field = InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: Text(
        value?.name ?? 'Select a course',
        style: value == null
            ? theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
            : theme.textTheme.bodyLarge,
      ),
    );

    return coursesAsync.when(
      loading: () => AbsorbPointer(child: field),
      error: (e, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          'Could not load courses',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      data: (courses) => InkWell(
        onTap: () => _openPicker(context, courses),
        borderRadius: BorderRadius.circular(4),
        child: field,
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, List<Course> courses) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CoursePickerSheet(
        courses: courses,
        selectedId: value?.id,
      ),
    );

    if (result == null) return;

    if (result.manage) {
      if (!context.mounted) return;
      // Push over the current route (including the New/Edit Round dialog this
      // picker sits in) — the dialog is still there on return, and reopening
      // the picker re-reads the (now-updated) course list from its stream.
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => const CoursesScreen()),
      );
      return;
    }

    if (result.addNew) {
      if (!context.mounted) return;
      final newCourse = await showDialog<Course>(
        context: context,
        builder: (_) => AddCourseDialog(existingCourses: courses),
      );
      if (newCourse != null) onChanged(newCourse);
      return;
    }

    onChanged(result.course);
  }
}

class _PickerResult {
  const _PickerResult.course(this.course)
      : addNew = false,
        manage = false;
  const _PickerResult.addNew()
      : course = null,
        addNew = true,
        manage = false;
  const _PickerResult.manage()
      : course = null,
        addNew = false,
        manage = true;

  final Course? course;
  final bool addNew;
  final bool manage;
}

class _CoursePickerSheet extends StatelessWidget {
  const _CoursePickerSheet({
    required this.courses,
    required this.selectedId,
  });

  final List<Course> courses;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (courses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No courses yet — add one below.'),
            ),
          for (final c in courses)
            ListTile(
              title: Text(c.name),
              subtitle: Text(c.gameTitle),
              trailing: c.id == selectedId ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.of(context).pop(_PickerResult.course(c)),
            ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add new course…'),
            onTap: () =>
                Navigator.of(context).pop(const _PickerResult.addNew()),
          ),
          ListTile(
            leading: const Icon(Icons.golf_course_outlined),
            title: const Text('Manage courses…'),
            onTap: () =>
                Navigator.of(context).pop(const _PickerResult.manage()),
          ),
        ],
      ),
    );
  }
}
