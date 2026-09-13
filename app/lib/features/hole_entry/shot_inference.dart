import 'hole_draft.dart';

/// Shot suggestion and reconciliation for the Hole Entry form (#81).
///
/// Pure Dart on purpose — no Flutter import — so every rule here is covered by
/// fast unit tests instead of widget pumps. The UI in `hole_card.dart` only
/// renders what these functions return.
///
/// Everything produced here is a *starting point*. Shots stay optional, every
/// suggested field is overrideable, and nothing in this file ever mutates a
/// draft or blocks a save.

/// The standard bag, longest to shortest. This is the dropdown's display order,
/// so it must not be reordered. Stored as free text, so a value outside this
/// list still round-trips (the dropdown shows it as unset).
const List<String> shotClubs = [
  'Driver',
  '3 Wood',
  '5 Wood',
  '7 Wood',
  '3 Hybrid',
  '4 Hybrid',
  '5 Hybrid',
  '2 Iron',
  '3 Iron',
  '4 Iron',
  '5 Iron',
  '6 Iron',
  '7 Iron',
  '8 Iron',
  '9 Iron',
  'Pitching Wedge',
  'Gap Wedge',
  'Sand Wedge',
  'Lob Wedge',
  'Putter',
];

/// Where a shot was played from.
const List<String> shotLies = [
  'Tee',
  'Fairway',
  'Light Rough',
  'Deep Rough',
  'Bunker',
  'Green',
  'Recovery',
];

// A shot's normal end-spot is just the *next* shot's lie, so `result` only
// captures the terminal outcomes a next shot can't imply: the ball was holed,
// or a penalty was incurred (OB / water / lost). Leave it blank otherwise.
const List<String> shotResults = [
  'Holed',
  'Penalty',
];

const String _putter = 'Putter';
const String _holed = 'Holed';
const String _penalty = 'Penalty';

/// Typical full-swing carry per club, in yards. Used only to *suggest* a club
/// and to step the remaining distance down between shots — never stored.
///
/// Deliberately omits [_putter]: a putt's distance is measured in feet on the
/// green, and putting is driven by the hole's `putts` count instead.
///
/// These are one generic player's numbers, so they will be wrong for somebody.
/// That is tolerable because every suggestion is overrideable — and it is why
/// [suggestClub] takes the bag as a parameter: the app already stores every
/// `(club, distance)` pair the user has ever entered in `hole_shots`, so a
/// learned per-player bag can replace this default later without touching a
/// single call site.
const Map<String, int> defaultClubDistances = {
  'Driver': 250,
  '3 Wood': 225,
  '5 Wood': 210,
  '7 Wood': 195,
  '3 Hybrid': 200,
  '4 Hybrid': 190,
  '5 Hybrid': 180,
  '2 Iron': 200,
  '3 Iron': 190,
  '4 Iron': 180,
  '5 Iron': 170,
  '6 Iron': 160,
  '7 Iron': 150,
  '8 Iron': 140,
  '9 Iron': 130,
  'Pitching Wedge': 115,
  'Gap Wedge': 100,
  'Sand Wedge': 85,
  'Lob Wedge': 65,
};

/// The club to play from [remainingYards] out: the one whose typical carry is
/// closest to the distance left.
///
/// Ties resolve to whichever club comes **earlier in [shotClubs]** — the longer,
/// more forgiving option — so the result is deterministic despite the bag
/// holding deliberate duplicates (3 Hybrid / 2 Iron both at 200, and so on).
///
/// Distances beyond the longest or shorter than the shortest club fall out of
/// nearest-match on their own: a 420-yard tee shot suggests a Driver. Returns
/// null for a non-positive distance, which is how "unknown" reaches here.
String? suggestClub(
  int remainingYards, {
  Map<String, int> bag = defaultClubDistances,
}) {
  if (remainingYards <= 0) return null;

  String? best;
  int? bestGap;
  // Walk [shotClubs] rather than the bag so ordering — and therefore tie-breaking
  // — is stable regardless of the map's iteration order.
  for (final club in shotClubs) {
    final carry = bag[club];
    if (carry == null) continue;
    final gap = (carry - remainingYards).abs();
    if (bestGap == null || gap < bestGap) {
      best = club;
      bestGap = gap;
    }
  }
  return best;
}

/// Physical shots the hole's scoring fields imply.
///
/// A penalty stroke isn't a shot row — it's recorded as `result: 'Penalty'` on
/// the shot that *caused* it — so the number of rows a completed hole should
/// have is the score minus its penalties.
int physicalShots(HoleDraft draft) {
  final penalties = draft.penaltyStrokes < 0 ? 0 : draft.penaltyStrokes;
  final physical = draft.score - penalties;
  return physical < 1 ? 1 : physical;
}

/// Full swings (everything that isn't a putt) the scoring fields imply.
///
/// Clamped to at least one: there is always a tee shot, even when penalties push
/// the arithmetic negative. A hole whose numbers don't add up still scaffolds
/// sensibly and shows up in [shotWarnings] rather than producing an empty list.
int fullSwingCount(HoleDraft draft) {
  final swings = physicalShots(draft) - draft.putts;
  return swings < 1 ? 1 : swings;
}

/// The remaining distance for the shot at [index], stepping the hole's yardage
/// down by each previous shot's typical carry.
///
/// Null when it can't be known — an unrecorded hole yardage, a previous shot
/// with no club, or a ball already at the pin.
int? _remainingAt(HoleDraft draft, int index, Map<String, int> bag) {
  if (draft.yards <= 0) return null;
  var remaining = draft.yards;
  for (var i = 0; i < index && i < draft.shots.length; i++) {
    final club = draft.shots[i].club;
    if (club == null) return null;
    final carry = bag[club];
    if (carry == null) return null;
    remaining -= carry;
  }
  return remaining > 0 ? remaining : null;
}

/// The pre-filled row to append to [HoleDraft.shots].
///
/// Reads the draft's own shot list, so the index is implicit — there's no way to
/// pass an index that disagrees with the list.
///
/// Chaining deliberately stops at the edges of what the hole-level fields
/// actually pin down. `fairwayHit` says exactly where a par-4/5 tee shot
/// finished, so shot 2's lie follows from it; `bunkerVisited` and `gir` say a
/// bunker or green was involved *somewhere* without saying on which shot, so
/// they suggest nothing and surface through [shotWarnings] instead. A blank the
/// user fills in one tap beats a guess they have to notice and undo.
ShotDraft suggestNextShot(
  HoleDraft draft, {
  Map<String, int> bag = defaultClubDistances,
}) {
  final shots = draft.shots;
  final index = shots.length;

  // Tee shot: the whole hole is still in front of you, so "remaining" is the
  // hole's yardage.
  if (index == 0) {
    final yards = draft.yards > 0 ? draft.yards : null;
    return ShotDraft(
      club: yards == null ? null : suggestClub(yards, bag: bag),
      distanceYards: yards,
      lie: 'Tee',
      result: _holedIfLast(draft, index),
    );
  }

  final previous = shots[index - 1];

  // After a penalty the ball is dropped somewhere the hole data doesn't record,
  // so every chained inference breaks down. Offer a blank row instead of a lie.
  if (previous.result == _penalty) {
    return const ShotDraft();
  }

  // Once the full swings are used up, the rest of the hole is putts.
  if (index >= fullSwingCount(draft) && draft.putts > 0) {
    return ShotDraft(
      club: _putter,
      lie: 'Green',
      result: _holedIfLast(draft, index),
    );
  }

  final remaining = _remainingAt(draft, index, bag);
  return ShotDraft(
    club: remaining == null ? null : suggestClub(remaining, bag: bag),
    distanceYards: remaining,
    lie: _chainedLie(draft, index, previous),
    result: _holedIfLast(draft, index),
  );
}

/// Where the shot at [index] is played from, given the previous row and the
/// hole-level fields. Null means "the data doesn't say" — the user picks.
String? _chainedLie(HoleDraft draft, int index, ShotDraft previous) {
  if (previous.club == _putter || previous.lie == 'Green') return 'Green';

  if (index == 1) {
    if (draft.par == 3) {
      // A par-3 tee shot that found the green is the only case the hole-level
      // fields pin down; missing it could be anywhere.
      return draft.gir ? 'Green' : null;
    }
    // fairwayHit is exactly "where did the tee shot finish" for a par 4 or 5.
    return switch (draft.fairwayHit) {
      true => 'Fairway',
      false => 'Light Rough',
      null => null,
    };
  }

  return null;
}

/// `'Holed'` when the row at [index] is the one that completes the score.
String? _holedIfLast(HoleDraft draft, int index) =>
    index + 1 == physicalShots(draft) ? _holed : null;

/// A full shot list built from the hole's scoring fields: the implied full
/// swings followed by the implied putts, chained the same way [suggestNextShot]
/// chains them, with the final row holed.
///
/// Offered as a one-tap starting point when a hole has no shots yet; the caller
/// keeps it out of reach once rows exist, so this never destroys entered work.
List<ShotDraft> scaffoldShotsFromScore(
  HoleDraft draft, {
  Map<String, int> bag = defaultClubDistances,
}) {
  final rows = physicalShots(draft);
  var built = draft.copyWith(shots: const []);
  for (var i = 0; i < rows; i++) {
    built = built.copyWith(
      shots: [...built.shots, suggestNextShot(built, bag: bag)],
    );
  }
  return built.shots;
}

/// Human-readable disagreements between the shot list and the hole-level fields.
///
/// Warn, never correct. Silently rewriting `putts` or `bunkerVisited` to match
/// the shots would fight the user, and can land the draft in a state
/// `HoleResultDao` rejects outright (raising putts to match putter rows can
/// break the `putts < score` invariant). Saving is never blocked.
///
/// Counting rules only fire once the list is *complete*. A half-entered list
/// disagrees with the score by definition, and a banner that's always on while
/// you type is a banner nobody reads. An under-count is never flagged at all —
/// `HoleShots` documents that shots need not sum to the score, so stopping after
/// the interesting shots is a legitimate way to use the feature. Recording
/// *more* shots than the score allows is the unambiguous error.
List<String> shotWarnings(HoleDraft draft) {
  final shots = draft.shots;
  if (shots.isEmpty) return const [];

  final warnings = <String>[];
  final physical = physicalShots(draft);
  final complete = shots.length >= physical;

  if (shots.length > physical) {
    warnings.add(
      'More shots recorded (${shots.length}) than the score allows '
      '($physical after penalties).',
    );
  }

  final putterShots = shots.where((s) => s.club == _putter).length;
  if (complete && putterShots != draft.putts) {
    warnings.add(
      'Putts is ${draft.putts} but $putterShots '
      '${putterShots == 1 ? 'shot uses' : 'shots use'} the putter.',
    );
  }

  if (!draft.bunkerVisited && shots.any((s) => s.lie == 'Bunker')) {
    warnings.add(
      'A shot is played from a bunker but "Bunker visited" is off.',
    );
  }

  if (draft.par >= 4 && shots.length >= 2) {
    final approachLie = shots[1].lie;
    if (approachLie != null) {
      final fromFairway = approachLie == 'Fairway';
      if (draft.fairwayHit == true && !fromFairway) {
        warnings.add(
          '"Fairway hit" is on but shot 2 is played from $approachLie.',
        );
      } else if (draft.fairwayHit == false && fromFairway) {
        warnings.add(
          '"Fairway hit" is off but shot 2 is played from the fairway.',
        );
      }
    }
  }

  // The suggestion engine only ever holes the last row, but a user editing a
  // list can leave an earlier one marked — worth flagging rather than rewriting.
  for (var i = 0; i < shots.length - 1; i++) {
    if (shots[i].result == _holed) {
      warnings.add('Shot ${i + 1} is marked holed but isn\'t the last shot.');
      break;
    }
  }

  if (complete && draft.gir) {
    final nonPutts = shots.where((s) => s.club != _putter).length;
    if (nonPutts > draft.par - 2) {
      warnings.add(
        'GIR is on but $nonPutts shots were taken before the first putt '
        '(a green in regulation allows ${draft.par - 2}).',
      );
    }
  }

  return warnings;
}
