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

  /// Updates a course's identity (name / game title) in place. Pass a companion
  /// carrying only the columns to change. The `(name, game_title)` UNIQUE still
  /// applies, so an update colliding with another course throws — callers
  /// pre-check and also catch the DB-level error as a safety net (mirroring
  /// [insert]). Returns the number of rows updated (1 if the course existed).
  Future<int> updateById(int id, CoursesCompanion course) {
    return (update(courses)..where((c) => c.id.equals(id))).write(course);
  }

  /// Deletes a course by id. The `rounds.course_id` foreign key is RESTRICT, so
  /// this throws if any round still references the course — callers gate on the
  /// course's round count first and catch the DB error as a safety net. Its
  /// `course_holes` template rows cascade away. Returns the number of rows
  /// deleted (1 if the course existed, 0 otherwise).
  Future<int> deleteById(int id) {
    return (delete(courses)..where((c) => c.id.equals(id))).go();
  }

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
