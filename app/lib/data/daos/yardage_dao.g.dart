// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yardage_dao.dart';

// ignore_for_file: type=lint
mixin _$YardageDaoMixin on DatabaseAccessor<GolfyDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  $TeeSetsTable get teeSets => attachedDatabase.teeSets;
  $PinSetsTable get pinSets => attachedDatabase.pinSets;
  $CourseYardsTable get courseYards => attachedDatabase.courseYards;
  $TeeToPinYardsTable get teeToPinYards => attachedDatabase.teeToPinYards;
  YardageDaoManager get managers => YardageDaoManager(this);
}

class YardageDaoManager {
  final _$YardageDaoMixin _db;
  YardageDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
  $$TeeSetsTableTableManager get teeSets =>
      $$TeeSetsTableTableManager(_db.attachedDatabase, _db.teeSets);
  $$PinSetsTableTableManager get pinSets =>
      $$PinSetsTableTableManager(_db.attachedDatabase, _db.pinSets);
  $$CourseYardsTableTableManager get courseYards =>
      $$CourseYardsTableTableManager(_db.attachedDatabase, _db.courseYards);
  $$TeeToPinYardsTableTableManager get teeToPinYards =>
      $$TeeToPinYardsTableTableManager(_db.attachedDatabase, _db.teeToPinYards);
}
