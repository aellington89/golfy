import 'package:flutter/material.dart';

/// A horizontal strip of hole chips with a progress counter above it, for use
/// as an [AppBar.bottom].
///
/// Each chip jumps to that hole on tap, carries a check when the hole is
/// [complete] and a pencil when it has unsaved edits, and highlights when it's
/// the current one. Above the strip, a small "`label`: X / N" counter gives the
/// at-a-glance progress signal the chips alone don't.
///
/// Generalised out of the Hole Entry screen so the course editor gets the same
/// navigation and completeness signal (#81) rather than an imitation of it. The
/// counter string is built here, not passed in, so the two screens can't drift
/// apart in format.
class HoleNavBar extends StatefulWidget implements PreferredSizeWidget {
  const HoleNavBar({
    super.key,
    required this.holeCount,
    required this.currentIndex,
    required this.complete,
    required this.label,
    required this.onTapHole,
    this.dirty = const {},
    this.keyPrefix = 'hole_chip',
    this.completeState = 'saved',
    this.textScaler = TextScaler.noScaling,
  });

  final int holeCount;

  /// Zero-based index of the hole currently shown.
  final int currentIndex;

  /// One-based hole numbers that count as done.
  final Set<int> complete;

  /// One-based hole numbers with unsaved edits.
  final Set<int> dirty;

  /// Leads the counter, e.g. `'Holes saved'` → "Holes saved: 4 / 18".
  final String label;

  /// Receives the tapped hole's zero-based index.
  final ValueChanged<int> onTapHole;

  /// Chip keys are `'<keyPrefix>_<holeNumber>'`. Distinct per screen so two
  /// strips on different screens don't collide in tests.
  final String keyPrefix;

  /// What a [complete] hole is, spoken after its number — "Hole 4, saved" on
  /// Hole Entry, "Hole 4, set" in the course editor. The check and pencil
  /// icons say it only visually (#73).
  final String completeState;

  /// The text scale the strip is drawn at — pass
  /// `MediaQuery.textScalerOf(context)`. An [AppBar] reads [preferredSize]
  /// before it builds its bottom, so the strip can't measure itself; it works
  /// its height out from this instead (#73).
  final TextScaler textScaler;

  @override
  Size get preferredSize => Size.fromHeight(heightFor(textScaler));

  /// 80 dp at the default text size: the counter's 16 dp line (12 sp text), the
  /// chips' 20 dp label line (14 sp) and padding. At a larger text size both
  /// lines grow and the padding doesn't. A fixed 80 dp squeezed the chips until
  /// their numbers were clipped (#73).
  static double heightFor(TextScaler scaler) {
    double growth(double fontSize, double lineHeight) =>
        (scaler.scale(fontSize) - fontSize) * lineHeight / fontSize;
    return 80 + growth(12, 16) + growth(14, 20);
  }

  @override
  State<HoleNavBar> createState() => _HoleNavBarState();
}

class _HoleNavBarState extends State<HoleNavBar> {
  final ScrollController _scrollController = ScrollController();

  /// Each chip's key, so the current one can be scrolled to wherever it is:
  /// chips are wider with an icon and at a larger text size.
  late List<GlobalKey> _chipKeys = _keysFor(widget.holeCount);

  static List<GlobalKey> _keysFor(int count) =>
      List.generate(count, (_) => GlobalKey());

  /// Where a chip is assumed to sit when it isn't built yet, far off screen.
  static const double _chipExtent = 52;

  @override
  void didUpdateWidget(covariant HoleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holeCount != widget.holeCount) {
      _chipKeys = _keysFor(widget.holeCount);
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrent();
    }
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    const duration = Duration(milliseconds: 200);
    final chip = _chipKeys[widget.currentIndex].currentContext;
    if (chip != null) {
      Scrollable.ensureVisible(
        chip,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeOut,
      );
      return;
    }
    final viewport = _scrollController.position.viewportDimension;
    final target =
        widget.currentIndex * _chipExtent - viewport / 2 + _chipExtent / 2;
    final clamped =
        target.clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      clamped,
      duration: duration,
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
    final completeCount = widget.complete.length;
    return SizedBox(
      height: widget.preferredSize.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(
              '${widget.label}: $completeCount / ${widget.holeCount}',
              semanticsLabel:
                  '${widget.label}: $completeCount of ${widget.holeCount}',
              style: theme.textTheme.bodySmall,
              // One line, as the height allows for: a large text size on a
              // narrow screen ellipsises rather than pushing the chips down.
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                final active = widget.currentIndex == i;
                // Unsaved edits outrank "done" — a hole you've changed since
                // saving is the one you still need to act on.
                final isDirty = widget.dirty.contains(hole);
                final isComplete = widget.complete.contains(hole);
                final icon = isDirty
                    ? Icons.edit
                    : isComplete
                        ? Icons.check
                        : null;
                return Padding(
                  key: _chipKeys[i],
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    key: ValueKey('${widget.keyPrefix}_$hole'),
                    label: Text(
                      '$hole',
                      semanticsLabel: isDirty
                          ? 'Hole $hole, unsaved changes'
                          : isComplete
                              ? 'Hole $hole, ${widget.completeState}'
                              : 'Hole $hole',
                    ),
                    avatar: icon == null
                        ? null
                        : Icon(
                            icon,
                            size: 16,
                            color: active
                                ? theme.colorScheme.onSecondaryContainer
                                : isDirty
                                    ? theme.colorScheme.tertiary
                                    : theme.colorScheme.primary,
                          ),
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
