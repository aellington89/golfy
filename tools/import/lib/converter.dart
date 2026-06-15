/// Pure, file-IO-free core of the one-time `golf_stats.xlsx` → `golfy_import.json`
/// converter (issue #33).
///
/// [buildImport] takes the worksheet already decoded into rows of primitive
/// cell values (`String` / `int` / `double` / `DateTime` / `bool` / `null`) and
/// returns the JSON-ready map the in-app importer ingests. Keeping the excel
/// decoding out of this file makes the transform trivially unit-testable.
///
/// The converter is intentionally *strict*: any unrecognized categorical token,
/// missing required integer, duplicate hole within a round, or "up & down
/// success without an attempt" throws an [ImportException] naming the offending
/// row, rather than silently guessing. Fix the source cell and re-run.
library;

/// Thrown when the spreadsheet contains data the converter cannot map
/// unambiguously. The [message] always names the offending row.
class ImportException implements Exception {
  ImportException(this.message);

  final String message;

  @override
  String toString() => 'ImportException: $message';
}

// Expected "Per Hole Tracker" column headers (matched case-insensitively).
const _hDate = 'Date';
const _hCourse = 'Course';
const _hRound = 'Round';
const _hHole = 'Hole';
const _hPar = 'Par';
const _hScore = 'Score';
const _hFairway = 'Fairway Hit?';
const _hGir = 'GIR?';
const _hPutts = 'Putts';
const _hUdAttempt = 'Up & Down Attempt?';
const _hUdSuccess = 'Up & Down Success?';
const _hPenalty = 'Penalty Stroke?';
const _hNotes = 'Notes';

const _requiredHeaders = <String>[
  _hDate, _hCourse, _hRound, _hHole, _hPar, _hScore,
  _hFairway, _hGir, _hPutts, _hUdAttempt, _hUdSuccess, _hPenalty,
];

/// Converts decoded sheet [rows] into the `golfy_import.json` structure.
///
/// The first row that carries both a `Par` and a `Score` header is treated as
/// the header row; columns are then addressed by name (order-independent).
/// Rows are grouped into rounds by `(Date, Course, Round)` — the sheet's
/// `Round` column is what distinguishes two 18-hole rounds played on the same
/// course and date.
Map<String, Object?> buildImport(
  List<List<Object?>> rows, {
  required String gameTitle,
  DateTime? generatedAt,
}) {
  if (gameTitle.trim().isEmpty) {
    throw ImportException('gameTitle must not be empty');
  }

  final header = _findHeader(rows);
  final col = _columnIndex(rows[header.index]);

  // Preserve first-seen round order; key is "date|course|round".
  final orderedKeys = <String>[];
  final rounds = <String, Map<String, Object?>>{};
  final holesByKey = <String, List<Map<String, Object?>>>{};
  final holeNumbersByKey = <String, Set<int>>{};

  for (var r = header.index + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c == null)) continue; // skip blank padding rows
    final rowNo = r + 1; // 1-based for human-friendly messages

    Object? cell(String name) {
      final i = col[name];
      return (i == null || i >= row.length) ? null : row[i];
    }

    final date = _isoDate(cell(_hDate), ctx: 'row $rowNo, $_hDate');
    final course = _requiredString(cell(_hCourse), ctx: 'row $rowNo, $_hCourse');
    final round = _requiredInt(cell(_hRound), ctx: 'row $rowNo, $_hCourse "$course"');
    final hole = _requiredInt(cell(_hHole), ctx: 'row $rowNo, $course R$round');
    final ctx = '$date $course R$round H$hole';
    if (hole < 1 || hole > 18) {
      throw ImportException('hole number $hole out of range 1..18 ($ctx)');
    }

    final par = _requiredInt(cell(_hPar), ctx: '$ctx, $_hPar');
    if (par < 3 || par > 5) {
      throw ImportException('par $par out of range 3..5 ($ctx)');
    }
    final score = _requiredInt(cell(_hScore), ctx: '$ctx, $_hScore');
    if (score < 1) throw ImportException('score $score must be >= 1 ($ctx)');
    final putts = _requiredInt(cell(_hPutts), ctx: '$ctx, $_hPutts');
    if (putts < 0) throw ImportException('putts $putts must be >= 0 ($ctx)');
    final penalty = _requiredInt(cell(_hPenalty), ctx: '$ctx, $_hPenalty');
    if (penalty < 0) {
      throw ImportException('penaltyStrokes $penalty must be >= 0 ($ctx)');
    }

    // Par 3s have no fairway: force null regardless of the cell (the app
    // enforces this invariant and would reject a non-null value).
    final fairway = par == 3
        ? null
        : _triState(cell(_hFairway), ctx: '$ctx, $_hFairway');
    final gir = _requireBool(cell(_hGir), ctx: '$ctx, $_hGir');
    final udAttempt =
        _requireBool(cell(_hUdAttempt), ctx: '$ctx, $_hUdAttempt');
    // "Up & Down Success?" is Yes/No/N/A; N/A (no attempt) maps to false.
    final udSuccess =
        _triState(cell(_hUdSuccess), ctx: '$ctx, $_hUdSuccess') ?? false;
    if (udSuccess && !udAttempt) {
      throw ImportException(
        'up & down success without an attempt — fix the source ($ctx)',
      );
    }

    final notes = _optionalString(cell(_hNotes));

    final key = '$date|$course|$round';
    if (!rounds.containsKey(key)) {
      orderedKeys.add(key);
      rounds[key] = {
        'date': date,
        'course': course,
        'roundNumber': round,
      };
      holesByKey[key] = [];
      holeNumbersByKey[key] = <int>{};
    }
    if (!holeNumbersByKey[key]!.add(hole)) {
      throw ImportException('duplicate hole $hole within round ($ctx)');
    }
    holesByKey[key]!.add({
      'holeNumber': hole,
      'par': par,
      'score': score,
      'fairwayHit': fairway,
      'gir': gir,
      'putts': putts,
      'upDownAttempt': udAttempt,
      'upDownSuccess': udSuccess,
      'penaltyStrokes': penalty,
      'notes': notes,
    });
  }

  if (orderedKeys.isEmpty) {
    throw ImportException('no data rows found beneath the header');
  }

  final roundList = <Map<String, Object?>>[];
  for (final key in orderedKeys) {
    final holes = holesByKey[key]!
      ..sort((a, b) => (a['holeNumber'] as int).compareTo(b['holeNumber'] as int));
    roundList.add({...rounds[key]!, 'holes': holes});
  }

  return {
    'gameTitle': gameTitle.trim(),
    'generatedAt': (generatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'rounds': roundList,
  };
}

class _Header {
  _Header(this.index);
  final int index;
}

_Header _findHeader(List<List<Object?>> rows) {
  for (var i = 0; i < rows.length; i++) {
    final names = rows[i]
        .map((c) => c?.toString().trim().toLowerCase())
        .whereType<String>()
        .toSet();
    if (names.contains(_hPar.toLowerCase()) &&
        names.contains(_hScore.toLowerCase())) {
      return _Header(i);
    }
  }
  throw ImportException(
    'could not find a header row containing "$_hPar" and "$_hScore"',
  );
}

Map<String, int> _columnIndex(List<Object?> headerRow) {
  final byLower = <String, int>{};
  for (var i = 0; i < headerRow.length; i++) {
    final name = headerRow[i]?.toString().trim();
    if (name != null && name.isNotEmpty) {
      byLower.putIfAbsent(name.toLowerCase(), () => i);
    }
  }
  final index = <String, int>{};
  for (final required in _requiredHeaders) {
    final i = byLower[required.toLowerCase()];
    if (i == null) {
      throw ImportException('missing required column "$required"');
    }
    index[required] = i;
  }
  // Notes is optional.
  final notes = byLower[_hNotes.toLowerCase()];
  if (notes != null) index[_hNotes] = notes;
  return index;
}

/// Parses Yes/No/N/A (and a few synonyms) into true/false/null.
bool? _triState(Object? v, {required String ctx}) {
  final s = v?.toString().trim().toLowerCase() ?? '';
  switch (s) {
    case 'yes':
    case 'y':
    case 'true':
    case '1':
      return true;
    case 'no':
    case 'n':
    case 'false':
    case '0':
      return false;
    case 'n/a':
    case 'na':
    case '':
      return null;
    default:
      throw ImportException('unrecognized Yes/No/N/A value "$v" ($ctx)');
  }
}

/// Like [_triState] but the value is required to be a definite Yes/No.
bool _requireBool(Object? v, {required String ctx}) {
  final r = _triState(v, ctx: ctx);
  if (r == null) {
    throw ImportException('expected Yes or No (got "$v") ($ctx)');
  }
  return r;
}

String _isoDate(Object? v, {required String ctx}) {
  if (v == null) throw ImportException('missing date ($ctx)');
  DateTime dt;
  if (v is DateTime) {
    dt = v;
  } else {
    final parsed = DateTime.tryParse(v.toString().trim());
    if (parsed == null) {
      throw ImportException('unparseable date "$v" ($ctx)');
    }
    dt = parsed;
  }
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$m-$d';
}

int _requiredInt(Object? v, {required String ctx}) {
  if (v is int) return v;
  if (v is double) {
    if (v == v.roundToDouble()) return v.toInt();
    throw ImportException('expected a whole number, got $v ($ctx)');
  }
  if (v is String) {
    final n = int.tryParse(v.trim());
    if (n != null) return n;
  }
  throw ImportException('expected an integer, got "$v" ($ctx)');
}

String _requiredString(Object? v, {required String ctx}) {
  final s = v?.toString().trim() ?? '';
  if (s.isEmpty) throw ImportException('missing value ($ctx)');
  return s;
}

String? _optionalString(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
