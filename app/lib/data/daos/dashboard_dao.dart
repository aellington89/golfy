import 'package:drift/drift.dart';

import '../database.dart';
import '../models/dashboard_stats.dart';
import '../tables/courses.dart';
import '../tables/hole_results.dart';
import '../tables/rounds.dart';

part 'dashboard_dao.g.dart';

/// Read-only aggregation queries that power the lifetime-stats dashboard.
///
/// The screen renders a single [DashboardStats] snapshot. We use one inert
/// `customSelect` with `readsFrom` covering all three source tables as a
/// change trigger, then re-run the full aggregate pipeline on every emission.
/// This keeps the SQL self-contained (no client-side combiners) and re-emits
/// exactly when any underlying row changes.
@DriftAccessor(tables: [HoleResults, Rounds, Courses])
class DashboardDao extends DatabaseAccessor<GolfyDatabase>
    with _$DashboardDaoMixin {
  DashboardDao(super.db);

  /// All scalar lifetime aggregates packed into a single SQL row. `NULLIF`
  /// on each denominator turns division-by-zero into SQL NULL, which surfaces
  /// in Dart as `null` (mapped to em-dash in the UI). When `hole_results` is
  /// empty, every aggregate column is NULL except `rounds_played` (which is
  /// 0).
  static const _scalarSql = '''
    SELECT
      COUNT(DISTINCT round_id) AS rounds_played,
      CAST(SUM(score) AS REAL)
        / NULLIF(COUNT(DISTINCT round_id), 0) AS avg_score_per_round,
      CAST(SUM(score - par) AS REAL)
        / NULLIF(COUNT(DISTINCT round_id), 0) AS avg_score_vs_par,
      CAST(SUM(CASE WHEN fairway_hit = 1 THEN 1 ELSE 0 END) AS REAL)
        / NULLIF(SUM(CASE WHEN fairway_hit IS NOT NULL THEN 1 ELSE 0 END), 0)
          AS fairway_pct,
      CAST(SUM(CASE WHEN gir = 1 THEN 1 ELSE 0 END) AS REAL)
        / NULLIF(COUNT(*), 0) AS gir_pct,
      AVG(CAST(putts AS REAL)) AS avg_putts,
      CAST(SUM(CASE WHEN up_down_success = 1 THEN 1 ELSE 0 END) AS REAL)
        / NULLIF(SUM(CASE WHEN up_down_attempt = 1 THEN 1 ELSE 0 END), 0)
          AS up_down_pct,
      CAST(SUM(CASE WHEN penalty_strokes > 0 THEN 1 ELSE 0 END) AS REAL)
        / NULLIF(COUNT(*), 0) AS penalty_hole_pct,
      CAST(SUM(penalty_strokes) AS REAL)
        / NULLIF(COUNT(*), 0) AS avg_penalty_strokes
    FROM hole_results
  ''';

  static const _bestRoundSql = '''
    SELECT r.id AS round_id, c.name AS course_name, r.date AS date,
           SUM(h.score - h.par) AS to_par
    FROM rounds r
    JOIN courses c ON c.id = r.course_id
    JOIN hole_results h ON h.round_id = r.id
    GROUP BY r.id
    HAVING COUNT(h.id) > 0
    ORDER BY to_par ASC, r.date DESC
    LIMIT 1
  ''';

  static const _scoreDistSql = '''
    SELECT (score - par) AS bucket, COUNT(*) AS c
    FROM hole_results
    GROUP BY bucket
    ORDER BY bucket
  ''';

  /// Reactive lifetime stats. Re-emits whenever any of `hole_results`,
  /// `rounds`, or `courses` changes.
  Stream<DashboardStats> watchStats() {
    // Inert trigger query: drift's change tracker watches `readsFrom`, and
    // re-runs the listener on every commit that touches those tables.
    return customSelect(
      'SELECT 1',
      readsFrom: {holeResults, rounds, courses},
    ).watch().asyncMap((_) => _computeStats());
  }

  Future<DashboardStats> _computeStats() async {
    final scalars = await customSelect(
      _scalarSql,
      readsFrom: {holeResults},
    ).getSingle();
    final bestRoundRows = await customSelect(
      _bestRoundSql,
      readsFrom: {rounds, courses, holeResults},
    ).get();
    final distRows = await customSelect(
      _scoreDistSql,
      readsFrom: {holeResults},
    ).get();

    final roundsPlayed = scalars.read<int>('rounds_played');
    final distribution = distRows
        .map((r) => ScoreBucket(
              scoreVsPar: r.read<int>('bucket'),
              count: r.read<int>('c'),
            ))
        .toList(growable: false);
    final bestRound = bestRoundRows.isEmpty
        ? null
        : BestRound(
            roundId: bestRoundRows.first.read<int>('round_id'),
            courseName: bestRoundRows.first.read<String>('course_name'),
            date: bestRoundRows.first.read<String>('date'),
            toPar: bestRoundRows.first.read<int>('to_par'),
          );

    return DashboardStats(
      roundsPlayed: roundsPlayed,
      avgScorePerRound: scalars.readNullable<double>('avg_score_per_round'),
      avgScoreVsPar: scalars.readNullable<double>('avg_score_vs_par'),
      fairwayHitPct: scalars.readNullable<double>('fairway_pct'),
      girPct: scalars.readNullable<double>('gir_pct'),
      avgPuttsPerHole: scalars.readNullable<double>('avg_putts'),
      upDownPct: scalars.readNullable<double>('up_down_pct'),
      penaltyHolePct: scalars.readNullable<double>('penalty_hole_pct'),
      avgPenaltyStrokesPerHole:
          scalars.readNullable<double>('avg_penalty_strokes'),
      scoreDistribution: distribution,
      bestRound: bestRound,
    );
  }
}
