import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/courses.dart';

part 'course_dao.g.dart';

/// DAO for the `courses` table.
@DriftAccessor(tables: [Courses])
class CourseDao extends DatabaseAccessor<GolfyDatabase> with _$CourseDaoMixin {
  CourseDao(super.db);

  /// Inserts a new course and returns the generated row id. Throws if the
  /// (name, game_title) pair already exists (schema-level UNIQUE).
  Future<int> insert(CoursesCompanion course) =>
      into(courses).insert(course);

  /// Reactive list of every course, ordered by game title then course name.
  Stream<List<Course>> watchAll() {
    return (select(courses)
          ..orderBy([
            (c) => OrderingTerm.asc(c.gameTitle),
            (c) => OrderingTerm.asc(c.name),
          ]))
        .watch();
  }

  /// Reactive list of every course, ordered alphabetically by name only.
  /// Used by the course picker UI, which presents one flat list across games.
  Stream<List<Course>> watchAllByName() {
    return (select(courses)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }
}
