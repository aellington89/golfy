import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../widgets/empty_state.dart';
import 'course_set_yards_screen.dart';
import 'delete_course.dart';
import 'edit_course_dialog.dart';

enum _CourseMenuAction { edit, delete }

/// Editor for one course's template (#36): the shared per-hole **par** and
/// **stroke index** card, plus its named **yardage sets** (pin sets / tee
/// boxes), each with its own 18-hole yardage card edited on
/// [CourseSetYardsScreen]. Reached from the [CoursesScreen] list.
///
/// Keyed by [courseId] and re-derived live from [coursesByNameStreamProvider],
/// so a rename reflects here and a delete (here or elsewhere) collapses to a
/// gone-state (mirrors [EventDetailScreen]). The par/SI rows seed once from
/// [courseHolesStreamProvider]; **Save card** rewrites them via
/// `replaceCourseHoles`. The sets section manages its own state.
class CourseHolesScreen extends ConsumerStatefulWidget {
  const CourseHolesScreen({super.key, required this.courseId});

  final int courseId;

  @override
  ConsumerState<CourseHolesScreen> createState() => _CourseHolesScreenState();
}

class _CourseHolesScreenState extends ConsumerState<CourseHolesScreen> {
  static const int _holeCount = 18;

  final List<int> _par = List<int>.filled(_holeCount, 4);
  // Read directly on save; the SI text fields own their display state, so these
  // mutate without setState (only the par dropdown needs a rebuild).
  final List<int?> _si = List<int?>.filled(_holeCount, null);

  bool _seeded = false;
  bool _saving = false;

  static Course? _findById(List<Course> courses, int id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _seedFromCard(List<CourseHole> card) {
    final byHole = {for (final h in card) h.holeNumber: h};
    for (var i = 0; i < _holeCount; i++) {
      final h = byHole[i + 1];
      _par[i] = h?.par ?? 4;
      _si[i] = h?.strokeIndex;
    }
  }

  Future<void> _save() async {
    // Client-side guard mirroring the stroke_index CHECK, so a typo surfaces a
    // friendly message instead of a raw DB error.
    for (var i = 0; i < _holeCount; i++) {
      final s = _si[i];
      if (s != null && (s < 1 || s > 18)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hole ${i + 1}: stroke index must be 1–18')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final holes = [
      for (var i = 0; i < _holeCount; i++)
        CourseHolesCompanion.insert(
          courseId: widget.courseId,
          holeNumber: i + 1,
          par: _par[i],
          strokeIndex: Value(_si[i]),
        ),
    ];
    try {
      await ref
          .read(repositoryProvider)
          .replaceCourseHoles(widget.courseId, holes);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Par & stroke index saved'),
          duration: Duration(seconds: 1),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  Future<void> _onMenuAction(
    _CourseMenuAction action,
    Course course,
    List<Course> allCourses,
    int roundCount,
  ) async {
    switch (action) {
      case _CourseMenuAction.edit:
        await showDialog<Course>(
          context: context,
          builder: (_) =>
              EditCourseDialog(course: course, existingCourses: allCourses),
        );
      case _CourseMenuAction.delete:
        final confirmed = await confirmDeleteCourse(
          context,
          courseName: course.name,
          roundCount: roundCount,
        );
        if (!confirmed) return;
        await ref.read(repositoryProvider).deleteCourse(course.id);
        if (!mounted) return;
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesByNameStreamProvider);
    final rounds =
        ref.watch(roundsStreamProvider).value ?? const <RoundWithCourse>[];
    final roundCount =
        rounds.where((r) => r.round.courseId == widget.courseId).length;

    return coursesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Failed to load course: $e')),
      ),
      data: (courses) {
        final course = _findById(courses, widget.courseId);
        if (course == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.golf_course_outlined,
              message: 'This course no longer exists.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.name, overflow: TextOverflow.ellipsis),
                Text(
                  course.gameTitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              PopupMenuButton<_CourseMenuAction>(
                key: const ValueKey('course_menu'),
                onSelected: (a) =>
                    _onMenuAction(a, course, courses, roundCount),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _CourseMenuAction.edit,
                    child: Text('Edit name'),
                  ),
                  PopupMenuItem(
                    value: _CourseMenuAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const ValueKey('save_course_card'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Save card'),
          ),
          body: ref.watch(courseHolesStreamProvider(widget.courseId)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Failed to load hole card: $e')),
                data: (card) {
                  if (!_seeded) {
                    _seedFromCard(card);
                    _seeded = true;
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                    children: [
                      const _SectionHeader('Par & stroke index'),
                      for (var i = 0; i < _holeCount; i++)
                        _ParSiRow(
                          hole: i + 1,
                          par: _par[i],
                          strokeIndex: _si[i],
                          onParChanged: (v) => setState(() => _par[i] = v),
                          onStrokeIndexChanged: (v) => _si[i] = v,
                        ),
                      const Divider(height: 32),
                      _YardageSetsSection(courseId: widget.courseId),
                    ],
                  );
                },
              ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One hole's shared par + stroke index row. The par dropdown is controlled;
/// the SI field seeds from `initialValue` (built once, after the card loads)
/// and reports edits back.
class _ParSiRow extends StatelessWidget {
  const _ParSiRow({
    required this.hole,
    required this.par,
    required this.strokeIndex,
    required this.onParChanged,
    required this.onStrokeIndexChanged,
  });

  final int hole;
  final int par;
  final int? strokeIndex;
  final ValueChanged<int> onParChanged;
  final ValueChanged<int?> onStrokeIndexChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('course_hole_row_$hole'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child:
                  Text('$hole', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(width: 8),
            _ParDropdown(value: par, onChanged: onParChanged),
            const Spacer(),
            SizedBox(
              width: 96,
              child: TextFormField(
                key: ValueKey('course_hole_si_$hole'),
                initialValue: strokeIndex?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stroke idx',
                  isDense: true,
                ),
                onChanged: (v) => onStrokeIndexChanged(int.tryParse(v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParDropdown extends StatelessWidget {
  const _ParDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: value,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 3, child: Text('Par 3')),
        DropdownMenuItem(value: 4, child: Text('Par 4')),
        DropdownMenuItem(value: 5, child: Text('Par 5')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// The course's named yardage sets: a list with add / rename / delete, each
/// tapping through to its 18-hole yardage editor ([CourseSetYardsScreen]).
class _YardageSetsSection extends ConsumerWidget {
  const _YardageSetsSection({required this.courseId});

  final int courseId;

  Future<void> _addSet(BuildContext context, WidgetRef ref) async {
    final name = await _promptSetName(context, title: 'Add yardage set');
    if (name == null) return;
    try {
      await ref
          .read(repositoryProvider)
          .insertCourseSet(CourseSetsCompanion.insert(
            courseId: courseId,
            name: name,
          ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A set named "$name" already exists')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(courseSetsStreamProvider(courseId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader('Yardage sets')),
            TextButton.icon(
              key: const ValueKey('add_yardage_set'),
              onPressed: () => _addSet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add set'),
            ),
          ],
        ),
        setsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Failed to load sets: $e'),
          ),
          data: (sets) {
            if (sets.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Text(
                  'No yardage sets yet. Add one (e.g. a pin set or tee box) to '
                  'record its per-hole yardages.',
                ),
              );
            }
            return Column(
              children: [for (final s in sets) _SetTile(set: s)],
            );
          },
        ),
      ],
    );
  }
}

enum _SetMenuAction { rename, delete }

class _SetTile extends ConsumerWidget {
  const _SetTile({required this.set});

  final CourseSet set;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _SetMenuAction action,
  ) async {
    final repo = ref.read(repositoryProvider);
    switch (action) {
      case _SetMenuAction.rename:
        final name = await _promptSetName(
          context,
          title: 'Rename set',
          initial: set.name,
        );
        if (name == null || name == set.name) return;
        try {
          await repo.renameCourseSet(set.id, name);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('A set named "$name" already exists')),
          );
        }
      case _SetMenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete yardage set?'),
            content: Text(
              'This deletes "${set.name}" and its yardages. Rounds played on it '
              'are kept and detached from the set (their scores are unaffected).',
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
        if (confirmed != true) return;
        await repo.deleteCourseSet(set.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: ValueKey('yardage_set_tile_${set.id}'),
      leading: const Icon(Icons.straighten),
      title: Text(set.name),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              CourseSetYardsScreen(setId: set.id, setName: set.name),
        ),
      ),
      trailing: PopupMenuButton<_SetMenuAction>(
        key: ValueKey('yardage_set_menu_${set.id}'),
        onSelected: (a) => _onAction(context, ref, a),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _SetMenuAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _SetMenuAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }
}

/// Prompts for a (non-empty, trimmed) yardage-set name, or null on cancel.
Future<String?> _promptSetName(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Set name',
          hintText: 'e.g. Blue tees, Sunday pins',
        ),
        onSubmitted: (_) {
          final t = controller.text.trim();
          Navigator.of(ctx).pop(t.isEmpty ? null : t);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final t = controller.text.trim();
            Navigator.of(ctx).pop(t.isEmpty ? null : t);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
