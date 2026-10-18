import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/hole_nav_bar.dart';
import 'add_set_dialog.dart';
import 'course_hole_card.dart';
import 'course_template.dart';
import 'delete_course.dart';
import 'edit_course_dialog.dart';

enum _CourseMenuAction { edit, delete }

enum _SetMenuAction { rename, delete }

const int _holeCount = 18;

/// The whole of a course's template on one screen (#81): par, stroke index,
/// the selected tee set's course yards and the selected tee set × pin set's
/// tee-to-pin yards, together, hole by hole.
///
/// Par and stroke index belong to the hole whatever it is played from. Course
/// yards belong to a tee set; tee-to-pin yards to a tee set and a pin set
/// together — the pair a round calls its yardage set. Picking a tee set and a
/// pin set above the holes chooses which yards every card shows and edits.
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

  /// Course yards per tee set id. A missing row reads unsaved, like a missing
  /// par: a tee set's card is something to fill in and accept.
  final _YardCards<int> _courseYards = _YardCards<int>(missingIsBlank: false);

  /// Tee-to-pin yards per (tee set id, pin set id). A missing row reads as a
  /// blank field: every tee set has its own card for every pin set, and just
  /// looking at a pair not filled in yet must not make eighteen holes unsaved.
  final _YardCards<(int, int)> _teeToPin =
      _YardCards<(int, int)>(missingIsBlank: true);

  int? _activeTeeId;
  int? _activePinId;

  /// A set just created here and selected before the sets stream has caught up
  /// with it — exempt from falling back to the first set until it arrives.
  int? _addedTeeId;
  int? _addedPinId;

  /// Whether the active sets have been pointed at the course's latest round's
  /// yet. Done once, when the sets and rounds have loaded, so the yardages just
  /// recorded by "Update course as I play" are the ones on screen — not
  /// whichever set sorts first by name. Set as soon as the user picks or adds a
  /// set, so a late-loading stream can't override their choice.
  bool _activeSetsDefaulted = false;
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

  /// Seeds a brand-new tee set's course yards from an existing tee set, as
  /// unsaved changes.
  Future<void> _seedCopiedTeeSet(int newTeeSetId, NewCourseSet spec) async {
    final source = spec.copyFromSetId;
    var yards = List<int>.filled(_holeCount, 0);
    if (source != null) {
      final rows = await ref.read(repositoryProvider).getCourseYards(source);
      final byHole = {for (final y in rows) y.holeNumber: y.yards};
      yards = applyYardOffset(
        [for (var h = 1; h <= _holeCount; h++) byHole[h] ?? 0],
        spec.offsetYards,
      );
    }
    if (!mounted) return;
    setState(() {
      // Claimed as seeded *before* its stream can emit, or the empty first
      // emission would overwrite the copy. Nothing is stored for the new tee
      // set yet, so every hole reads unsaved.
      _courseYards.seedUnsaved(newTeeSetId, yards);
      _activeTeeId = _addedTeeId = newTeeSetId;
      _activeSetsDefaulted = true;
    });
  }

  // ── Dirty / complete state ───────────────────────────────────────────────

  bool _holeIsDirty(int index) {
    if (_savedPar[index] != _par[index]) return true;
    if (_savedSi[index] != _si[index]) return true;
    // Any loaded card, not just the active ones — otherwise the chips would
    // flicker as the user switches sets and the unsaved count would lie.
    return _courseYards.holeIsDirty(index) || _teeToPin.holeIsDirty(index);
  }

  /// A hole counts as set up once it has a stroke index and, for whichever tee
  /// set and pin set are selected, its yards. Par always holds a value, so it
  /// can't signal completeness on its own.
  bool _holeIsComplete(int index) {
    if (_si[index] == null) return false;
    final tee = _activeTeeId;
    if (tee == null) return true;
    final course = _courseYards.live[tee];
    if (course == null || course[index] <= 0) return false;
    final pin = _activePinId;
    if (pin == null) return true;
    final toPin = _teeToPin.live[(tee, pin)];
    return toPin != null && toPin[index] > 0;
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
    // Only cards that changed: the rest already say what the database does,
    // and a pair the user only looked at has nothing to write.
    final dirtyTees = _courseYards.dirtyCards;
    final dirtyPairs = _teeToPin.dirtyCards;
    final courseYardsByTeeSet = <int, List<CourseYardsCompanion>>{
      for (final tee in dirtyTees)
        tee: [
          for (var i = 0; i < _holeCount; i++)
            CourseYardsCompanion.insert(
              teeSetId: tee,
              holeNumber: i + 1,
              yards: _courseYards.live[tee]![i],
            ),
        ],
    };
    final teeToPinByYardageSet = <(int, int), List<TeeToPinYardsCompanion>>{
      for (final pair in dirtyPairs)
        pair: [
          for (var i = 0; i < _holeCount; i++)
            TeeToPinYardsCompanion.insert(
              teeSetId: pair.$1,
              pinSetId: pair.$2,
              holeNumber: i + 1,
              yards: _teeToPin.live[pair]![i],
            ),
        ],
    };

    try {
      await ref
          .read(repositoryProvider)
          .replaceCourseCard(
            widget.courseId,
            holes,
            courseYardsByTeeSet: courseYardsByTeeSet,
            teeToPinByYardageSet: teeToPinByYardageSet,
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        // Everything just written is now the stored state, which clears every
        // Saved / Unsaved chip at once.
        for (var i = 0; i < _holeCount; i++) {
          _savedPar[i] = _par[i];
          _savedSi[i] = _si[i];
        }
        dirtyTees.forEach(_courseYards.markSaved);
        dirtyPairs.forEach(_teeToPin.markSaved);
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
          _courseYards.clear();
          _teeToPin.clear();
        });
        Navigator.of(context).pop();
    }
  }

  Future<void> _addSet(CourseSetKind kind, List<ExistingSet> existing) async {
    final spec = await showDialog<NewCourseSet>(
      context: context,
      builder: (_) => AddSetDialog(kind: kind, existing: existing),
    );
    if (spec == null) return;
    final repo = ref.read(repositoryProvider);
    try {
      switch (kind) {
        case CourseSetKind.tee:
          final id = await repo.insertTeeSet(TeeSetsCompanion.insert(
            courseId: widget.courseId,
            name: spec.name,
          ));
          await _seedCopiedTeeSet(id, spec);
        case CourseSetKind.pin:
          final id = await repo.insertPinSet(PinSetsCompanion.insert(
            courseId: widget.courseId,
            name: spec.name,
          ));
          if (!mounted) return;
          setState(() {
            _activePinId = _addedPinId = id;
            _activeSetsDefaulted = true;
          });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A ${kind.noun} named "${spec.name}" already exists'),
        ),
      );
    }
  }

  Future<void> _onSetAction(
    CourseSetKind kind,
    _SetMenuAction action,
    ExistingSet set,
  ) async {
    final repo = ref.read(repositoryProvider);
    switch (action) {
      case _SetMenuAction.rename:
        final name = await promptSetName(
          context,
          kind: kind,
          title: 'Rename ${kind.noun}',
          initial: set.name,
        );
        if (name == null || name == set.name) return;
        try {
          switch (kind) {
            case CourseSetKind.tee:
              await repo.renameTeeSet(set.id, name);
            case CourseSetKind.pin:
              await repo.renamePinSet(set.id, name);
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('A ${kind.noun} named "$name" already exists'),
            ),
          );
        }
      case _SetMenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete ${kind.noun}?'),
            content: Text(switch (kind) {
              CourseSetKind.tee => 'This deletes "${set.name}", its course '
                  'yards and its tee-to-pin yards. Rounds played from it are '
                  'kept and detached from it (their scores are unaffected).',
              CourseSetKind.pin => 'This deletes "${set.name}" and its '
                  'tee-to-pin yards. Rounds played to it are kept and detached '
                  'from it (their scores are unaffected).',
            }),
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
        switch (kind) {
          case CourseSetKind.tee:
            await repo.deleteTeeSet(set.id);
          case CourseSetKind.pin:
            await repo.deletePinSet(set.id);
        }
        if (!mounted) return;
        // Drop its in-memory cards too, so a deleted set can't be written back
        // or counted as unsaved.
        setState(() {
          switch (kind) {
            case CourseSetKind.tee:
              _courseYards.removeWhere((tee) => tee == set.id);
              _teeToPin.removeWhere((pair) => pair.$1 == set.id);
              if (_activeTeeId == set.id) _activeTeeId = null;
            case CourseSetKind.pin:
              _teeToPin.removeWhere((pair) => pair.$2 == set.id);
              if (_activePinId == set.id) _activePinId = null;
          }
        });
    }
  }

  /// The set to show from [ids]: [active] while it is there — or while it is
  /// the set [justAdded], which the stream hasn't caught up with yet — and
  /// otherwise the first, or none.
  static int? _resolveActive(List<int> ids, int? active, int? justAdded) {
    if (active != null && (ids.contains(active) || active == justAdded)) {
      return active;
    }
    return ids.isEmpty ? null : ids.first;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesByNameStreamProvider);
    final roundsValue = ref.watch(roundsStreamProvider).value;
    final courseRounds = [
      for (final r in roundsValue ?? const <RoundWithCourse>[])
        if (r.round.courseId == widget.courseId) r.round,
    ];
    // Newest first, so this is the round last played here; null until the
    // rounds have loaded, or when the course has never been played.
    final latestRound = roundsValue == null ? null : courseRounds.firstOrNull;

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
        return _buildEditor(
          context,
          course,
          courses,
          courseRounds.length,
          roundsLoaded: roundsValue != null,
          latestRound: latestRound,
        );
      },
    );
  }

  Widget _buildEditor(
    BuildContext context,
    Course course,
    List<Course> allCourses,
    int roundCount, {
    required bool roundsLoaded,
    required Round? latestRound,
  }) {
    final cardAsync = ref.watch(courseHolesStreamProvider(widget.courseId));
    final teeSetsValue = ref.watch(teeSetsStreamProvider(widget.courseId)).value;
    final pinSetsValue = ref.watch(pinSetsStreamProvider(widget.courseId)).value;
    final teeSets = teeSetsValue ?? const <TeeSet>[];
    final pinSets = pinSetsValue ?? const <PinSet>[];

    // Seed par/SI once; a live re-seed would fight the user's typing.
    cardAsync.whenData((card) {
      if (!_cardSeeded) {
        _seedCard(card);
        _cardSeeded = true;
      }
    });

    // Default to the first of each, and fall back if the active one goes.
    final teeIds = [for (final s in teeSets) s.id];
    final pinIds = [for (final s in pinSets) s.id];
    if (teeIds.contains(_addedTeeId)) _addedTeeId = null;
    if (pinIds.contains(_addedPinId)) _addedPinId = null;
    if (!_activeSetsDefaulted &&
        roundsLoaded &&
        teeSetsValue != null &&
        pinSetsValue != null) {
      _activeSetsDefaulted = true;
      final tee = latestRound?.teeSetId;
      final pin = latestRound?.pinSetId;
      if (teeIds.contains(tee)) _activeTeeId = tee;
      if (pinIds.contains(pin)) _activePinId = pin;
    }
    _activeTeeId = _resolveActive(teeIds, _activeTeeId, _addedTeeId);
    _activePinId = _resolveActive(pinIds, _activePinId, _addedPinId);

    // Only the active cards are watched — one live query each rather than one
    // per set.
    final activeTeeId = _activeTeeId;
    final activePinId = _activePinId;
    if (activeTeeId != null) {
      ref.watch(courseYardsStreamProvider(activeTeeId)).whenData((rows) {
        if (!_courseYards.seeded.contains(activeTeeId)) {
          _courseYards.seed(
            activeTeeId,
            {for (final y in rows) y.holeNumber: y.yards},
          );
        }
      });
    }
    final activePair = activeTeeId == null || activePinId == null
        ? null
        : (activeTeeId, activePinId);
    if (activePair != null) {
      ref.watch(teeToPinYardsStreamProvider(activePair)).whenData((rows) {
        if (!_teeToPin.seeded.contains(activePair)) {
          _teeToPin.seed(
            activePair,
            {for (final y in rows) y.holeNumber: y.yards},
          );
        }
      });
    }

    final dirty = _dirtyHoles;
    final courseYards =
        activeTeeId == null ? null : _courseYards.live[activeTeeId];
    final teeToPin = activePair == null ? null : _teeToPin.live[activePair];
    // Null-safe: a set just added may not be in the stream's list yet.
    final teeSetName =
        teeSets.where((s) => s.id == activeTeeId).firstOrNull?.name;
    final pinSetName =
        pinSets.where((s) => s.id == activePinId).firstOrNull?.name;
    final teeOptions = [for (final s in teeSets) (id: s.id, name: s.name)];
    final pinOptions = [for (final s in pinSets) (id: s.id, name: s.name)];

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
              _YardageIntro(
                hasSets: teeSets.isNotEmpty || pinSets.isNotEmpty,
              ),
              _SetStrip(
                kind: CourseSetKind.tee,
                sets: teeOptions,
                activeId: activeTeeId,
                empty: 'No tee sets yet. Add one (e.g. Blue) to record each '
                    'hole\'s course yards.',
                onSelect: (id) => setState(() {
                  _activeTeeId = id;
                  _activeSetsDefaulted = true;
                }),
                onAdd: () => _addSet(CourseSetKind.tee, teeOptions),
                onSetAction: (a, s) => _onSetAction(CourseSetKind.tee, a, s),
              ),
              _SetStrip(
                kind: CourseSetKind.pin,
                sets: pinOptions,
                activeId: activePinId,
                empty: 'No pin sets yet. Add one (e.g. Sunday pins) to record '
                    'tee-to-pin yards from each tee set.',
                onSelect: (id) => setState(() {
                  _activePinId = id;
                  _activeSetsDefaulted = true;
                }),
                onAdd: () => _addSet(CourseSetKind.pin, pinOptions),
                onSetAction: (a, s) => _onSetAction(CourseSetKind.pin, a, s),
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
                          courseYards: courseYards?[i],
                          teeSetName: teeSetName,
                          teeToPinYards: teeToPin?[i],
                          pinSetName: pinSetName,
                          isDirty: _holeIsDirty(i),
                          onParChanged: (v) => setState(() => _par[i] = v),
                          onStrokeIndexChanged: (v) =>
                              setState(() => _si[i] = v),
                          onCourseYardsChanged: courseYards == null
                              ? null
                              : (v) => setState(() => courseYards[i] = v),
                          onTeeToPinYardsChanged: teeToPin == null
                              ? null
                              : (v) => setState(() => teeToPin[i] = v),
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

/// One line above the strips saying what each set changes, once there are
/// sets to switch between.
class _YardageIntro extends StatelessWidget {
  const _YardageIntro({required this.hasSets});

  final bool hasSets;

  @override
  Widget build(BuildContext context) {
    if (!hasSets) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Text(
        'Par and stroke index are the same from every tee. Course yards change '
        'with the tee set; tee-to-pin yards with the tee set and pin set '
        'together.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

/// A course's tee sets or pin sets as a selectable strip. Choosing one swaps
/// which yards every hole card shows and edits; long-press renames, the chip's
/// delete icon deletes.
class _SetStrip extends StatelessWidget {
  const _SetStrip({
    required this.kind,
    required this.sets,
    required this.activeId,
    required this.empty,
    required this.onSelect,
    required this.onAdd,
    required this.onSetAction,
  });

  final CourseSetKind kind;
  final List<ExistingSet> sets;
  final int? activeId;

  /// What the strip says when the course has no sets of this [kind].
  final String empty;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final void Function(_SetMenuAction, ExistingSet) onSetAction;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      CourseSetKind.tee => Icons.sports_golf,
      CourseSetKind.pin => Icons.flag_outlined,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: sets.isEmpty
                ? Text(empty)
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
                                key: ValueKey('${kind.name}_set_chip_${s.id}'),
                                label: Text(s.name),
                                selected: s.id == activeId,
                                showCheckmark: false,
                                avatar: Icon(icon, size: 18),
                                onPressed: () => onSelect(s.id),
                                onDeleted: () =>
                                    onSetAction(_SetMenuAction.delete, s),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                deleteButtonTooltipMessage:
                                    'Delete ${kind.noun}',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          TextButton.icon(
            key: ValueKey('add_${kind.name}_set'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(switch (kind) {
              CourseSetKind.tee => 'Tee set',
              CourseSetKind.pin => 'Pin set',
            }),
          ),
        ],
      ),
    );
  }
}

/// Live and stored per-hole yards for one kind of yardage card — a tee set's
/// course yards, or a yardage set's tee-to-pin yards — keyed by [K].
///
/// Held per card so switching sets carries unsaved edits instead of discarding
/// them or nagging to save first. Only cards that have actually been loaded
/// ([seeded]) are ever written: a wholesale replace built from an unseeded
/// blank card would wipe yards the user never opened.
class _YardCards<K> {
  _YardCards({required this.missingIsBlank});

  /// Whether a hole with no stored row matches a blank (0) field. When false,
  /// a missing row never equals a live value, so the hole reads unsaved.
  final bool missingIsBlank;

  final Map<K, List<int>> live = {};
  final Map<K, List<int?>> _stored = {};
  final Set<K> seeded = {};

  /// Loads a card from its stored rows, by hole number.
  void seed(K key, Map<int, int> byHole) {
    live[key] = [for (var h = 1; h <= _holeCount; h++) byHole[h] ?? 0];
    _stored[key] = [
      for (var h = 1; h <= _holeCount; h++)
        byHole[h] ?? (missingIsBlank ? 0 : null),
    ];
    seeded.add(key);
  }

  /// Loads a card that has nothing stored yet, every hole unsaved.
  void seedUnsaved(K key, List<int> yards) {
    live[key] = [...yards];
    _stored[key] = List<int?>.filled(_holeCount, null);
    seeded.add(key);
  }

  bool _differs(K key, int index) {
    final l = live[key];
    final s = _stored[key];
    return l != null && s != null && s[index] != l[index];
  }

  bool holeIsDirty(int index) => seeded.any((k) => _differs(k, index));

  /// Every loaded card with at least one hole that differs from storage.
  List<K> get dirtyCards => [
        for (final k in seeded)
          if (Iterable<int>.generate(_holeCount).any((i) => _differs(k, i))) k,
      ];

  void markSaved(K key) => _stored[key] = [...live[key]!];

  void removeWhere(bool Function(K key) test) {
    live.removeWhere((k, _) => test(k));
    _stored.removeWhere((k, _) => test(k));
    seeded.removeWhere(test);
  }

  void clear() => removeWhere((_) => true);
}
