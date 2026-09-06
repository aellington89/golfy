// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_set_dao.dart';

// ignore_for_file: type=lint
mixin _$CourseSetDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $CourseSetsTable get courseSets => attachedDatabase.courseSets;
  $CourseSetYardsTable get courseSetYards => attachedDatabase.courseSetYards;
  CourseSetDaoManager get managers => CourseSetDaoManager(this);
}

class CourseSetDaoManager {
  final _$CourseSetDaoMixin _db;
  CourseSetDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
  $$CourseSetsTableTableManager get courseSets =>
      $$CourseSetsTableTableManager(_db.attachedDatabase, _db.courseSets);
  $$CourseSetYardsTableTableManager get courseSetYards =>
      $$CourseSetYardsTableTableManager(
        _db.attachedDatabase,
        _db.courseSetYards,
      );
}
