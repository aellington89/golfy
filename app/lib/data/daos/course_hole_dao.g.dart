// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_hole_dao.dart';

// ignore_for_file: type=lint
mixin _$CourseHoleDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $CourseHolesTable get courseHoles => attachedDatabase.courseHoles;
  CourseHoleDaoManager get managers => CourseHoleDaoManager(this);
}

class CourseHoleDaoManager {
  final _$CourseHoleDaoMixin _db;
  CourseHoleDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
  $$CourseHolesTableTableManager get courseHoles =>
      $$CourseHolesTableTableManager(_db.attachedDatabase, _db.courseHoles);
}
