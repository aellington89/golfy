import 'hole_draft.dart';

/// Shot vocabulary and suggestion for the Hole Entry form (#22, #81).
///
/// Pure Dart on purpose — no Flutter import — so every rule here is covered by
/// fast unit tests instead of widget pumps. How a hole's fields follow from one
/// another, and what stops a save, lives in `hole_rules.dart`.

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
// or a penalty was incurred (OB / water / lost). Leave it blank otherwise. The
// form sets `Holed` itself — it is always the hole's last stroke — so only
// `Penalty` is ever the player's to mark.
const List<String> shotResults = [
  holedResult,
  penaltyResult,
];

/// Where shot 2 of a par 4 or 5 is played from, given whether the tee shot
/// found the fairway. A miss is most often the rough; it's a starting point
/// the player overrides for a bunker or the trees. Null when unanswered.
String? lieAfterTeeShot(bool? fairwayHit) => switch (fairwayHit) {
      true => 'Fairway',
      false => 'Light Rough',
      null => null,
    };

/// The row "Add shot" appends to [HoleDraft.shots].
///
/// Only the lie is ever filled in, and only where the hole's own answers pin it
/// down: shot 2 on a par 4 or 5 is played from wherever the tee shot finished,
/// which "Fairway hit?" says. Everything else starts blank. In particular the
/// club and the distance are never guessed — the tee shot is the only stroke
/// whose distance the hole knows, and it gets the yardage when it's laid out.
ShotDraft suggestNextShot(HoleDraft draft) {
  final shots = draft.shots;
  if (shots.isEmpty) return ShotDraft.tee(draft.yards);
  if (shots.length == 1 && draft.par != 3 && !shots.first.isPenalty) {
    return ShotDraft(lie: lieAfterTeeShot(draft.fairwayHit));
  }
  // A par-3 tee shot that needs a second shot missed the green, and after a
  // penalty the ball is dropped somewhere: neither says where.
  return const ShotDraft();
}

/// Typical full-swing carry per club, in yards, for [suggestClub] — never
/// stored.
///
/// Deliberately omits the putter: a putt's distance is measured in feet on the
/// green, and putts are entered as rows of their own in the Putting section.
///
/// These are one generic player's numbers, so they will be wrong for somebody —
/// which is why [suggestClub] takes the bag as a parameter: the app already
/// stores every `(club, distance)` pair the user has ever entered in
/// `hole_shots`, so a learned per-player bag can replace this default.
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
/// Not called by the form at the moment: club suggestions are switched off for
/// now, at the player's request. It stays, tested, so turning them back on —
/// perhaps with a bag learned from the player's own `hole_shots` in place of
/// [defaultClubDistances] — is a call site, not a rewrite.
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
