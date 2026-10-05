// Guard tests for the backup format (#69).
//
// These exist to fail. Each one turns a change that would silently alter — or
// silently shrink — everybody's backups into a red test with an explanation:
//
//   * a ninth table added to the schema and not to the payload,
//   * a column added, renamed or dropped, changing the file's keys,
//   * a `schemaVersion` bump, which is the moment to decide whether backups
//     written before it can still be read (and to register an upgrader).
//
// If one of these fails, read BACKUP_FORMAT.md > "When the schema changes"
// before changing the test.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
import 'package:golfy_app/data/database.dart';

import '_sample.dart';

void main() {
  late GolfyDatabase db;

  setUp(() {
    db = GolfyDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('every table in the schema is in the backup', () {
    final inSchema = db.allTables.map((t) => t.actualTableName).toSet();

    expect(
      const BackupPayload.empty().tables.keys.toSet(),
      inSchema,
      reason: 'a table the schema has but the backup does not is data no '
          'user can ever get off their device. Add it to BackupPayload, to '
          'backupTableOrder (parents first) and to the codec, then regenerate '
          'the golden files.',
    );
    expect(backupTableOrder.toSet(), inSchema);
    expect(backupTableOrder, hasLength(inSchema.length));
  });

  test('every column of every table is in the backup', () {
    final sample = samplePayload().tables;

    for (final table in db.allTables) {
      final rows = sample[table.actualTableName]!;
      expect(
        rows,
        isNotEmpty,
        reason: 'the sample payload in _sample.dart needs a '
            '${table.actualTableName} row to check its columns against',
      );

      expect(
        rows.first.toJson().keys.toSet(),
        table.columnsByName.keys.toSet(),
        reason: 'the keys written for ${table.actualTableName} no longer '
            'match its columns. A renamed or dropped column changes the '
            'backup format for files that already exist — see '
            'BACKUP_FORMAT.md.',
      );
    }
  });

  test('the codec reads the schema version the app is on', () {
    expect(
      BackupCodec.supportedSchemaVersion,
      db.schemaVersion,
      reason: 'the schema moved. Decide what happens to backups written at '
          'version ${BackupCodec.supportedSchemaVersion}: either register a '
          'payload upgrader in BackupCodec and capture a golden file at the '
          'old version, or declare the break with a `- **BREAKING:**` '
          'changelog entry (RELEASING.md). Then bump '
          'supportedSchemaVersion.',
    );
  });

  test('a backup states the same schema version it was written at', () {
    expect(
      manifestOf(sampleTree())['schemaVersion'],
      db.schemaVersion,
    );
  });
}
