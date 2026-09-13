/// Starting points for a course's per-hole card (#81).
///
/// Pure Dart on purpose — no Flutter, no drift — so the numbers are unit-tested
/// directly and can't drift away from the CHECK constraints they have to satisfy
/// (`par BETWEEN 3 AND 5`, `yards >= 0`).
///
/// Nothing here is ever written to the database on the user's behalf. The editor
/// seeds these values into its in-memory state and marks every hole unsaved, so
/// a guess is something the user *accepts* rather than inherits — and an
/// unreviewed default never becomes indistinguishable from a real card.
library;

/// A conventional 18-hole par-72 layout: four par 3s, four par 5s, ten par 4s,
/// 36 out and 36 in. Not any particular course — just a far better first guess
/// than eighteen par 4s, and the shape most video-game courses follow.
const List<int> standardPar72 = [
  4, 5, 3, 4, 4, 3, 4, 5, 4, // out — 36
  4, 3, 5, 4, 4, 4, 3, 5, 4, // in  — 36
];

/// Par for [holeNumber] (1-based) from [standardPar72], falling back to 4 for a
/// hole number outside the standard 18.
int defaultParForHole(int holeNumber) {
  if (holeNumber < 1 || holeNumber > standardPar72.length) return 4;
  return standardPar72[holeNumber - 1];
}

/// Shifts a yardage card by [offsetYards], clamped at zero.
///
/// Used when a new yardage set is copied from an existing one: tee boxes on the
/// same course are highly correlated, so "the blues, minus 20" beats retyping
/// eighteen numbers. A flat offset is only ever an approximation — real tee
/// boxes differ hole by hole — which is exactly why the result lands in the
/// editor as unsaved changes for review rather than going straight to the
/// database.
List<int> applyYardOffset(List<int> yards, int offsetYards) => [
      for (final y in yards) (y + offsetYards).clamp(0, 100000),
    ];
