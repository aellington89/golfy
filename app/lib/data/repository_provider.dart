import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'database_provider.dart';
import 'models/dashboard_stats.dart';
import 'models/event_stats.dart';
import 'models/round_with_course.dart';
import 'repository.dart';

/// The repository itself is stateless: it just delegates to the DAOs on the
/// shared [GolfyDatabase] instance. A plain [Provider] is correct here —
/// nothing needs a [Notifier] until per-screen edit-form state lands with
/// the round / hole-entry / dashboard UI work.
final repositoryProvider = Provider<GolfyRepository>((ref) {
  return GolfyRepository(ref.watch(databaseProvider));
});

/// Reactive list of courses, ordered (gameTitle, name).
final coursesStreamProvider = StreamProvider<List<Course>>((ref) {
  return ref.watch(repositoryProvider).watchCourses();
});

/// Reactive list of courses, ordered alphabetically by name. Used by the
/// course picker UI.
final coursesByNameStreamProvider = StreamProvider<List<Course>>((ref) {
  return ref.watch(repositoryProvider).watchCoursesByName();
});

/// Reactive shared per-hole card (par + stroke index) for a course (#36),
/// keyed on course id. Ordered by hole number; empty for a course with no card.
/// Backs the par/SI editor and the Hole Entry par auto-fill.
final courseHolesStreamProvider =
    StreamProvider.family<List<CourseHole>, int>((ref, courseId) {
  return ref.watch(repositoryProvider).watchCourseHoles(courseId);
});

/// Reactive list of a course's named yardage sets (#36), keyed on course id,
/// ordered by name. Backs the sets list and the New Round set picker.
final courseSetsStreamProvider =
    StreamProvider.family<List<CourseSet>, int>((ref, courseId) {
  return ref.watch(repositoryProvider).watchCourseSets(courseId);
});

/// Reactive per-hole yardage for a single yardage set (#36), keyed on set id.
/// Ordered by hole number; empty for a set with no yardages. Backs the set
/// yardage editor and the Hole Entry yards auto-fill.
final courseSetYardsStreamProvider =
    StreamProvider.family<List<CourseSetYard>, int>((ref, setId) {
  return ref.watch(repositoryProvider).watchCourseSetYards(setId);
});

/// Reactive list of events, ordered alphabetically by name. Used by the
/// event picker UI (mirrors [coursesByNameStreamProvider]).
final eventsStreamProvider = StreamProvider<List<Event>>((ref) {
  return ref.watch(repositoryProvider).watchEvents();
});

/// Reactive list of rounds joined with their course name, newest first.
final roundsStreamProvider = StreamProvider<List<RoundWithCourse>>((ref) {
  return ref.watch(repositoryProvider).watchRounds();
});

/// Reactive lookup of a single [RoundWithCourse] by id, derived from
/// [roundsStreamProvider]. Emits `null` if no round with the given id is
/// in the list. Sharing the underlying stream avoids a second DB watcher
/// for the Hole Entry header.
final roundWithCourseProvider =
    StreamProvider.family<RoundWithCourse?, int>((ref, roundId) {
  return ref.watch(repositoryProvider).watchRounds().map((rounds) {
    for (final r in rounds) {
      if (r.round.id == roundId) return r;
    }
    return null;
  });
});

/// Reactive list of the rounds belonging to a single event, newest first
/// (same shape as [roundsStreamProvider]). Family parameter is the event id.
/// Backed by a keyed DB query (`idx_rounds_event`), so consumers get one
/// event's rounds without re-scanning the full rounds stream client-side (#55).
final roundsForEventProvider =
    StreamProvider.family<List<RoundWithCourse>, int>((ref, eventId) {
  return ref.watch(repositoryProvider).watchRoundsForEvent(eventId);
});

/// Reactive list of hole_results for a specific round, ordered by hole
/// number. Family parameter is the round id.
final holeResultsStreamProvider =
    StreamProvider.family<List<HoleResult>, int>((ref, roundId) {
  return ref.watch(repositoryProvider).watchHoleResults(roundId);
});

/// Reactive per-shot lists for a round's holes (#22), keyed by hole number.
/// Family parameter is the round id; holes with no shots are absent from the
/// map. Backs the Hole Entry shot-list seeding.
final holeShotsStreamProvider =
    StreamProvider.family<Map<int, List<HoleShot>>, int>((ref, roundId) {
  return ref.watch(repositoryProvider).watchHoleShots(roundId);
});

/// Reactive aggregated lifetime stats for the dashboard.
final dashboardStatsStreamProvider = StreamProvider<DashboardStats>((ref) {
  return ref.watch(repositoryProvider).watchDashboardStats();
});

/// Reactive per-event scoring stats (#56), keyed on event id. The per-event
/// counterpart to [dashboardStatsStreamProvider]; backs the Event detail
/// screen's scoring summary card.
final eventStatsStreamProvider =
    StreamProvider.family<EventStats, int>((ref, eventId) {
  return ref.watch(repositoryProvider).watchEventStats(eventId);
});
