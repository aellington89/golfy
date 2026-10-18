// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_dao.dart';

// ignore_for_file: type=lint
mixin _$BackupDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $CourseHolesTable get courseHoles => attachedDatabase.courseHoles;
  $TeeSetsTable get teeSets => attachedDatabase.teeSets;
  $CourseYardsTable get courseYards => attachedDatabase.courseYards;
  $PinSetsTable get pinSets => attachedDatabase.pinSets;
  $TeeToPinYardsTable get teeToPinYards => attachedDatabase.teeToPinYards;
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
  $$TeeSetsTableTableManager get teeSets =>
      $$TeeSetsTableTableManager(_db.attachedDatabase, _db.teeSets);
  $$CourseYardsTableTableManager get courseYards =>
      $$CourseYardsTableTableManager(_db.attachedDatabase, _db.courseYards);
  $$PinSetsTableTableManager get pinSets =>
      $$PinSetsTableTableManager(_db.attachedDatabase, _db.pinSets);
  $$TeeToPinYardsTableTableManager get teeToPinYards =>
      $$TeeToPinYardsTableTableManager(_db.attachedDatabase, _db.teeToPinYards);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db.attachedDatabase, _db.rounds);
  $$HoleResultsTableTableManager get holeResults =>
      $$HoleResultsTableTableManager(_db.attachedDatabase, _db.holeResults);
  $$HoleShotsTableTableManager get holeShots =>
      $$HoleShotsTableTableManager(_db.attachedDatabase, _db.holeShots);
}
