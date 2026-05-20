import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/courses.dart';
import 'tables/hole_results.dart';
import 'tables/rounds.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Courses, Rounds, HoleResults])
class GolfyDatabase extends _$GolfyDatabase {
  GolfyDatabase() : super(driftDatabase(name: 'golfy'));

  GolfyDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
