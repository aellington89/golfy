import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/models/round_with_course.dart';
import '../../data/repository_provider.dart';
import '../../widgets/empty_state.dart';
import 'add_course_dialog.dart';
import 'course_holes_screen.dart';

/// Course-management screen (#36): every saved course with its game title and
/// round count, a FAB to add a new one, and tap-through to the [CourseHolesScreen]
/// to edit that course's per-hole template (par / yards / stroke index) or
/// rename / delete it. Pushed from the Rounds tab's "Manage courses" action and
/// the course picker — not a bottom-nav destination. Mirrors the Events tab.
///
/// Backed by [coursesByNameStreamProvider] (alphabetical); round counts are
/// derived in-memory from [roundsStreamProvider], matching the Events screen.
class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesByNameStreamProvider);
    final rounds =
        ref.watch(roundsStreamProvider).value ?? const <RoundWithCourse>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      floatingActionButton: coursesAsync.when(
        loading: () => null,
        error: (_, _) => null,
        data: (courses) => FloatingActionButton(
          onPressed: () => _openAddCourseDialog(context, courses),
          child: const Icon(Icons.add),
        ),
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load courses: $e')),
        data: (courses) {
          if (courses.isEmpty) {
            return const EmptyState(
              icon: Icons.golf_course_outlined,
              message: 'No courses yet. Tap + to add one.',
            );
          }
          final counts = _roundCounts(rounds);
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: courses.length,
            itemBuilder: (context, i) {
              final course = courses[i];
              return _CourseTile(
                course: course,
                roundCount: counts[course.id] ?? 0,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAddCourseDialog(
    BuildContext context,
    List<Course> courses,
  ) async {
    await showDialog<Course>(
      context: context,
      builder: (_) => AddCourseDialog(existingCourses: courses),
    );
  }

  /// Rounds attached to each course id, keyed by course id.
  static Map<int, int> _roundCounts(List<RoundWithCourse> rounds) {
    final counts = <int, int>{};
    for (final r in rounds) {
      final id = r.round.courseId;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.course, required this.roundCount});

  final Course course;
  final int roundCount;

  @override
  Widget build(BuildContext context) {
    final rounds = roundCount == 0
        ? 'No rounds yet'
        : (roundCount == 1 ? '1 round' : '$roundCount rounds');
    return ListTile(
      key: ValueKey('course_tile_${course.id}'),
      leading: const Icon(Icons.golf_course_outlined),
      title: Text(course.name),
      subtitle: Text('${course.gameTitle} · $rounds'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CourseHolesScreen(courseId: course.id),
        ),
      ),
    );
  }
}
