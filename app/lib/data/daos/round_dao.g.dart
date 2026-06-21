// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'round_dao.dart';

// ignore_for_file: type=lint
mixin _$RoundDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $EventsTable get events => attachedDatabase.events;
  $RoundsTable get rounds => attachedDatabase.rounds;
  $HoleResultsTable get holeResults => attachedDatabase.holeResults;
  RoundDaoManager get managers => RoundDaoManager(this);
}

class RoundDaoManager {
  final _$RoundDaoMixin _db;
  RoundDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db.attachedDatabase, _db.rounds);
  $$HoleResultsTableTableManager get holeResults =>
      $$HoleResultsTableTableManager(_db.attachedDatabase, _db.holeResults);
}
