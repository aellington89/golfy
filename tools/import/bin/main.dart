/// CLI entry point for the one-time `golf_stats.xlsx` → `golfy_import.json`
/// converter (issue #33).
///
/// Usage:
///   dart run bin/main.dart --game-title "PGA 2K25" path/to/golf_stats.xlsx
///
/// Reads the "Per Hole Tracker" worksheet, converts each cell to a primitive,
/// hands the rows to the pure [buildImport] transform, and writes indented
/// JSON. All domain validation lives in `lib/converter.dart`.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:excel/excel.dart';
import 'package:golfy_import_tool/converter.dart';

const _defaultSheet = 'Per Hole Tracker';

void main(List<String> argv) {
  final parser = ArgParser()
    ..addOption('game-title',
        help: 'gameTitle stored for every imported course (required).')
    ..addOption('out',
        defaultsTo: 'golfy_import.json', help: 'Output JSON path.')
    ..addOption('sheet',
        defaultsTo: _defaultSheet, help: 'Worksheet name to read.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(_usage(parser));
    exitCode = 64; // EX_USAGE
    return;
  }

  if (args['help'] as bool) {
    stdout.writeln(_usage(parser));
    return;
  }

  final gameTitle = (args['game-title'] as String?)?.trim();
  if (gameTitle == null || gameTitle.isEmpty) {
    stderr
      ..writeln('Error: --game-title is required.')
      ..writeln(_usage(parser));
    exitCode = 64;
    return;
  }

  if (args.rest.length != 1) {
    stderr
      ..writeln('Error: provide exactly one input .xlsx path.')
      ..writeln(_usage(parser));
    exitCode = 64;
    return;
  }

  final input = File(args.rest.single);
  if (!input.existsSync()) {
    stderr.writeln('Error: file not found: ${input.path}');
    exitCode = 66; // EX_NOINPUT
    return;
  }

  final sheetName = args['sheet'] as String;
  final excel = Excel.decodeBytes(input.readAsBytesSync());
  final sheet = excel.tables[sheetName];
  if (sheet == null) {
    stderr.writeln(
      'Error: sheet "$sheetName" not found. Available: '
      '${excel.tables.keys.join(', ')}',
    );
    exitCode = 65; // EX_DATAERR
    return;
  }

  final rows =
      sheet.rows.map((r) => r.map(_cellToPrimitive).toList()).toList();

  final Map<String, Object?> result;
  try {
    result = buildImport(rows, gameTitle: gameTitle);
  } on ImportException catch (e) {
    stderr.writeln('Import failed: ${e.message}');
    exitCode = 65;
    return;
  }

  final roundList = result['rounds'] as List;
  final holes = roundList.fold<int>(
      0, (sum, r) => sum + ((r as Map)['holes'] as List).length);
  final courses =
      roundList.map((r) => (r as Map)['course']).toSet().length;

  final outPath = args['out'] as String;
  File(outPath)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(
    'Wrote $outPath: $courses courses, ${roundList.length} rounds, $holes holes.',
  );
}

String _usage(ArgParser parser) =>
    'Usage: dart run bin/main.dart --game-title "<title>" <input.xlsx>\n\n'
    '${parser.usage}';

/// Flattens an `excel` cell to a plain Dart value the converter understands.
Object? _cellToPrimitive(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  if (v is TextCellValue) return v.value.toString();
  if (v is IntCellValue) return v.value;
  if (v is DoubleCellValue) return v.value;
  if (v is BoolCellValue) return v.value;
  if (v is DateCellValue) return DateTime(v.year, v.month, v.day);
  if (v is DateTimeCellValue) {
    return DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second);
  }
  return v.toString();
}
