// Backup format, write side (#69) — BackupCodec.encode and the round trip.
//
// Pure: no database, no file system. The format these tests pin is specified
// in BACKUP_FORMAT.md, and a change here is a change to a file every user may
// already be holding.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:golfy_app/data/backup/backup_codec.dart';
import 'package:golfy_app/data/backup/backup_manifest.dart';
import 'package:golfy_app/data/backup/backup_payload.dart';

import '_sample.dart';

void main() {
  group('encode', () {
    test('round-trips a payload unchanged', () {
      final payload = samplePayload();

      final decoded = BackupCodec.decode(BackupCodec.encode(
        sampleManifest(payload),
        payload,
      ));

      expect(decoded.payload, payload);
    });

    test('round-trips the manifest', () {
      final payload = samplePayload();
      final manifest = sampleManifest(payload);

      final decoded = BackupCodec.decode(BackupCodec.encode(manifest, payload));

      expect(decoded.manifest.formatVersion, manifest.formatVersion);
      expect(decoded.manifest.schemaVersion, manifest.schemaVersion);
      expect(decoded.manifest.appVersion, '0.4.0+38');
      expect(decoded.manifest.platform, 'android');
      expect(decoded.manifest.exportedAt, manifest.exportedAt);
      expect(decoded.manifest.rowCounts, payload.rowCounts);
    });

    test('round-trips an empty database', () {
      const payload = BackupPayload.empty();

      final decoded = BackupCodec.decode(BackupCodec.encode(
        sampleManifest(payload),
        payload,
      ));

      expect(decoded.payload, payload);
      expect(decoded.payload.isEmpty, isTrue);
      expect(decoded.manifest.rowCounts.values, everyElement(0));
    });

    test('writes the tables parents-first', () {
      expect(dataOf(sampleTree()).keys, backupTableOrder);
    });

    test('keys rows by their SQL column names', () {
      final tree = sampleTree();

      expect(rowOf(tree, 'courses').keys, ['id', 'name', 'game_title']);
      expect(rowOf(tree, 'rounds').keys, [
        'id',
        'date',
        'course_id',
        'round_number',
        'tee_set',
        'course_set_id',
        'weather',
        'wind_speed_mph',
        'difficulty',
        'notes',
        'migration_canary',
        'event_id',
      ]);
      expect(rowOf(tree, 'hole_shots').keys, [
        'id',
        'hole_result_id',
        'shot_number',
        'club',
        'distance_yards',
        'lie',
        'result',
      ]);
    });

    test('writes booleans as true / false, not 0 / 1', () {
      final hole = rowOf(sampleTree(), 'hole_results');

      expect(hole['gir'], isFalse);
      expect(hole['up_down_attempt'], isTrue);
      expect(hole['bunker_visited'], isTrue);
      expect(rowOf(sampleTree(), 'events')['tied'], isTrue);
    });

    test('writes unset columns as explicit nulls', () {
      final tree = sampleTree();

      // A missing key would decode as null for a nullable column, so the file
      // states every one of them.
      final secondHole = rowOf(tree, 'course_holes', 1);
      expect(secondHole.containsKey('stroke_index'), isTrue);
      expect(secondHole['stroke_index'], isNull);

      final round = rowOf(tree, 'rounds');
      expect(round.containsKey('weather'), isTrue);
      expect(round['weather'], isNull);
      expect(round['tee_set'], isNull);
      expect(round['migration_canary'], isNull);
    });

    test('keeps quotes, newlines and non-ASCII text intact', () {
      final notes = rowOf(sampleTree(), 'rounds')['notes'];

      expect(notes, 'Said "nice shot" — then this:\nthree-putt. ⛳');
    });

    test('is pretty-printed, two-space indented, newline-terminated', () {
      final text = encodeSample();

      expect(text, startsWith('{\n  "golfyBackup": {\n    "formatVersion": 1'));
      expect(text, endsWith('}\n'));
      expect(text.split('\n').length, greaterThan(50));
    });

    test('is byte-stable across encodings of the same data', () {
      expect(encodeSample(), encodeSample());
    });

    test('states the schema version and the format version separately', () {
      final manifest = manifestOf(sampleTree());

      expect(manifest['formatVersion'], BackupManifest.currentFormatVersion);
      expect(manifest['schemaVersion'], BackupCodec.supportedSchemaVersion);
      expect(manifest['formatVersion'], 1);
      expect(manifest['schemaVersion'], 7);
    });

    test('states when it was made, in UTC', () {
      expect(
        manifestOf(sampleTree())['exportedAt'],
        '2026-10-03T14:32:07.000Z',
      );
    });

    test('carries no device identifier beyond the platform name', () {
      final manifest = manifestOf(sampleTree());

      expect(manifest.keys, [
        'formatVersion',
        'schemaVersion',
        'appVersion',
        'exportedAt',
        'platform',
        'rowCounts',
      ]);
    });

    test('states a row count for every table', () {
      final counts = manifestOf(sampleTree())['rowCounts']!
          as Map<String, Object?>;

      expect(counts.keys, backupTableOrder);
      expect(counts['course_holes'], 2);
      expect(counts['courses'], 1);
    });

    test('is valid JSON by any reader', () {
      expect(() => jsonDecode(encodeSample()), returnsNormally);
    });
  });

  group('payload', () {
    test('counts rows per table and in total', () {
      final payload = samplePayload();

      expect(payload.rowCounts['course_holes'], 2);
      expect(payload.totalRows, 9);
      expect(payload.isEmpty, isFalse);
      expect(const BackupPayload.empty().isEmpty, isTrue);
    });

    test('compares equal only when every row matches', () {
      expect(samplePayload(), samplePayload());
      expect(samplePayload().hashCode, samplePayload().hashCode);
      expect(samplePayload() == const BackupPayload.empty(), isFalse);
    });
  });
}
