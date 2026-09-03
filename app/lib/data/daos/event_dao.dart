import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/events.dart';

part 'event_dao.g.dart';

/// DAO for the `events` table — competitions that group rounds (#35).
@DriftAccessor(tables: [Events])
class EventDao extends DatabaseAccessor<GolfyDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  /// Inserts a new event and returns the generated row id. Throws if an event
  /// with the same `(name, season)` already exists (schema-level UNIQUE) — the
  /// same name recurs across seasons as distinct occurrences (#47). Callers
  /// supply a name and season; the result is recorded later via [setResult].
  Future<int> insert(EventsCompanion event) => into(events).insert(event);

  /// Reactive list of every event, ordered by name then ascending season so a
  /// recurring competition's occurrences cluster together (Season 1, 2, 3…).
  Stream<List<Event>> watchAll() {
    return (select(events)
          ..orderBy([
            (e) => OrderingTerm.asc(e.name),
            (e) => OrderingTerm.asc(e.season),
          ]))
        .watch();
  }

  /// Looks up a single event by id. Returns null if no row matches.
  Future<Event?> getById(int id) {
    return (select(events)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  /// Records an event's result wholesale. Pass all three components so the
  /// stored row is fully specified — a "not recorded yet" result is
  /// `finishPosition: null, tied: false, missedCut: false`. Validates the
  /// position/tied/cut invariant before writing. Returns the rows updated
  /// (1 if the event existed, 0 otherwise).
  Future<int> setResult(
    int id, {
    int? finishPosition,
    bool tied = false,
    bool missedCut = false,
  }) {
    _assertResultInvariants(
      finishPosition: finishPosition,
      tied: tied,
      missedCut: missedCut,
    );
    return (update(events)..where((e) => e.id.equals(id))).write(
      EventsCompanion(
        finishPosition: Value(finishPosition),
        tied: Value(tied),
        missedCut: Value(missedCut),
      ),
    );
  }

  /// Updates a single event's identity — its [name] and [season] — leaving its
  /// result columns untouched. A UNIQUE(name, season) collision throws (the UI
  /// surfaces it as "already exists"), so an edit can land on an existing
  /// occurrence. Returns the rows updated (1 if the event existed, 0 otherwise).
  Future<int> updateDetails(
    int id, {
    required String name,
    required int season,
  }) {
    return (update(events)..where((e) => e.id.equals(id)))
        .write(EventsCompanion(name: Value(name), season: Value(season)));
  }

  /// Deletes a single event by id. Its rounds are detached (their `event_id`
  /// is set to NULL) via the schema-level `ON DELETE SET NULL`; round and hole
  /// data is preserved. Returns the number of rows deleted.
  Future<int> deleteById(int id) {
    return (delete(events)..where((e) => e.id.equals(id))).go();
  }

  /// Rejects impossible result states before the SQL hits the database,
  /// mirroring [HoleResultDao]'s invariant guard:
  ///   * a missed cut cannot also carry a finishing position or a tie, and
  ///   * a tie requires a finishing position, and
  ///   * a finishing position is 1-based.
  void _assertResultInvariants({
    required int? finishPosition,
    required bool tied,
    required bool missedCut,
  }) {
    if (missedCut && (finishPosition != null || tied)) {
      throw ArgumentError(
        'A missed-cut event cannot also have a finishing position.',
      );
    }
    if (tied && finishPosition == null) {
      throw ArgumentError('A tied result requires a finishing position.');
    }
    if (finishPosition != null && finishPosition < 1) {
      throw ArgumentError.value(
        finishPosition,
        'finishPosition',
        'must be >= 1',
      );
    }
  }
}
