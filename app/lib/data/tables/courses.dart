import 'package:drift/drift.dart';

class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get gameTitle => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, gameTitle},
      ];
}
