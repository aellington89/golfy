// Backup format, read side (#69) — the half that makes the file importable.
//
// Decoding is *total*: a file is either fully understood or refused, naming
// what defeated it. #70 relies on that, because a restore that acted on a
// half-read backup would lose data silently. These tests damage one thing at a
// time and assert on the complaint.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_format_exception.dart';
import 'package:golfy_app/data/backup/backup_manifest.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';
import 'package:golfy_app/data/database.dart';

import '_sample.dart';

/// Matches a [BackupFormatException] carrying [problem], and optionally a
/// message fragment and a location.
Matcher throwsBackup(
  BackupFormatProblem problem, {
  String? mentioning,
  String? table,
  int? rowIndex,
}) {
  return throwsA(
    isA<BackupFormatException>()
        .having((e) => e.problem, 'problem', problem)
        .having(
          (e) => e.message,
          'message',
          mentioning == null ? anything : contains(mentioning),
        )
        .having((e) => e.table, 'table', table ?? anything)
        .having((e) => e.rowIndex, 'rowIndex', rowIndex ?? anything),
  );
}

void main() {
  group('a file that is not a backup', () {
    test('rejects text that is not JSON', () {
      expect(
        () => BackupCodec.decode('this is my scorecard, not JSON'),
        throwsBackup(BackupFormatProblem.notJson),
      );
    });

    test('rejects an empty file', () {
      expect(
        () => BackupCodec.decode(''),
        throwsBackup(BackupFormatProblem.notJson),
      );
    });

    test('rejects JSON that is not an object', () {
      expect(
        () => BackupCodec.decode('[1, 2, 3]'),
        throwsBackup(BackupFormatProblem.notJson, mentioning: 'JSON object'),
      );
    });

    test('rejects an object with no golfyBackup section', () {
      expect(
        () => BackupCodec.decode('{"data": {}}'),
        throwsBackup(
          BackupFormatProblem.missingManifest,
          mentioning: 'does not look like a Golfy backup',
        ),
      );
    });
  });

  group('a damaged manifest', () {
    test('rejects a non-numeric formatVersion', () {
      final tree = sampleTree();
      manifestOf(tree)['formatVersion'] = 'one';

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badManifestField,
            mentioning: 'formatVersion'),
      );
    });

    test('rejects a missing schemaVersion', () {
      final tree = sampleTree();
      manifestOf(tree).remove('schemaVersion');

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badManifestField,
            mentioning: 'schemaVersion'),
      );
    });

    test('rejects an exportedAt that is not a date', () {
      final tree = sampleTree();
      manifestOf(tree)['exportedAt'] = 'last Tuesday';

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badManifestField,
            mentioning: 'not a date'),
      );
    });

    test('rejects an empty platform', () {
      final tree = sampleTree();
      manifestOf(tree)['platform'] = '';

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badManifestField,
            mentioning: 'platform'),
      );
    });

    test('rejects rowCounts that is not an object', () {
      final tree = sampleTree();
      manifestOf(tree)['rowCounts'] = 9;

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badManifestField,
            mentioning: 'rowCounts'),
      );
    });

    test('rejects a rowCounts entry that is not a number', () {
      final tree = sampleTree();
      (manifestOf(tree)['rowCounts']! as Map<String, Object?>)['courses'] =
          'lots';

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badManifestField),
      );
    });
  });

  group('version gatekeeping', () {
    test('rejects a container version it does not know', () {
      final tree = sampleTree();
      manifestOf(tree)['formatVersion'] = 2;

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.unsupportedFormatVersion,
            mentioning: 'cannot be read by this version of Golfy'),
      );
    });

    test('refuses a backup from a newer Golfy', () {
      final tree = sampleTree();
      manifestOf(tree)['schemaVersion'] =
          BackupCodec.supportedSchemaVersion + 1;

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.newerSchemaVersion,
            mentioning: 'newer version of Golfy'),
      );
    });

    test('refuses an older data version it has no upgrader for', () {
      // No Golfy build can have written this — export did not exist before
      // schema v7 — but a hand-made file can claim anything, and the refusal
      // has to be the readable kind.
      final tree = sampleTree();
      manifestOf(tree)['schemaVersion'] =
          BackupCodec.supportedSchemaVersion - 1;

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.unsupportedSchemaVersion,
            mentioning: 'cannot upgrade'),
      );
    });

    test('accepts its own schema version', () {
      expect(
        BackupCodec.decode(encodeSample()).manifest.schemaVersion,
        BackupCodec.supportedSchemaVersion,
      );
    });
  });

  group('damaged tables', () {
    test('rejects a file with no data section', () {
      final tree = sampleTree();
      tree.remove('data');

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.missingData),
      );
    });

    test('rejects a table the schema does not have', () {
      final tree = sampleTree();
      dataOf(tree)['penalties'] = <Object?>[];

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.unknownTable,
            mentioning: 'penalties', table: 'penalties'),
      );
    });

    test('rejects a missing table', () {
      final tree = sampleTree();
      dataOf(tree).remove('events');

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.missingTable, table: 'events'),
      );
    });

    test('rejects a table that is not a list of rows', () {
      final tree = sampleTree();
      dataOf(tree)['courses'] = <String, Object?>{'id': 1};

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.missingTable,
            mentioning: 'must be a list of rows', table: 'courses'),
      );
    });

    test('does not care what order the tables appear in', () {
      // An importer uses its own ordering, so a file assembled by hand or by
      // another tool still reads.
      final tree = sampleTree();
      final reversed = <String, Object?>{
        for (final table in backupTableOrder.reversed)
          table: dataOf(tree)[table],
      };
      tree['data'] = reversed;

      expect(BackupCodec.decode(reencode(tree)).payload, samplePayload());
    });
  });

  group('damaged rows', () {
    test('rejects a row that is not an object', () {
      final tree = sampleTree();
      dataOf(tree)['courses'] = <Object?>['Pebble Beach'];

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badRow,
            mentioning: 'not an object', table: 'courses', rowIndex: 0),
      );
    });

    test('rejects a row missing a required column', () {
      final tree = sampleTree();
      rowOf(tree, 'courses').remove('name');

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badRow,
            table: 'courses', rowIndex: 0),
      );
    });

    test('rejects a row missing an optional column', () {
      // The silent-data-loss case: `stroke_index` absent would otherwise
      // decode as null and look deliberate.
      final tree = sampleTree();
      rowOf(tree, 'course_holes', 1).remove('stroke_index');

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badRow,
            mentioning: 'missing stroke_index',
            table: 'course_holes',
            rowIndex: 1),
      );
    });

    test('rejects a row carrying a column the table does not have', () {
      final tree = sampleTree();
      rowOf(tree, 'hole_results')['mulligans'] = 1;

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badRow,
            mentioning: 'unexpected mulligans',
            table: 'hole_results',
            rowIndex: 0),
      );
    });

    test('rejects a column of the wrong type', () {
      final tree = sampleTree();
      rowOf(tree, 'course_holes')['par'] = 'four';

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.badRow, table: 'course_holes'),
      );
    });

    test('names the table and the row in its message', () {
      final tree = sampleTree();
      rowOf(tree, 'course_holes', 1).remove('stroke_index');

      try {
        BackupCodec.decode(reencode(tree));
        fail('expected a BackupFormatException');
      } on BackupFormatException catch (e) {
        expect(e.describe, contains('course_holes'));
        expect(e.describe, contains('row 2'));
        expect(e.toString(), contains('badRow'));
      }
    });
  });

  group('the integrity check', () {
    test('rejects counts that disagree with the rows present', () {
      final tree = sampleTree();
      (manifestOf(tree)['rowCounts']! as Map<String, Object?>)['courses'] = 2;

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.rowCountMismatch,
            mentioning: 'looks incomplete or edited', table: 'courses'),
      );
    });

    test('catches a row quietly deleted from the file', () {
      final tree = sampleTree();
      tableOf(tree, 'course_holes').removeLast();

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.rowCountMismatch,
            table: 'course_holes'),
      );
    });

    test('rejects a manifest that omits a table from its counts', () {
      final tree = sampleTree();
      (manifestOf(tree)['rowCounts']! as Map<String, Object?>)
          .remove('hole_shots');

      expect(
        () => BackupCodec.decode(reencode(tree)),
        throwsBackup(BackupFormatProblem.rowCountMismatch,
            mentioning: 'does not say how many', table: 'hole_shots'),
      );
    });
  });

  group('referential checks before a restore writes anything', () {
    test('a sound payload has nothing to report', () {
      expect(samplePayload().validate(), isEmpty);
      expect(const BackupPayload.empty().validate(), isEmpty);
    });

    test('catches a round pointing at a course that is not in the file', () {
      final payload = samplePayload();
      final broken = payload.copyWith(
        rounds: [payload.rounds.first.copyWith(courseId: 99)],
      );

      expect(
        broken.validate(),
        contains(const BackupProblem(
          'rounds',
          'course_id 99 is not in courses',
          rowIndex: 0,
        )),
      );
    });

    test('catches a hole pointing at a round that is not in the file', () {
      final broken = samplePayload().copyWith(rounds: const <Round>[]);

      expect(
        broken.validate().map((p) => p.detail),
        contains('round_id 1 is not in rounds'),
      );
    });

    test('ignores a nullable link that is simply not set', () {
      final payload = samplePayload();
      final detached = payload.copyWith(
        events: const <Event>[],
        rounds: [
          payload.rounds.first.copyWith(eventId: const Value<int?>(null)),
        ],
      );

      expect(detached.validate(), isEmpty);
    });

    test('catches a duplicated unique key', () {
      final payload = samplePayload();
      final duplicated = payload.copyWith(
        courseHoles: [
          payload.courseHoles.first,
          payload.courseHoles.first.copyWith(id: 9),
        ],
      );

      expect(
        duplicated.validate().map((p) => p.detail),
        contains('duplicates another row on (course_id, hole_number)'),
      );
    });

    test('catches a duplicated row id', () {
      final payload = samplePayload();
      final duplicated = payload.copyWith(
        courses: [
          payload.courses.first,
          payload.courses.first.copyWith(name: 'Augusta'),
        ],
      );

      expect(
        duplicated.validate().map((p) => p.detail),
        contains('id 1 appears twice'),
      );
    });

    test('catches an id that is not a row id', () {
      final broken = const BackupPayload.empty().copyWith(
        courses: [samplePayload().courses.first.copyWith(id: 0)],
      );

      expect(
        broken.validate().map((p) => p.detail),
        contains('id 0 is not a row id'),
      );
    });

    test('catches a hole number outside 1-18', () {
      final payload = samplePayload();
      final broken = payload.copyWith(
        courseHoles: [payload.courseHoles.first.copyWith(holeNumber: 19)],
        holeResults: [payload.holeResults.first.copyWith(holeNumber: 0)],
        holeShots: const <HoleShot>[],
      );

      expect(
        broken.validate().map((p) => p.toString()),
        containsAll([
          'course_holes row 1: hole_number 19 is outside 1-18',
          'hole_results row 1: hole_number 0 is outside 1-18',
        ]),
      );
    });

    test('catches a shot numbered below 1', () {
      final payload = samplePayload();
      final broken = payload.copyWith(
        holeShots: [payload.holeShots.first.copyWith(shotNumber: 0)],
      );

      expect(
        broken.validate().map((p) => p.detail),
        contains('shot_number 0 is below 1'),
      );
    });

    test('decoding does not validate — the two are separate steps', () {
      // A file can be perfectly well-formed and still describe an impossible
      // database. #70 runs both, in this order, before it writes anything.
      final tree = sampleTree();
      rowOf(tree, 'rounds')['course_id'] = 99;

      final bundle = BackupCodec.decode(reencode(tree));

      expect(bundle.payload.rounds.single.courseId, 99);
      expect(bundle.payload.validate(), isNotEmpty);
    });
  });

  group('the manifest', () {
    test('describes itself for a log', () {
      final manifest = BackupCodec.decode(encodeSample()).manifest;

      expect(
        manifest.toString(),
        'BackupManifest(format 1, schema 7, 0.4.0+38, android, '
        '2026-10-03T14:32:07.000Z)',
      );
    });

    test('reads a manifest written in local time as UTC', () {
      final tree = sampleTree();
      manifestOf(tree)['exportedAt'] = '2026-10-03T16:32:07+02:00';

      final manifest = BackupCodec.decode(reencode(tree)).manifest;

      expect(manifest.exportedAt.isUtc, isTrue);
      expect(manifest.exportedAt, DateTime.utc(2026, 10, 3, 14, 32, 7));
    });

    test('exposes the format version it writes', () {
      expect(BackupManifest.currentFormatVersion, 1);
      expect(BackupManifest.jsonKey, 'golfyBackup');
    });
  });
}
