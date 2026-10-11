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
  int? teeSetId,
  String? teeSetName,
  int courseYards = 0,
  int? pinSetId,
  String? pinSetName,
  int teeToPinYards = 0,
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
      teeSetId: teeSetId,
      teeSetName: teeSetName,
      courseYards: courseYards,
      pinSetId: pinSetId,
      pinSetName: pinSetName,
      teeToPinYards: teeToPinYards,
    ),
  );
}

class _CourseTemplateSheet extends ConsumerStatefulWidget {
  const _CourseTemplateSheet({
    required this.courseId,
    required this.holeNumber,
    required this.par,
    required this.strokeIndex,
    required this.teeSetId,
    required this.teeSetName,
    required this.courseYards,
    required this.pinSetId,
    required this.pinSetName,
    required this.teeToPinYards,
  });

  final int courseId;
  final int holeNumber;
  final int par;
  final int? strokeIndex;

  /// The round's yardage set, each half null when the round has none.
  final int? teeSetId;
  final String? teeSetName;
  final int courseYards;
  final int? pinSetId;
  final String? pinSetName;
  final int teeToPinYards;

  @override
  ConsumerState<_CourseTemplateSheet> createState() =>
      _CourseTemplateSheetState();
}

class _CourseTemplateSheetState extends ConsumerState<_CourseTemplateSheet> {
  late int _par = widget.par;
  late int? _si = widget.strokeIndex;
  late int _courseYards = widget.courseYards;
  late int _teeToPin = widget.teeToPinYards;
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
      final teeSetId = widget.teeSetId;
      final pinSetId = widget.pinSetId;
      if (teeSetId != null) {
        // With a pin set the round plays tee-to-pin, so course yards are only
        // written when actually edited — not as a 0 nobody entered.
        if (pinSetId == null || _courseYards != widget.courseYards) {
          await repo.upsertCourseYard(CourseYardsCompanion.insert(
            teeSetId: teeSetId,
            holeNumber: widget.holeNumber,
            yards: _courseYards,
          ));
        }
        if (pinSetId != null) {
          await repo.upsertTeeToPinYard(TeeToPinYardsCompanion.insert(
            teeSetId: teeSetId,
            pinSetId: pinSetId,
            holeNumber: widget.holeNumber,
            yards: _teeToPin,
          ));
        }
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
    final hasTee = widget.teeSetId != null;
    final hasPin = hasTee && widget.pinSetId != null;
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
            hasTee
                ? 'Saved on the course, not this round — future rounds start '
                    'from these values. Par and stroke index apply from every '
                    'tee; course yards belong to the tee set, and tee-to-pin '
                    'yards to the tee set and pin set together.'
                : 'This round has no tee set, so only par and stroke index '
                    'can be saved — and those apply from every tee.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          CourseHoleCard(
            holeNumber: widget.holeNumber,
            par: _par,
            strokeIndex: _si,
            courseYards: hasTee ? _courseYards : null,
            teeSetName: widget.teeSetName,
            teeToPinYards: hasPin ? _teeToPin : null,
            pinSetName: widget.pinSetName,
            showStatus: false,
            onParChanged: (v) => setState(() => _par = v),
            onStrokeIndexChanged: (v) => setState(() => _si = v),
            onCourseYardsChanged:
                hasTee ? (v) => setState(() => _courseYards = v) : null,
            onTeeToPinYardsChanged:
                hasPin ? (v) => setState(() => _teeToPin = v) : null,
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
