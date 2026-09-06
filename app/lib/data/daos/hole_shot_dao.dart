import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/hole_results.dart';
import '../tables/hole_shots.dart';

part 'hole_shot_dao.g.dart';

/// DAO for `hole_shots` — a hole's ordered per-shot list (#22).
@DriftAccessor(tables: [HoleShots, HoleResults])
class HoleShotDao extends DatabaseAccessor<GolfyDatabase>
    with _$HoleShotDaoMixin {
  HoleShotDao(super.db);

  /// Reactive shots for every hole of a round, keyed by hole number and each
  /// list ordered by shot number. Joins to `hole_results` so a single query
  /// covers the whole round; holes with no shots are simply absent from the map.
  Stream<Map<int, List<HoleShot>>> watchForRound(int roundId) {
    final query = select(holeShots).join([
      innerJoin(
        holeResults,
        holeResults.id.equalsExp(holeShots.holeResultId),
      ),
    ])
      ..where(holeResults.roundId.equals(roundId))
      ..orderBy([
        OrderingTerm.asc(holeResults.holeNumber),
        OrderingTerm.asc(holeShots.shotNumber),
      ]);
    return query.watch().map((rows) {
      final byHole = <int, List<HoleShot>>{};
      for (final row in rows) {
        final holeNumber = row.readTable(holeResults).holeNumber;
        (byHole[holeNumber] ??= <HoleShot>[]).add(row.readTable(holeShots));
      }
      return byHole;
    });
  }

  /// Replaces a hole's entire shot list in one transaction: clears the existing
  /// rows for the hole_results row, then inserts [shots]. Each companion must
  /// carry `holeResultId == holeResultId` and a 1-based `shotNumber`.
  Future<void> replaceForHole(
    int holeResultId,
    List<HoleShotsCompanion> shots,
  ) {
    return transaction(() async {
      await (delete(holeShots)
            ..where((s) => s.holeResultId.equals(holeResultId)))
          .go();
      await batch((b) => b.insertAll(holeShots, shots));
    });
  }
}
