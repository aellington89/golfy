import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';
import '../courses/course_hole_card.dart';

/// Edits one hole of the course template without leaving the round (#81).
///
/// Renders the same [CourseHoleCard] the course editor uses — one widget, two
/// hosts — so correcting a course mid-round looks and behaves like setting it up
/// beforehand. It is also the only place stroke index can be entered while
/// playing: the round form has no home for it.
///
/// Writes a single hole rather than replacing the course card, so holes the
/// player hasn't reached yet are untouched.
Future<void> showCourseTemplateSheet(
  BuildContext context,
  WidgetRef ref, {
  required int courseId,
  required int holeNumber,
  required int par,
  int? strokeIndex,
  int? yards,
  int? courseSetId,
  String? setName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CourseTemplateSheet(
      courseId: courseId,
      holeNumber: holeNumber,
      par: par,
      strokeIndex: strokeIndex,
      yards: yards,
      courseSetId: courseSetId,
      setName: setName,
    ),
  );
}

class _CourseTemplateSheet extends ConsumerStatefulWidget {
  const _CourseTemplateSheet({
    required this.courseId,
    required this.holeNumber,
    required this.par,
    required this.strokeIndex,
    required this.yards,
    required this.courseSetId,
    required this.setName,
  });

  final int courseId;
  final int holeNumber;
  final int par;
  final int? strokeIndex;
  final int? yards;
  final int? courseSetId;
  final String? setName;

  @override
  ConsumerState<_CourseTemplateSheet> createState() =>
      _CourseTemplateSheetState();
}

class _CourseTemplateSheetState extends ConsumerState<_CourseTemplateSheet> {
  late int _par = widget.par;
  late int? _si = widget.strokeIndex;
  late int _yards = widget.yards ?? 0;
  bool _saving = false;

  Future<void> _save() async {
    final si = _si;
    if (si != null && (si < 1 || si > 18)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stroke index must be 1–18')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    try {
      await repo.upsertCourseHole(CourseHolesCompanion.insert(
        courseId: widget.courseId,
        holeNumber: widget.holeNumber,
        par: _par,
        strokeIndex: Value(_si),
      ));
      final setId = widget.courseSetId;
      if (setId != null) {
        await repo.upsertCourseSetYard(CourseSetYardsCompanion.insert(
          courseSetId: setId,
          holeNumber: widget.holeNumber,
          yards: _yards,
        ));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Course updated for hole ${widget.holeNumber}'),
          duration: const Duration(seconds: 1),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSet = widget.courseSetId != null;
    final setLabel = widget.setName ?? 'this set';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Course template',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            hasSet
                ? 'Saved on the course, not this round — future rounds start '
                    'from these values. Par and stroke index apply to every '
                    'yardage set; only the yardage belongs to $setLabel.'
                : 'This round has no yardage set, so only par and stroke index '
                    'can be saved — and those apply to every set.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          CourseHoleCard(
            holeNumber: widget.holeNumber,
            par: _par,
            strokeIndex: _si,
            yards: hasSet ? _yards : null,
            setName: widget.setName,
            showStatus: false,
            onParChanged: (v) => setState(() => _par = v),
            onStrokeIndexChanged: (v) => setState(() => _si = v),
            onYardsChanged: hasSet ? (v) => setState(() => _yards = v) : null,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('save_course_template_hole'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Save to course'),
          ),
        ],
      ),
    );
  }
}
