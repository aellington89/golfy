import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/hole_results.dart';

part 'hole_result_dao.g.dart';

/// DAO for the `hole_results` table.
@DriftAccessor(tables: [HoleResults])
class HoleResultDao extends DatabaseAccessor<GolfyDatabase>
    with _$HoleResultDaoMixin {
  HoleResultDao(super.db);

  /// Inserts a hole result, or updates the existing row when the
  /// `(round_id, hole_number)` pair already exists. Uses a real
  /// `INSERT ... ON CONFLICT(round_id, hole_number) DO UPDATE` so the row's
  /// `id` is preserved across edits (avoiding the foot-guns of
  /// `INSERT OR REPLACE`, which would delete + reinsert).
  ///
  /// Throws [ArgumentError] when a companion violates one of the
  /// app-layer invariants: see [_assertInvariants].
  Future<int> upsert(HoleResultsCompanion hole) {
    _assertInvariants(hole);
    return into(holeResults).insert(
      hole,
      onConflict: DoUpdate(
        (_) => hole,
        target: [holeResults.roundId, holeResults.holeNumber],
      ),
    );
  }

  /// Reactive list of every hole_result for a round, ordered by hole number.
  Stream<List<HoleResult>> watchForRound(int roundId) {
    return (select(holeResults)
          ..where((h) => h.roundId.equals(roundId))
          ..orderBy([(h) => OrderingTerm.asc(h.holeNumber)]))
        .watch();
  }

  /// Number of hole_result rows for a round. Used by the round-in-progress
  /// indicator on the round list.
  Future<int> countForRound(int roundId) async {
    final count = holeResults.id.count();
    final row = await (selectOnly(holeResults)
          ..addColumns([count])
          ..where(holeResults.roundId.equals(roundId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Validates the three "impossible state" combinations the database does
  /// not enforce at the SQL level:
  ///
  /// * `upDownSuccess = true` requires `upDownAttempt = true`
  /// * `sandSave = true` requires `bunkerVisited = true`
  /// * `par = 3` cannot have a non-null `fairwayHit` (par 3s have no fairway)
  ///
  /// Validation is skipped when the corresponding field is `Value.absent()`,
  /// so partial updates that omit a field don't spuriously trip the check.
  void _assertInvariants(HoleResultsCompanion h) {
    final upDownAttempt = h.upDownAttempt.present ? h.upDownAttempt.value : null;
    final upDownSuccess = h.upDownSuccess.present ? h.upDownSuccess.value : null;
    if (upDownAttempt != null &&
        upDownSuccess != null &&
        upDownSuccess &&
        !upDownAttempt) {
      throw ArgumentError(
        'upDownSuccess=true requires upDownAttempt=true',
      );
    }

    final bunkerVisited =
        h.bunkerVisited.present ? h.bunkerVisited.value : null;
    final sandSave = h.sandSave.present ? h.sandSave.value : null;
    if (bunkerVisited != null &&
        sandSave != null &&
        sandSave &&
        !bunkerVisited) {
      throw ArgumentError(
        'sandSave=true requires bunkerVisited=true',
      );
    }

    final par = h.par.present ? h.par.value : null;
    final fairwayHit = h.fairwayHit.present ? h.fairwayHit.value : null;
    if (par == 3 && h.fairwayHit.present && fairwayHit != null) {
      throw ArgumentError(
        'par 3 holes have no fairway; fairwayHit must be null',
      );
    }
  }
}
