// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'round_dao.dart';

// ignore_for_file: type=lint
mixin _$RoundDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $RoundsTable get rounds => attachedDatabase.rounds;
  RoundDaoManager get managers => RoundDaoManager(this);
}

class RoundDaoManager {
  final _$RoundDaoMixin _db;
  RoundDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db.attachedDatabase, _db.rounds);
}
