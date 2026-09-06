// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hole_result_dao.dart';

// ignore_for_file: type=lint
mixin _$HoleResultDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $CourseSetsTable get courseSets => attachedDatabase.courseSets;
  $EventsTable get events => attachedDatabase.events;
  $RoundsTable get rounds => attachedDatabase.rounds;
  $HoleResultsTable get holeResults => attachedDatabase.holeResults;
  HoleResultDaoManager get managers => HoleResultDaoManager(this);
}

class HoleResultDaoManager {
  final _$HoleResultDaoMixin _db;
  HoleResultDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
  $$CourseSetsTableTableManager get courseSets =>
      $$CourseSetsTableTableManager(_db.attachedDatabase, _db.courseSets);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db.attachedDatabase, _db.rounds);
  $$HoleResultsTableTableManager get holeResults =>
      $$HoleResultsTableTableManager(_db.attachedDatabase, _db.holeResults);
}
