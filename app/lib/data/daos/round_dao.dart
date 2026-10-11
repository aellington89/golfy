import 'package:drift/drift.dart';

import '../database.dart';
import '../models/round_with_course.dart';
import '../tables/courses.dart';
import '../tables/events.dart';
import '../tables/hole_results.dart';
import '../tables/pin_sets.dart';
import '../tables/rounds.dart';
import '../tables/tee_sets.dart';

part 'round_dao.g.dart';

/// DAO for the `rounds` table plus the rounds-with-course-name join used by
/// the rounds list screen.
@DriftAccessor(
    tables: [Rounds, Courses, HoleResults, Events, TeeSets, PinSets])
class RoundDao extends DatabaseAccessor<GolfyDatabase> with _$RoundDaoMixin {
  RoundDao(super.db);

  /// Inserts a new round and returns the generated row id. The `courseId`
  /// must reference an existing course (FK RESTRICT).
  ///
  /// Throws [ArgumentError] when the round's tee set or pin set belongs to
  /// another course — see [_assertYardageSetOnCourse].
  Future<int> insert(RoundsCompanion round) async {
    await _assertYardageSetOnCourse(
      round.courseId.value,
      round.teeSetId.present ? round.teeSetId.value : null,
      round.pinSetId.present ? round.pinSetId.value : null,
    );
    return into(rounds).insert(round);
  }

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
  ///
  /// Throws [ArgumentError] when the update would leave the round's tee set or
  /// pin set on another course — so moving a round to a different course must
  /// clear or replace both in the same companion.
  Future<int> updateById(int id, RoundsCompanion round) async {
    // Only an update that moves the course or a set can break the pairing.
    if (round.courseId.present ||
        round.teeSetId.present ||
        round.pinSetId.present) {
      final current = await getById(id);
      if (current != null) {
        await _assertYardageSetOnCourse(
          round.courseId.present ? round.courseId.value : current.courseId,
          round.teeSetId.present ? round.teeSetId.value : current.teeSetId,
          round.pinSetId.present ? round.pinSetId.value : current.pinSetId,
        );
      }
    }
    return (update(rounds)..where((r) => r.id.equals(id))).write(round);
  }

  /// A round's yardage set has to be on the round's own course: a tee set or
  /// pin set from another course would pre-fill yards for holes that aren't
  /// these ones. SQL can't say so across the three tables, so this does.
  ///
  /// A set that doesn't exist is left for the foreign key to refuse.
  Future<void> _assertYardageSetOnCourse(
    int courseId,
    int? teeSetId,
    int? pinSetId,
  ) async {
    if (teeSetId != null) {
      final tee = await (select(teeSets)..where((s) => s.id.equals(teeSetId)))
          .getSingleOrNull();
      if (tee != null && tee.courseId != courseId) {
        throw ArgumentError(
          'tee set $teeSetId is on course ${tee.courseId}, not $courseId',
        );
      }
    }
    if (pinSetId != null) {
      final pin = await (select(pinSets)..where((s) => s.id.equals(pinSetId)))
          .getSingleOrNull();
      if (pin != null && pin.courseId != courseId) {
        throw ArgumentError(
          'pin set $pinSetId is on course ${pin.courseId}, not $courseId',
        );
      }
    }
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
      // Joined on each set's primary key, so they can't multiply rows the way
      // the hole_results join does.
      leftOuterJoin(teeSets, teeSets.id.equalsExp(rounds.teeSetId)),
      leftOuterJoin(pinSets, pinSets.id.equalsExp(rounds.pinSetId)),
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
                teeSetName: row.readTableOrNull(teeSets)?.name,
                pinSetName: row.readTableOrNull(pinSets)?.name,
                holesEntered: row.read(holeCount) ?? 0,
                totalScore: row.read(scoreSum) ?? 0,
                totalPar: row.read(parSum) ?? 0,
              ))
          .toList();
    });
  }
}
