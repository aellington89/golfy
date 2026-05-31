import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'database_provider.dart';
import 'models/dashboard_stats.dart';
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

/// Reactive list of hole_results for a specific round, ordered by hole
/// number. Family parameter is the round id.
final holeResultsStreamProvider =
    StreamProvider.family<List<HoleResult>, int>((ref, roundId) {
  return ref.watch(repositoryProvider).watchHoleResults(roundId);
});

/// Reactive aggregated lifetime stats for the dashboard.
final dashboardStatsStreamProvider = StreamProvider<DashboardStats>((ref) {
  return ref.watch(repositoryProvider).watchDashboardStats();
});
