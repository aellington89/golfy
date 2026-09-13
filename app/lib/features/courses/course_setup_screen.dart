import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/hole_nav_bar.dart';
import 'add_yardage_set_dialog.dart';
import 'course_hole_card.dart';
import 'course_template.dart';
import 'delete_course.dart';
import 'edit_course_dialog.dart';

enum _CourseMenuAction { edit, delete }

enum _SetMenuAction { rename, delete }

const int _holeCount = 18;

/// The whole of a course's template on one screen (#81): par, stroke index and
/// the selected yardage set's yardage, together, hole by hole — replacing the
/// old split between a par/stroke-index screen and a separate screen per set.
///
/// Borrows Hole Entry's idioms so setting a course up and playing it feel like
/// the same app: the same [ParSelector] for par, the same [HoleNavBar] chip
/// strip and "X / 18" counter, and the same Saved / Unsaved per-hole feedback.
///
/// **A list, not a `PageView`.** Stroke index is a global constraint — it has to
/// be a permutation of 1..18 — and you can't tell whether 7 is taken from a
/// screen showing one hole. Course setup is also random-access transcription off
/// a game's own screen, not the sequential walk that makes paging right for play.
///
/// **One save, per-hole feedback.** The repository writes a course card
/// wholesale, so "save just this hole" would quietly rewrite the other
/// seventeen; instead every hole shows whether it differs from what's stored and
/// a single save commits the lot in one transaction.
class CourseSetupScreen extends ConsumerStatefulWidget {
  const CourseSetupScreen({super.key, required this.courseId});

  final int courseId;

  @override
  ConsumerState<CourseSetupScreen> createState() => _CourseSetupScreenState();
}

class _CourseSetupScreenState extends ConsumerState<CourseSetupScreen> {
  // Created once: rebuilding these each frame would leave `ensureVisible`
  // holding a dead context.
  late final List<GlobalKey> _holeKeys =
      List<GlobalKey>.generate(_holeCount, (_) => GlobalKey());

  // Live edits.
  final List<int> _par = List<int>.filled(_holeCount, 4);
  final List<int?> _si = List<int?>.filled(_holeCount, null);

  // What the database holds. Null means "no row for this hole", which never
  // equals a live value — so a course with no card reads as entirely unsaved.
  final List<int?> _savedPar = List<int?>.filled(_holeCount, null);
  final List<int?> _savedSi = List<int?>.filled(_holeCount, null);
  bool _cardSeeded = false;

  /// Live and stored yardages per set id. Held per set so switching tee boxes
  /// carries unsaved edits instead of discarding them or nagging to save first.
  final Map<int, List<int>> _yardsBySet = {};
  final Map<int, List<int?>> _savedYardsBySet = {};

  /// Sets whose yardages have actually been loaded. Only these are ever written:
  /// a wholesale replace built from an unseeded blank card would wipe a tee box
  /// the user never opened.
  final Set<int> _seededSets = {};

  int? _activeSetId;
  int _currentHoleIndex = 0;
  bool _saving = false;

  static Course? _findById(List<Course> courses, int id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ── Seeding ──────────────────────────────────────────────────────────────

  /// Seeds par / stroke index once, from the stored card when there is one and
  /// otherwise from the standard par-72 template.
  ///
  /// A template seed is left looking unsaved on every hole, because `_savedPar`
  /// stays null — the guess is something to accept, not something to inherit,
  /// and an unreviewed default must never become indistinguishable in the
  /// database from a card somebody actually set.
  void _seedCard(List<CourseHole> card) {
    final byHole = {for (final h in card) h.holeNumber: h};
    for (var i = 0; i < _holeCount; i++) {
      final stored = byHole[i + 1];
      _par[i] = stored?.par ?? defaultParForHole(i + 1);
      _si[i] = stored?.strokeIndex;
      _savedPar[i] = stored?.par;
      _savedSi[i] = stored?.strokeIndex;
    }
  }

  void _seedSet(int setId, List<CourseSetYard> rows) {
    final byHole = {for (final y in rows) y.holeNumber: y.yards};
    _yardsBySet[setId] = [
      for (var h = 1; h <= _holeCount; h++) byHole[h] ?? 0,
    ];
    _savedYardsBySet[setId] = [
      for (var h = 1; h <= _holeCount; h++) byHole[h],
    ];
    _seededSets.add(setId);
  }

  /// Seeds a brand-new set from an existing one, as unsaved changes.
  Future<void> _seedCopiedSet(int newSetId, NewYardageSet spec) async {
    final source = spec.copyFromSetId;
    var yards = List<int>.filled(_holeCount, 0);
    if (source != null) {
      final rows =
          await ref.read(repositoryProvider).getCourseSetYards(source);
      final byHole = {for (final y in rows) y.holeNumber: y.yards};
      yards = applyYardOffset(
        [for (var h = 1; h <= _holeCount; h++) byHole[h] ?? 0],
        spec.offsetYards,
      );
    }
    if (!mounted) return;
    setState(() {
      _yardsBySet[newSetId] = yards;
      // Nothing is stored for the new set yet, so every hole reads unsaved.
      _savedYardsBySet[newSetId] = List<int?>.filled(_holeCount, null);
      // Claim it as seeded *before* its stream can emit, or the empty first
      // emission would overwrite the copy.
      _seededSets.add(newSetId);
      _activeSetId = newSetId;
    });
  }

  // ── Dirty / complete state ───────────────────────────────────────────────

  bool _holeIsDirty(int index) {
    if (_savedPar[index] != _par[index]) return true;
    if (_savedSi[index] != _si[index]) return true;
    // Any loaded set, not just the active one — otherwise the chips would
    // flicker as the user switches tee boxes and the unsaved count would lie.
    for (final setId in _seededSets) {
      final live = _yardsBySet[setId];
      final stored = _savedYardsBySet[setId];
      if (live == null || stored == null) continue;
      if (stored[index] != live[index]) return true;
    }
    return false;
  }

  /// A hole counts as set up once it has a stroke index and, when the course has
  /// a tee box selected, a yardage. Par always holds a value, so it can't signal
  /// completeness on its own.
  bool _holeIsComplete(int index) {
    if (_si[index] == null) return false;
    final active = _activeSetId;
    if (active == null) return true;
    final yards = _yardsBySet[active];
    return yards != null && yards[index] > 0;
  }

  Set<int> get _dirtyHoles => {
        for (var i = 0; i < _holeCount; i++)
          if (_holeIsDirty(i)) i + 1,
      };

  Set<int> get _completeHoles => {
        for (var i = 0; i < _holeCount; i++)
          if (_holeIsComplete(i)) i + 1,
      };

  // ── Actions ──────────────────────────────────────────────────────────────

  void _goToHole(int index) {
    setState(() => _currentHoleIndex = index);
    final ctx = _holeKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
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
    final yardsBySet = <int, List<CourseSetYardsCompanion>>{
      for (final setId in _seededSets)
        if (_yardsBySet[setId] != null)
          setId: [
            for (var i = 0; i < _holeCount; i++)
              CourseSetYardsCompanion.insert(
                courseSetId: setId,
                holeNumber: i + 1,
                yards: _yardsBySet[setId]![i],
              ),
          ],
    };

    try {
      await ref
          .read(repositoryProvider)
          .replaceCourseCard(widget.courseId, holes, yardsBySet);
      if (!mounted) return;
      setState(() {
        _saving = false;
        // Everything just written is now the stored state, which clears every
        // Saved / Unsaved chip at once.
        for (var i = 0; i < _holeCount; i++) {
          _savedPar[i] = _par[i];
          _savedSi[i] = _si[i];
        }
        for (final setId in yardsBySet.keys) {
          _savedYardsBySet[setId] = [..._yardsBySet[setId]!];
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Course card saved'),
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

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'This course card has edits that have not been saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            key: const ValueKey('discard_course_changes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  /// Back-navigation guard: the editor holds unsaved edits, so confirm before
  /// letting a pop discard them.
  Future<void> _handlePop(bool didPop) async {
    if (didPop || !mounted) return;
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    Navigator.of(context).pop();
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
        // The course is gone, so there is nothing left to save — drop the dirty
        // state before popping or the unsaved-changes guard would block it.
        setState(() {
          for (var i = 0; i < _holeCount; i++) {
            _savedPar[i] = _par[i];
            _savedSi[i] = _si[i];
          }
          _seededSets.clear();
        });
        Navigator.of(context).pop();
    }
  }

  Future<void> _addSet(List<CourseSet> existing) async {
    final spec = await showDialog<NewYardageSet>(
      context: context,
      builder: (_) => AddYardageSetDialog(existingSets: existing),
    );
    if (spec == null) return;
    try {
      final id = await ref.read(repositoryProvider).insertCourseSet(
            CourseSetsCompanion.insert(
              courseId: widget.courseId,
              name: spec.name,
            ),
          );
      await _seedCopiedSet(id, spec);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A set named "${spec.name}" already exists')),
      );
    }
  }

  Future<void> _onSetAction(_SetMenuAction action, CourseSet set) async {
    final repo = ref.read(repositoryProvider);
    switch (action) {
      case _SetMenuAction.rename:
        final name = await promptSetName(
          context,
          title: 'Rename set',
          initial: set.name,
        );
        if (name == null || name == set.name) return;
        try {
          await repo.renameCourseSet(set.id, name);
        } catch (_) {
          if (!mounted) return;
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
        if (!mounted) return;
        // Drop its in-memory state too, so a deleted set can't be written back
        // or counted as unsaved.
        setState(() {
          _yardsBySet.remove(set.id);
          _savedYardsBySet.remove(set.id);
          _seededSets.remove(set.id);
          if (_activeSetId == set.id) _activeSetId = null;
        });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
        return _buildEditor(context, course, courses, roundCount);
      },
    );
  }

  Widget _buildEditor(
    BuildContext context,
    Course course,
    List<Course> allCourses,
    int roundCount,
  ) {
    final cardAsync = ref.watch(courseHolesStreamProvider(widget.courseId));
    final setsAsync = ref.watch(courseSetsStreamProvider(widget.courseId));
    final sets = setsAsync.value ?? const <CourseSet>[];

    // Seed par/SI once; a live re-seed would fight the user's typing.
    cardAsync.whenData((card) {
      if (!_cardSeeded) {
        _seedCard(card);
        _cardSeeded = true;
      }
    });

    // Default to the first set, and fall back if the active one disappears.
    if (sets.isNotEmpty && !sets.any((s) => s.id == _activeSetId)) {
      _activeSetId = sets.first.id;
    }

    // Only the active set is watched — one live query rather than one per set.
    final activeSetId = _activeSetId;
    if (activeSetId != null) {
      ref.watch(courseSetYardsStreamProvider(activeSetId)).whenData((rows) {
        if (!_seededSets.contains(activeSetId)) {
          _seedSet(activeSetId, rows);
        }
      });
    }

    final dirty = _dirtyHoles;
    final activeYards = activeSetId == null ? null : _yardsBySet[activeSetId];
    final activeSetName = activeSetId == null
        ? null
        : sets.firstWhere((s) => s.id == activeSetId).name;

    return PopScope(
      canPop: dirty.isEmpty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
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
                  _onMenuAction(a, course, allCourses, roundCount),
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
          bottom: HoleNavBar(
            holeCount: _holeCount,
            currentIndex: _currentHoleIndex,
            complete: _completeHoles,
            dirty: dirty,
            label: 'Holes set',
            keyPrefix: 'course_hole_chip',
            onTapHole: _goToHole,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('save_course_card'),
          onPressed: _saving || dirty.isEmpty ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(
            dirty.isEmpty ? 'All saved' : 'Save card · ${dirty.length} unsaved',
          ),
        ),
        body: cardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load hole card: $e')),
          data: (_) => Column(
            children: [
              _YardageSetStrip(
                sets: sets,
                activeSetId: activeSetId,
                onSelect: (id) => setState(() => _activeSetId = id),
                onAdd: () => _addSet(sets),
                onSetAction: _onSetAction,
              ),
              const Divider(height: 1),
              Expanded(
                // A plain ListView, not .builder: eighteen cards are cheap, and
                // building them all keeps every GlobalKey attached so the chip
                // strip can scroll to any hole.
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: [
                    for (var i = 0; i < _holeCount; i++)
                      KeyedSubtree(
                        key: _holeKeys[i],
                        child: CourseHoleCard(
                          holeNumber: i + 1,
                          par: _par[i],
                          strokeIndex: _si[i],
                          yards: activeYards?[i],
                          setName: activeSetName,
                          isDirty: _holeIsDirty(i),
                          onParChanged: (v) => setState(() => _par[i] = v),
                          onStrokeIndexChanged: (v) =>
                              setState(() => _si[i] = v),
                          onYardsChanged: activeSetId == null
                              ? null
                              : (v) => setState(
                                    () => _yardsBySet[activeSetId]![i] = v,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The course's yardage sets as a selectable strip. Choosing one swaps which
/// yardage every hole card shows and edits.
class _YardageSetStrip extends StatelessWidget {
  const _YardageSetStrip({
    required this.sets,
    required this.activeSetId,
    required this.onSelect,
    required this.onAdd,
    required this.onSetAction,
  });

  final List<CourseSet> sets;
  final int? activeSetId;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final void Function(_SetMenuAction, CourseSet) onSetAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: sets.isEmpty
                ? const Text(
                    'No yardage sets yet. Add one (e.g. a tee box or pin set) '
                    'to record per-hole yardages.',
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in sets)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onLongPress: () =>
                                  onSetAction(_SetMenuAction.rename, s),
                              child: InputChip(
                                key: ValueKey('yardage_set_chip_${s.id}'),
                                label: Text(s.name),
                                selected: s.id == activeSetId,
                                showCheckmark: false,
                                avatar: const Icon(Icons.straighten, size: 18),
                                onPressed: () => onSelect(s.id),
                                onDeleted: () =>
                                    onSetAction(_SetMenuAction.delete, s),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                deleteButtonTooltipMessage: 'Delete set',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          TextButton.icon(
            key: const ValueKey('add_yardage_set'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add set'),
          ),
        ],
      ),
    );
  }
}
