/// The yardage split that comes with schema v9: each v8 yardage set — named
/// "Tee Set - Pin Set" and holding that pair's tee-to-pin yards — becomes a
/// tee set, a pin set and the pair's tee-to-pin yards.
///
/// Shared by the v8 -> v9 database migration and the v8 backup upgrader, so a
/// database and a backup of it come out of the upgrade holding the same rows.
/// Frozen on purpose: it reads sets as v8 recorded them, and a device upgrading
/// from v8 years from now has to get what one upgrading today gets.
library;

/// One v8 `course_sets` row.
typedef V8YardageSet = ({int id, int courseId, String name});

/// One v8 `course_set_yards` row.
typedef V8SetYard = ({int id, int courseSetId, int holeNumber, int yards});

/// One v9 `tee_sets` or `pin_sets` row.
typedef V9CourseSet = ({int id, int courseId, String name});

/// One v9 `course_yards` row.
typedef V9CourseYard = ({int id, int teeSetId, int holeNumber, int yards});

/// One v9 `tee_to_pin_yards` row.
typedef V9TeeToPinYard = ({
  int id,
  int teeSetId,
  int pinSetId,
  int holeNumber,
  int yards,
});

/// Where one v8 set went: the course it is on, its tee set, and its pin set —
/// null when its name named no pin set. A round played on the v8 set is played
/// on this pair.
typedef V9YardageSet = ({int courseId, int teeSetId, int? pinSetId});

/// The v9 rows a v8 course's yardage sets become.
class SplitYardage {
  const SplitYardage({
    required this.teeSets,
    required this.pinSets,
    required this.courseYards,
    required this.teeToPinYards,
    required this.bySetId,
  });

  final List<V9CourseSet> teeSets;
  final List<V9CourseSet> pinSets;
  final List<V9CourseYard> courseYards;
  final List<V9TeeToPinYard> teeToPinYards;

  /// Every v8 set id, mapped to the yardage set it became.
  final Map<int, V9YardageSet> bySetId;
}

/// What separates the tee set from the pin set in a v8 name: a hyphen — or an
/// en or em dash — with whitespace either side, as in "Blue - Sunday pins". A
/// bare hyphen is part of a name ("Blue-White"), not a separator.
final RegExp _separator = RegExp(r'\s+[-–—]\s+');

/// A v8 set's [name] as its tee set and pin set, split at the first
/// separator, each trimmed.
///
/// A name with no separator, or with nothing on one side of it, is a tee set
/// alone with no pin set — every name the app suggested was "Tee Set - Pin
/// Set", but a set named by hand may not be.
({String tee, String? pin}) splitYardageSetName(String name) {
  final match = _separator.firstMatch(name);
  if (match != null) {
    final tee = name.substring(0, match.start).trim();
    final pin = name.substring(match.end).trim();
    if (tee.isNotEmpty && pin.isNotEmpty) return (tee: tee, pin: pin);
  }
  final whole = name.trim();
  return (tee: whole.isEmpty ? name : whole, pin: null);
}

/// Splits v8's [sets] and their [yards] into v9's tee sets, pin sets and
/// yards.
///
/// * Each set's name splits into a tee set and a pin set
///   ([splitYardageSetName]). Sets on one course naming the same tee set —
///   "Blue - Sunday", "Blue - Monday" — share one tee set, and likewise pin
///   sets; names match ignoring case, keeping the first set's spelling. New
///   ids count up from 1 in the order the sets were created.
/// * A set's yards are its pair's **tee-to-pin** yards. A set whose name named
///   no pin set has no pair, so its yards become its tee set's **course
///   yards** — what a round with no pin set pre-fills from.
/// * Two sets that land on the same card — "Blue - Sunday" and "blue -
///   sunday" — keep the earlier-created set's yards for a hole both have.
/// * Yard rows keep their v8 ids.
///
/// Every yard's set must be among [sets]; an unknown one is an
/// [ArgumentError], since there is no pair to put it under.
SplitYardage splitYardageSets(
  Iterable<V8YardageSet> sets,
  Iterable<V8SetYard> yards,
) {
  final orderedSets = [...sets]..sort((a, b) => a.id.compareTo(b.id));
  final teeSets = <V9CourseSet>[];
  final pinSets = <V9CourseSet>[];
  final teeIds = <String, int>{};
  final pinIds = <String, int>{};
  final bySetId = <int, V9YardageSet>{};

  int idFor(List<V9CourseSet> rows, Map<String, int> ids, int course, String n) {
    return ids.putIfAbsent('$course\u0000${n.toLowerCase()}', () {
      final id = rows.length + 1;
      rows.add((id: id, courseId: course, name: n));
      return id;
    });
  }

  for (final set in orderedSets) {
    final (:tee, :pin) = splitYardageSetName(set.name);
    bySetId[set.id] = (
      courseId: set.courseId,
      teeSetId: idFor(teeSets, teeIds, set.courseId, tee),
      pinSetId: pin == null ? null : idFor(pinSets, pinIds, set.courseId, pin),
    );
  }

  // The earlier-created set's yards first, so they win a shared hole.
  final setOrder = {for (final (i, s) in orderedSets.indexed) s.id: i};
  final orderedYards = [...yards]..sort((a, b) {
      final bySet = (setOrder[a.courseSetId] ?? -1)
          .compareTo(setOrder[b.courseSetId] ?? -1);
      return bySet != 0 ? bySet : a.id.compareTo(b.id);
    });
  final courseYards = <V9CourseYard>[];
  final teeToPinYards = <V9TeeToPinYard>[];
  final filled = <String>{};
  for (final yard in orderedYards) {
    final pair = bySetId[yard.courseSetId];
    if (pair == null) {
      throw ArgumentError.value(
        yard.courseSetId,
        'courseSetId',
        'yard ${yard.id} names a set that is not among the sets',
      );
    }
    final pinSetId = pair.pinSetId;
    if (!filled.add('${pair.teeSetId}/$pinSetId/${yard.holeNumber}')) continue;
    if (pinSetId == null) {
      courseYards.add((
        id: yard.id,
        teeSetId: pair.teeSetId,
        holeNumber: yard.holeNumber,
        yards: yard.yards,
      ));
    } else {
      teeToPinYards.add((
        id: yard.id,
        teeSetId: pair.teeSetId,
        pinSetId: pinSetId,
        holeNumber: yard.holeNumber,
        yards: yard.yards,
      ));
    }
  }
  courseYards.sort((a, b) => a.id.compareTo(b.id));
  teeToPinYards.sort((a, b) => a.id.compareTo(b.id));

  return SplitYardage(
    teeSets: teeSets,
    pinSets: pinSets,
    courseYards: courseYards,
    teeToPinYards: teeToPinYards,
    bySetId: bySetId,
  );
}
