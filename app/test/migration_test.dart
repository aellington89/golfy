// Drift schema migration tests (#24).
//
// These prove the step-based `onUpgrade` harness end to end against drift's
// generated schema snapshots in `test/generated_migrations/`:
//   * the v1 -> v2 migration produces the expected schema,
//   * data written at v1 survives the upgrade, and
//   * a freshly created database matches the generated definitions.
//
// When the schema changes: bump `schemaVersion`, dump a new snapshot, add the
// `fromNToN+1` step, regenerate helpers, then extend the cases below. See
// app/README.md > "Database migrations".
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates the schema from v1 to v2', () async {
    final connection = await verifier.startAt(1);
    final db = GolfyDatabase.forTesting(connection);
    addTearDown(db.close);

    // Opens the db (running `onUpgrade`) and asserts the resulting sqlite
    // schema matches the generated v2 snapshot.
    await verifier.migrateAndValidate(db, 2);
  });

  test('migration preserves data written at v1', () async {
    final schema = await verifier.schemaAt(1);

    // Seed a course + round through the v1-shaped database (no canary column).
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    final courseId = await oldDb.into(oldDb.courses).insert(
          v1.CoursesCompanion.insert(
            name: 'Pebble Beach',
            gameTitle: 'PGA Tour 2K25',
          ),
        );
    await oldDb.into(oldDb.rounds).insert(
          v1.RoundsCompanion.insert(date: '2026-05-19', courseId: courseId),
        );
    await oldDb.close();

    // Migrate the same underlying database with the real app schema (v2).
    final db = GolfyDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    // The pre-existing rows survive, and the new column is null for them.
    final course = await db.select(db.courses).getSingle();
    expect(course.name, 'Pebble Beach');

    final round = await db.select(db.rounds).getSingle();
    expect(round.date, '2026-05-19');
    expect(round.courseId, courseId);
    expect(round.migrationCanary, isNull);
  });

  test('a freshly created database matches the generated schema', () async {
    final db = GolfyDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Validates that `onCreate` builds exactly what the current Dart
    // definitions describe — catches a forgotten migration after a table edit.
    await db.validateDatabaseSchema();
  });
}
