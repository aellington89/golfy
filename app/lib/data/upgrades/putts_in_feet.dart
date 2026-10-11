/// The putt conversion that comes with schema v8: putts saved with a distance
/// in yards — the only unit a shot had before v8 — are rewritten in feet.
///
/// Shared by the v7 -> v8 database migration and the v7 backup upgrader, so a
/// database and a backup of it come out of the upgrade holding the same rows.
/// Frozen on purpose: it reads shots as v7 recorded them, and must not follow
/// later changes to how the hole entry form tells a putt from a shot — a
/// device upgrading from v7 years from now has to get what one upgrading today
/// gets.
library;

/// One v7 `hole_shots` row, reduced to what the conversion reads.
typedef V7Shot = ({
  int id,
  int holeResultId,
  int shotNumber,
  String? club,
  String? lie,
  int? distanceYards,
});

/// Feet in a yard: a putt saved as 4 yards is 12 feet.
const int feetPerYard = 3;

/// The ids of the putts among [shots] that were saved with a distance in
/// yards — the rows the conversion rewrites in feet.
///
/// A hole's putts are the putt rows its shot list ends on (a putter, or a shot
/// played from the green), as many as its `putts` count says — [puttsByHole],
/// keyed by `hole_results` id — and never its first row, which is the tee shot.
/// That is the rule the v8 hole entry form reads a saved hole by, so every row
/// converted here is one the form shows as a putt, and every shot it shows with
/// a distance in yards keeps it.
Set<int> puttsSavedInYards(
  Iterable<V7Shot> shots,
  Map<int, int> puttsByHole,
) {
  final byHole = <int, List<V7Shot>>{};
  for (final s in shots) {
    (byHole[s.holeResultId] ??= <V7Shot>[]).add(s);
  }
  final ids = <int>{};
  byHole.forEach((hole, rows) {
    rows.sort((a, b) => a.shotNumber.compareTo(b.shotNumber));
    final putts = puttsByHole[hole] ?? 0;
    for (var i = rows.length - 1, counted = 0;
        i > 0 && counted < putts && _isPutt(rows[i]);
        i--, counted++) {
      if (rows[i].distanceYards != null) ids.add(rows[i].id);
    }
  });
  return ids;
}

bool _isPutt(V7Shot s) => s.club == 'Putter' || s.lie == 'Green';
