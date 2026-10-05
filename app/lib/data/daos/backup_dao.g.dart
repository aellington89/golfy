// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_dao.dart';

// ignore_for_file: type=lint
mixin _$BackupDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $CourseHolesTable get courseHoles => attachedDatabase.courseHoles;
  $CourseSetsTable get courseSets => attachedDatabase.courseSets;
  $CourseSetYardsTable get courseSetYards => attachedDatabase.courseSetYards;
  $EventsTable get events => attachedDatabase.events;
  $RoundsTable get rounds => attachedDatabase.rounds;
  $HoleResultsTable get holeResults => attachedDatabase.holeResults;
  $HoleShotsTable get holeShots => attachedDatabase.holeShots;
  BackupDaoManager get managers => BackupDaoManager(this);
}

class BackupDaoManager {
  final _$BackupDaoMixin _db;
  BackupDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
  $$CourseHolesTableTableManager get courseHoles =>
      $$CourseHolesTableTableManager(_db.attachedDatabase, _db.courseHoles);
  $$CourseSetsTableTableManager get courseSets =>
      $$CourseSetsTableTableManager(_db.attachedDatabase, _db.courseSets);
  $$CourseSetYardsTableTableManager get courseSetYards =>
      $$CourseSetYardsTableTableManager(
        _db.attachedDatabase,
        _db.courseSetYards,
      );
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db.attachedDatabase, _db.rounds);
  $$HoleResultsTableTableManager get holeResults =>
      $$HoleResultsTableTableManager(_db.attachedDatabase, _db.holeResults);
  $$HoleShotsTableTableManager get holeShots =>
      $$HoleShotsTableTableManager(_db.attachedDatabase, _db.holeShots);
}
