import 'package:drift/drift.dart';

import '../database.dart';
import '../models/round_with_course.dart';
import '../tables/courses.dart';
import '../tables/events.dart';
import '../tables/hole_results.dart';
import '../tables/rounds.dart';

part 'round_dao.g.dart';

/// DAO for the `rounds` table plus the rounds-with-course-name join used by
/// the rounds list screen.
@DriftAccessor(tables: [Rounds, Courses, HoleResults, Events])
class RoundDao extends DatabaseAccessor<GolfyDatabase> with _$RoundDaoMixin {
  RoundDao(super.db);

  /// Inserts a new round and returns the generated row id. The `courseId`
  /// must reference an existing course (FK RESTRICT).
  Future<int> insert(RoundsCompanion round) => into(rounds).insert(round);

  /// Looks up a single round by id. Returns null if no row matches.
  Future<Round?> getById(int id) {
    return (select(rounds)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Deletes a single round by id. Cascade-deletes its hole_results via the
  /// schema-level `ON DELETE CASCADE`. Returns the number of rows deleted
  /// (1 if the round existed, 0 otherwise).
  Future<int> deleteById(int id) {
    return (delete(rounds)..where((r) => r.id.equals(id))).go();
  }

  /// Updates a single round in place (#45). Pass a companion carrying only the
  /// columns to change; a present `Value(null)` explicitly clears a nullable
  /// column — e.g. `eventId: Value(null)` detaches the round from its event,
  /// while `Value.absent()` leaves a column untouched. Returns the number of
  /// rows updated (1 if the round existed, 0 otherwise).
  ///
  /// The `UNIQUE(date, courseId, roundNumber)` constraint and the `courseId`
  /// FK (RESTRICT) still apply, so an update that collides with another round
  /// or points at a missing course throws — callers pre-check and also catch
  /// the DB-level error as a safety net (mirroring [insert]).
  Future<int> updateById(int id, RoundsCompanion round) {
    return (update(rounds)..where((r) => r.id.equals(id))).write(round);
  }

  /// Reactive list of every round joined with its course's name and its
  /// optional event, the count of hole_results rows attached to it, and the
  /// summed score / par across those holes (for the rounds-list score-vs-par
  /// label). Ordered newest first — see [_watchRoundsWithCourse].
  Stream<List<RoundWithCourse>> watchAllWithCourse() => _watchRoundsWithCourse();

  /// Reactive list of the rounds belonging to the event [eventId], in the same
  /// shape and newest-first order as [watchAllWithCourse]. Filters on
  /// `rounds.event_id` — backed by the `idx_rounds_event` index (#35) — so the
  /// Events feature can query one event's rounds directly instead of
  /// re-scanning the full rounds stream client-side (#55).
  Stream<List<RoundWithCourse>> watchRoundsForEvent(int eventId) =>
      _watchRoundsWithCourse(filter: rounds.eventId.equals(eventId));

  /// Shared query behind [watchAllWithCourse] and [watchRoundsForEvent].
  ///
  /// Uses a `LEFT OUTER JOIN` to `hole_results` so rounds with no holes
  /// entered still appear (with `holesEntered = 0`); their `SUM`s are SQL NULL,
  /// coerced to `0` (the UI suppresses the score label when `holesEntered == 0`
  /// rather than rendering a misleading `E`). The `events` join is also a
  /// `LEFT OUTER JOIN` so casual rounds (no `eventId`) keep a null `event`, and
  /// because it joins `events`, the stream re-emits when an event's recorded
  /// result changes — keeping the grouped rounds list's result badges live.
  ///
  /// Ordered newest first by date, breaking ties by descending row id so the
  /// most recently inserted round wins on the same date. [filter], when given,
  /// is applied as a `WHERE` on the joined query to narrow the rows.
  Stream<List<RoundWithCourse>> _watchRoundsWithCourse({
    Expression<bool>? filter,
  }) {
    final holeCount = holeResults.id.count();
    final scoreSum = holeResults.score.sum();
    final parSum = holeResults.par.sum();
    final query = select(rounds).join([
      innerJoin(courses, courses.id.equalsExp(rounds.courseId)),
      leftOuterJoin(events, events.id.equalsExp(rounds.eventId)),
      leftOuterJoin(
        holeResults,
        holeResults.roundId.equalsExp(rounds.id),
      ),
    ])
      ..addColumns([holeCount, scoreSum, parSum])
      ..groupBy([rounds.id])
      ..orderBy([
        OrderingTerm.desc(rounds.date),
        OrderingTerm.desc(rounds.id),
      ]);
    if (filter != null) {
      query.where(filter);
    }

    return query.watch().map((rows) {
      return rows
          .map((row) => RoundWithCourse(
                round: row.readTable(rounds),
                courseName: row.readTable(courses).name,
                event: row.readTableOrNull(events),
                holesEntered: row.read(holeCount) ?? 0,
                totalScore: row.read(scoreSum) ?? 0,
                totalPar: row.read(parSum) ?? 0,
              ))
          .toList();
    });
  }
}
