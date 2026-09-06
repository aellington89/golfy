import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../shell/tab_index_provider.dart';
import '../../widgets/empty_state.dart';
import '../rounds/active_round_provider.dart';
import 'hole_card.dart';
import 'hole_draft.dart';

/// Hole-by-hole entry for the round currently set on
/// [activeRoundIdProvider]. Swipeable [PageView] with one [HoleCard] per
/// hole (1..18); persisted drafts pre-populate from
/// [holeResultsStreamProvider], in-flight edits live in `_drafts` and
/// survive page swipes. "Finish Round" appears when all 18 holes are saved
/// and clears the active id + flips the shell back to the Rounds tab.
class HoleEntryScreen extends ConsumerStatefulWidget {
  const HoleEntryScreen({super.key});

  @override
  ConsumerState<HoleEntryScreen> createState() => _HoleEntryScreenState();
}

class _HoleEntryScreenState extends ConsumerState<HoleEntryScreen> {
  static const int _holeCount = 18;
  static final _displayFormat = DateFormat.yMMMMd();

  final PageController _pageController = PageController();
  final Map<int, HoleDraft> _drafts = {};

  /// Holes the user has touched since the last save / stream sync. We
  /// don't want a stream tick to clobber an in-flight edit, so these are
  /// skipped when seeding from `savedByHole`.
  final Set<int> _dirty = {};

  /// Round id the `_drafts` cache was built for. When the active round
  /// changes (new round started, current round deleted), the cache must
  /// be cleared.
  int? _draftsRoundId;

  /// The active round's template auto-fill sources, keyed by hole number (#36),
  /// refreshed each build and read by [_initialForHole] (so a hole the user
  /// never opened still saves the course's par/yards). `par` comes from the
  /// course's shared per-hole card ([courseHolesStreamProvider]); `yards` from
  /// the round's chosen yardage set ([courseSetYardsStreamProvider]). Either is
  /// empty when absent — the graceful "no data" fallback (par 4 / blank yards).
  Map<int, int> _parByHole = const {};
  Map<int, int> _yardsByHole = const {};

  /// Whether the round was already complete (18/18 saved) the first time
  /// its hole stream emitted this session. Drives the Finish FAB label:
  /// re-opening a finished round from the scorecard's Edit action reads
  /// "Done", whereas completing the 18th hole during first entry reads
  /// "Finish Round". Hole rows are only ever upserted (never deleted), so a
  /// complete round stays complete — this entry-time snapshot is stable.
  /// Captured once per round (guarded by [_initialCountCaptured]) and reset
  /// in [_resetForRound].
  bool _wasCompleteOnEntry = false;
  bool _initialCountCaptured = false;

  /// Currently-visible page index (0-based). Kept in sync via
  /// [PageView.onPageChanged] for swipe gestures and updated eagerly in
  /// [_goToPage] so the chip strip highlights the target as soon as the
  /// user taps a chip (rather than waiting for the animation to finish).
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _resetForRound(int? roundId) {
    _drafts.clear();
    _dirty.clear();
    _currentPage = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _draftsRoundId = roundId;
    _wasCompleteOnEntry = false;
    _initialCountCaptured = false;
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _seedFromSaved(Map<int, HoleResult> savedByHole) {
    for (final entry in savedByHole.entries) {
      if (_dirty.contains(entry.key)) continue;
      _drafts[entry.key] = HoleDraft.fromHoleResult(entry.value);
    }
  }

  /// The starting draft for a hole the user hasn't touched or saved: par from
  /// the course's shared card and yards from the round's set (#36), each falling
  /// back to the plain default when absent. Saved holes are seeded separately in
  /// [_seedFromSaved] and take precedence via `_drafts[hole] ??` at the call
  /// sites.
  HoleDraft _initialForHole(int holeNumber) {
    return HoleDraft.initial(
      par: _parByHole[holeNumber] ?? 4,
      yards: _yardsByHole[holeNumber] ?? 0,
    );
  }

  Future<void> _saveHole(int roundId, int holeNumber) async {
    final draft = _drafts[holeNumber] ?? _initialForHole(holeNumber);
    final companion = draft.toCompanion(
      roundId: roundId,
      holeNumber: holeNumber,
    );
    final repo = ref.read(repositoryProvider);
    try {
      await repo.upsertHoleResult(companion);
      if (!mounted) return;
      setState(() => _dirty.remove(holeNumber));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hole $holeNumber saved'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save hole: $e')),
      );
    }
  }

  void _finishRound() {
    ref.read(activeRoundIdProvider.notifier).clear();
    ref.read(tabIndexProvider.notifier).set(ShellTabs.rounds);
  }

  @override
  Widget build(BuildContext context) {
    final activeRoundId = ref.watch(activeRoundIdProvider);

    if (activeRoundId == null) {
      return const _NoActiveRound();
    }

    // Reset drafts when the active round changes between builds.
    if (_draftsRoundId != activeRoundId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _resetForRound(activeRoundId));
      });
    }

    final roundAsync = ref.watch(roundWithCourseProvider(activeRoundId));
    final holesAsync = ref.watch(holeResultsStreamProvider(activeRoundId));

    // The active round's template auto-fill (#36): par from the course's shared
    // per-hole card, yards from the round's chosen yardage set. Both refresh
    // when the round (hence course / set) changes; each is empty until it loads
    // or when the course has no card / the round has no set.
    final round = roundAsync.value?.round;
    final courseId = round?.courseId;
    final courseSetId = round?.courseSetId;
    final parByHole = <int, int>{};
    if (courseId != null) {
      ref.watch(courseHolesStreamProvider(courseId)).whenData((holes) {
        for (final h in holes) {
          parByHole[h.holeNumber] = h.par;
        }
      });
    }
    final yardsByHole = <int, int>{};
    if (courseSetId != null) {
      ref.watch(courseSetYardsStreamProvider(courseSetId)).whenData((yards) {
        for (final y in yards) {
          yardsByHole[y.holeNumber] = y.yards;
        }
      });
    }
    _parByHole = parByHole;
    _yardsByHole = yardsByHole;

    final savedByHole = <int, HoleResult>{};
    holesAsync.whenData((holes) {
      for (final h in holes) {
        savedByHole[h.holeNumber] = h;
      }
      _seedFromSaved(savedByHole);
      // Snapshot whether the round arrived already complete, so the Finish
      // FAB can read "Done" for an edit of a finished round vs. "Finish
      // Round" for a first-time completion. Gated on the post-frame reset
      // having synced `_draftsRoundId`, so we never capture the pre-reset
      // frame's stale round identity.
      if (!_initialCountCaptured && _draftsRoundId == activeRoundId) {
        _initialCountCaptured = true;
        _wasCompleteOnEntry = savedByHole.length == _holeCount;
      }
    });

    final savedCount = savedByHole.length;
    final allSaved = savedCount == _holeCount;

    return Scaffold(
      appBar: AppBar(
        title: _AppBarTitle(roundAsync: roundAsync),
        bottom: _HoleNavBar(
          holeCount: _holeCount,
          currentPage: _currentPage,
          savedByHole: savedByHole,
          onTapHole: _goToPage,
        ),
      ),
      floatingActionButton: allSaved
          ? FloatingActionButton.extended(
              key: const ValueKey('finish_round'),
              onPressed: _finishRound,
              icon: Icon(_wasCompleteOnEntry ? Icons.check : Icons.flag),
              label: Text(_wasCompleteOnEntry ? 'Done' : 'Finish Round'),
            )
          : null,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _holeCount,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, index) {
          final holeNumber = index + 1;
          final draft = _drafts[holeNumber] ?? _initialForHole(holeNumber);
          final savedDraft = savedByHole.containsKey(holeNumber)
              ? HoleDraft.fromHoleResult(savedByHole[holeNumber]!)
              : null;
          return HoleCard(
            key: ValueKey('hole_card_$holeNumber'),
            holeNumber: holeNumber,
            draft: draft,
            savedDraft: savedDraft,
            onChanged: (updated) {
              setState(() {
                _drafts[holeNumber] = updated;
                _dirty.add(holeNumber);
              });
            },
            onSave: () => _saveHole(activeRoundId, holeNumber),
            onPrev: index == 0 ? null : () => _goToPage(index - 1),
            onNext:
                index == _holeCount - 1 ? null : () => _goToPage(index + 1),
          );
        },
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.roundAsync});

  final AsyncValue<RoundWithCourse?> roundAsync;

  @override
  Widget build(BuildContext context) {
    final round = roundAsync.value;
    if (round == null) return const Text('Hole Entry');
    final dateLabel = _formatDate(round.round.date);
    final eventName = round.event?.name;
    final subtitle = eventName == null ? dateLabel : '$dateLabel · $eventName';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          round.courseName,
          style: Theme.of(context).textTheme.titleLarge,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  static String _formatDate(String iso) {
    try {
      return _HoleEntryScreenState._displayFormat.format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

/// Horizontal strip of 18 hole chips that sits under the AppBar title.
/// Each chip jumps the [PageView] to that hole on tap, shows a check
/// when the hole is saved, and highlights when it's the active page.
/// Replaces the old jump-to-hole popup menu — discoverability for both
/// "go to hole N" and "which holes are done" comes from a single visible
/// control. Above the strip, a small "Holes saved: X / 18" counter gives
/// the at-a-glance progress signal the chips alone don't.
class _HoleNavBar extends StatefulWidget implements PreferredSizeWidget {
  const _HoleNavBar({
    required this.holeCount,
    required this.currentPage,
    required this.savedByHole,
    required this.onTapHole,
  });

  final int holeCount;
  final int currentPage;
  final Map<int, HoleResult> savedByHole;
  final ValueChanged<int> onTapHole;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  State<_HoleNavBar> createState() => _HoleNavBarState();
}

class _HoleNavBarState extends State<_HoleNavBar> {
  final ScrollController _scrollController = ScrollController();
  static const double _chipExtent = 52;

  @override
  void didUpdateWidget(covariant _HoleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final target =
        widget.currentPage * _chipExtent - viewport / 2 + _chipExtent / 2;
    final clamped =
        target.clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedCount = widget.savedByHole.length;
    return SizedBox(
      height: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(
              'Holes saved: $savedCount / ${widget.holeCount}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: widget.holeCount,
              itemBuilder: (context, i) {
                final hole = i + 1;
                final saved = widget.savedByHole.containsKey(hole);
                final active = widget.currentPage == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    key: ValueKey('hole_chip_$hole'),
                    label: Text('$hole'),
                    avatar: saved
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: active
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.primary,
                          )
                        : null,
                    selected: active,
                    onSelected: (_) => widget.onTapHole(i),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveRound extends ConsumerWidget {
  const _NoActiveRound();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hole Entry')),
      body: EmptyState(
        icon: Icons.flag_outlined,
        message: 'No active round. Go to Rounds to start one.',
        action: FilledButton.icon(
          onPressed: () => ref.read(tabIndexProvider.notifier).set(ShellTabs.rounds),
          icon: const Icon(Icons.list_alt),
          label: const Text('Go to Rounds'),
        ),
      ),
    );
  }
}
