// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CoursesTable extends Courses with TableInfo<$CoursesTable, Course> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameTitleMeta = const VerificationMeta(
    'gameTitle',
  );
  @override
  late final GeneratedColumn<String> gameTitle = GeneratedColumn<String>(
    'game_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, gameTitle];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Course> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('game_title')) {
      context.handle(
        _gameTitleMeta,
        gameTitle.isAcceptableOrUnknown(data['game_title']!, _gameTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_gameTitleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, gameTitle},
  ];
  @override
  Course map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Course(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      gameTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_title'],
      )!,
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class Course extends DataClass implements Insertable<Course> {
  final int id;
  final String name;
  final String gameTitle;
  const Course({required this.id, required this.name, required this.gameTitle});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['game_title'] = Variable<String>(gameTitle);
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      name: Value(name),
      gameTitle: Value(gameTitle),
    );
  }

  factory Course.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Course(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      gameTitle: serializer.fromJson<String>(json['gameTitle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'gameTitle': serializer.toJson<String>(gameTitle),
    };
  }

  Course copyWith({int? id, String? name, String? gameTitle}) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    gameTitle: gameTitle ?? this.gameTitle,
  );
  Course copyWithCompanion(CoursesCompanion data) {
    return Course(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      gameTitle: data.gameTitle.present ? data.gameTitle.value : this.gameTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Course(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('gameTitle: $gameTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, gameTitle);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Course &&
          other.id == this.id &&
          other.name == this.name &&
          other.gameTitle == this.gameTitle);
}

class CoursesCompanion extends UpdateCompanion<Course> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> gameTitle;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.gameTitle = const Value.absent(),
  });
  CoursesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String gameTitle,
  }) : name = Value(name),
       gameTitle = Value(gameTitle);
  static Insertable<Course> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? gameTitle,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (gameTitle != null) 'game_title': gameTitle,
    });
  }

  CoursesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? gameTitle,
  }) {
    return CoursesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      gameTitle: gameTitle ?? this.gameTitle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (gameTitle.present) {
      map['game_title'] = Variable<String>(gameTitle.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('gameTitle: $gameTitle')
          ..write(')'))
        .toString();
  }
}

class $RoundsTable extends Rounds with TableInfo<$RoundsTable, Round> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoundsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES courses (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _roundNumberMeta = const VerificationMeta(
    'roundNumber',
  );
  @override
  late final GeneratedColumn<int> roundNumber = GeneratedColumn<int>(
    'round_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _teeSetMeta = const VerificationMeta('teeSet');
  @override
  late final GeneratedColumn<String> teeSet = GeneratedColumn<String>(
    'tee_set',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weatherMeta = const VerificationMeta(
    'weather',
  );
  @override
  late final GeneratedColumn<String> weather = GeneratedColumn<String>(
    'weather',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _windSpeedMphMeta = const VerificationMeta(
    'windSpeedMph',
  );
  @override
  late final GeneratedColumn<int> windSpeedMph = GeneratedColumn<int>(
    'wind_speed_mph',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    courseId,
    roundNumber,
    teeSet,
    weather,
    windSpeedMph,
    difficulty,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rounds';
  @override
  VerificationContext validateIntegrity(
    Insertable<Round> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('round_number')) {
      context.handle(
        _roundNumberMeta,
        roundNumber.isAcceptableOrUnknown(
          data['round_number']!,
          _roundNumberMeta,
        ),
      );
    }
    if (data.containsKey('tee_set')) {
      context.handle(
        _teeSetMeta,
        teeSet.isAcceptableOrUnknown(data['tee_set']!, _teeSetMeta),
      );
    }
    if (data.containsKey('weather')) {
      context.handle(
        _weatherMeta,
        weather.isAcceptableOrUnknown(data['weather']!, _weatherMeta),
      );
    }
    if (data.containsKey('wind_speed_mph')) {
      context.handle(
        _windSpeedMphMeta,
        windSpeedMph.isAcceptableOrUnknown(
          data['wind_speed_mph']!,
          _windSpeedMphMeta,
        ),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date, courseId, roundNumber},
  ];
  @override
  Round map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Round(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      )!,
      roundNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_number'],
      )!,
      teeSet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tee_set'],
      ),
      weather: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather'],
      ),
      windSpeedMph: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wind_speed_mph'],
      ),
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $RoundsTable createAlias(String alias) {
    return $RoundsTable(attachedDatabase, alias);
  }
}

class Round extends DataClass implements Insertable<Round> {
  final int id;
  final String date;
  final int courseId;
  final int roundNumber;
  final String? teeSet;
  final String? weather;
  final int? windSpeedMph;
  final String? difficulty;
  final String? notes;
  const Round({
    required this.id,
    required this.date,
    required this.courseId,
    required this.roundNumber,
    this.teeSet,
    this.weather,
    this.windSpeedMph,
    this.difficulty,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    map['course_id'] = Variable<int>(courseId);
    map['round_number'] = Variable<int>(roundNumber);
    if (!nullToAbsent || teeSet != null) {
      map['tee_set'] = Variable<String>(teeSet);
    }
    if (!nullToAbsent || weather != null) {
      map['weather'] = Variable<String>(weather);
    }
    if (!nullToAbsent || windSpeedMph != null) {
      map['wind_speed_mph'] = Variable<int>(windSpeedMph);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<String>(difficulty);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  RoundsCompanion toCompanion(bool nullToAbsent) {
    return RoundsCompanion(
      id: Value(id),
      date: Value(date),
      courseId: Value(courseId),
      roundNumber: Value(roundNumber),
      teeSet: teeSet == null && nullToAbsent
          ? const Value.absent()
          : Value(teeSet),
      weather: weather == null && nullToAbsent
          ? const Value.absent()
          : Value(weather),
      windSpeedMph: windSpeedMph == null && nullToAbsent
          ? const Value.absent()
          : Value(windSpeedMph),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Round.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Round(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      courseId: serializer.fromJson<int>(json['courseId']),
      roundNumber: serializer.fromJson<int>(json['roundNumber']),
      teeSet: serializer.fromJson<String?>(json['teeSet']),
      weather: serializer.fromJson<String?>(json['weather']),
      windSpeedMph: serializer.fromJson<int?>(json['windSpeedMph']),
      difficulty: serializer.fromJson<String?>(json['difficulty']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'courseId': serializer.toJson<int>(courseId),
      'roundNumber': serializer.toJson<int>(roundNumber),
      'teeSet': serializer.toJson<String?>(teeSet),
      'weather': serializer.toJson<String?>(weather),
      'windSpeedMph': serializer.toJson<int?>(windSpeedMph),
      'difficulty': serializer.toJson<String?>(difficulty),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Round copyWith({
    int? id,
    String? date,
    int? courseId,
    int? roundNumber,
    Value<String?> teeSet = const Value.absent(),
    Value<String?> weather = const Value.absent(),
    Value<int?> windSpeedMph = const Value.absent(),
    Value<String?> difficulty = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => Round(
    id: id ?? this.id,
    date: date ?? this.date,
    courseId: courseId ?? this.courseId,
    roundNumber: roundNumber ?? this.roundNumber,
    teeSet: teeSet.present ? teeSet.value : this.teeSet,
    weather: weather.present ? weather.value : this.weather,
    windSpeedMph: windSpeedMph.present ? windSpeedMph.value : this.windSpeedMph,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    notes: notes.present ? notes.value : this.notes,
  );
  Round copyWithCompanion(RoundsCompanion data) {
    return Round(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      roundNumber: data.roundNumber.present
          ? data.roundNumber.value
          : this.roundNumber,
      teeSet: data.teeSet.present ? data.teeSet.value : this.teeSet,
      weather: data.weather.present ? data.weather.value : this.weather,
      windSpeedMph: data.windSpeedMph.present
          ? data.windSpeedMph.value
          : this.windSpeedMph,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Round(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('courseId: $courseId, ')
          ..write('roundNumber: $roundNumber, ')
          ..write('teeSet: $teeSet, ')
          ..write('weather: $weather, ')
          ..write('windSpeedMph: $windSpeedMph, ')
          ..write('difficulty: $difficulty, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    courseId,
    roundNumber,
    teeSet,
    weather,
    windSpeedMph,
    difficulty,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Round &&
          other.id == this.id &&
          other.date == this.date &&
          other.courseId == this.courseId &&
          other.roundNumber == this.roundNumber &&
          other.teeSet == this.teeSet &&
          other.weather == this.weather &&
          other.windSpeedMph == this.windSpeedMph &&
          other.difficulty == this.difficulty &&
          other.notes == this.notes);
}

class RoundsCompanion extends UpdateCompanion<Round> {
  final Value<int> id;
  final Value<String> date;
  final Value<int> courseId;
  final Value<int> roundNumber;
  final Value<String?> teeSet;
  final Value<String?> weather;
  final Value<int?> windSpeedMph;
  final Value<String?> difficulty;
  final Value<String?> notes;
  const RoundsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.courseId = const Value.absent(),
    this.roundNumber = const Value.absent(),
    this.teeSet = const Value.absent(),
    this.weather = const Value.absent(),
    this.windSpeedMph = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.notes = const Value.absent(),
  });
  RoundsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required int courseId,
    this.roundNumber = const Value.absent(),
    this.teeSet = const Value.absent(),
    this.weather = const Value.absent(),
    this.windSpeedMph = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.notes = const Value.absent(),
  }) : date = Value(date),
       courseId = Value(courseId);
  static Insertable<Round> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<int>? courseId,
    Expression<int>? roundNumber,
    Expression<String>? teeSet,
    Expression<String>? weather,
    Expression<int>? windSpeedMph,
    Expression<String>? difficulty,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (courseId != null) 'course_id': courseId,
      if (roundNumber != null) 'round_number': roundNumber,
      if (teeSet != null) 'tee_set': teeSet,
      if (weather != null) 'weather': weather,
      if (windSpeedMph != null) 'wind_speed_mph': windSpeedMph,
      if (difficulty != null) 'difficulty': difficulty,
      if (notes != null) 'notes': notes,
    });
  }

  RoundsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<int>? courseId,
    Value<int>? roundNumber,
    Value<String?>? teeSet,
    Value<String?>? weather,
    Value<int?>? windSpeedMph,
    Value<String?>? difficulty,
    Value<String?>? notes,
  }) {
    return RoundsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      courseId: courseId ?? this.courseId,
      roundNumber: roundNumber ?? this.roundNumber,
      teeSet: teeSet ?? this.teeSet,
      weather: weather ?? this.weather,
      windSpeedMph: windSpeedMph ?? this.windSpeedMph,
      difficulty: difficulty ?? this.difficulty,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (roundNumber.present) {
      map['round_number'] = Variable<int>(roundNumber.value);
    }
    if (teeSet.present) {
      map['tee_set'] = Variable<String>(teeSet.value);
    }
    if (weather.present) {
      map['weather'] = Variable<String>(weather.value);
    }
    if (windSpeedMph.present) {
      map['wind_speed_mph'] = Variable<int>(windSpeedMph.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoundsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('courseId: $courseId, ')
          ..write('roundNumber: $roundNumber, ')
          ..write('teeSet: $teeSet, ')
          ..write('weather: $weather, ')
          ..write('windSpeedMph: $windSpeedMph, ')
          ..write('difficulty: $difficulty, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $HoleResultsTable extends HoleResults
    with TableInfo<$HoleResultsTable, HoleResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoleResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _roundIdMeta = const VerificationMeta(
    'roundId',
  );
  @override
  late final GeneratedColumn<int> roundId = GeneratedColumn<int>(
    'round_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rounds (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _holeNumberMeta = const VerificationMeta(
    'holeNumber',
  );
  @override
  late final GeneratedColumn<int> holeNumber = GeneratedColumn<int>(
    'hole_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (hole_number BETWEEN 1 AND 18)',
  );
  static const VerificationMeta _parMeta = const VerificationMeta('par');
  @override
  late final GeneratedColumn<int> par = GeneratedColumn<int>(
    'par',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (par BETWEEN 3 AND 5)',
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (score >= 1)',
  );
  static const VerificationMeta _yardsMeta = const VerificationMeta('yards');
  @override
  late final GeneratedColumn<int> yards = GeneratedColumn<int>(
    'yards',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (yards >= 0)',
  );
  static const VerificationMeta _fairwayHitMeta = const VerificationMeta(
    'fairwayHit',
  );
  @override
  late final GeneratedColumn<bool> fairwayHit = GeneratedColumn<bool>(
    'fairway_hit',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fairway_hit" IN (0, 1))',
    ),
  );
  static const VerificationMeta _girMeta = const VerificationMeta('gir');
  @override
  late final GeneratedColumn<bool> gir = GeneratedColumn<bool>(
    'gir',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("gir" IN (0, 1))',
    ),
  );
  static const VerificationMeta _puttsMeta = const VerificationMeta('putts');
  @override
  late final GeneratedColumn<int> putts = GeneratedColumn<int>(
    'putts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (putts >= 0)',
  );
  static const VerificationMeta _upDownAttemptMeta = const VerificationMeta(
    'upDownAttempt',
  );
  @override
  late final GeneratedColumn<bool> upDownAttempt = GeneratedColumn<bool>(
    'up_down_attempt',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("up_down_attempt" IN (0, 1))',
    ),
  );
  static const VerificationMeta _upDownSuccessMeta = const VerificationMeta(
    'upDownSuccess',
  );
  @override
  late final GeneratedColumn<bool> upDownSuccess = GeneratedColumn<bool>(
    'up_down_success',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("up_down_success" IN (0, 1))',
    ),
  );
  static const VerificationMeta _penaltyStrokesMeta = const VerificationMeta(
    'penaltyStrokes',
  );
  @override
  late final GeneratedColumn<int> penaltyStrokes = GeneratedColumn<int>(
    'penalty_strokes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (penalty_strokes >= 0)',
  );
  static const VerificationMeta _bunkerVisitedMeta = const VerificationMeta(
    'bunkerVisited',
  );
  @override
  late final GeneratedColumn<bool> bunkerVisited = GeneratedColumn<bool>(
    'bunker_visited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bunker_visited" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sandSaveMeta = const VerificationMeta(
    'sandSave',
  );
  @override
  late final GeneratedColumn<bool> sandSave = GeneratedColumn<bool>(
    'sand_save',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sand_save" IN (0, 1))',
    ),
  );
  static const VerificationMeta _driveDistanceYardsMeta =
      const VerificationMeta('driveDistanceYards');
  @override
  late final GeneratedColumn<int> driveDistanceYards = GeneratedColumn<int>(
    'drive_distance_yards',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (drive_distance_yards >= 0)',
  );
  static const VerificationMeta _approachDistanceYardsMeta =
      const VerificationMeta('approachDistanceYards');
  @override
  late final GeneratedColumn<int> approachDistanceYards = GeneratedColumn<int>(
    'approach_distance_yards',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (approach_distance_yards >= 0)',
  );
  static const VerificationMeta _teeClubMeta = const VerificationMeta(
    'teeClub',
  );
  @override
  late final GeneratedColumn<String> teeClub = GeneratedColumn<String>(
    'tee_club',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    roundId,
    holeNumber,
    par,
    score,
    yards,
    fairwayHit,
    gir,
    putts,
    upDownAttempt,
    upDownSuccess,
    penaltyStrokes,
    bunkerVisited,
    sandSave,
    driveDistanceYards,
    approachDistanceYards,
    teeClub,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hole_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoleResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('round_id')) {
      context.handle(
        _roundIdMeta,
        roundId.isAcceptableOrUnknown(data['round_id']!, _roundIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roundIdMeta);
    }
    if (data.containsKey('hole_number')) {
      context.handle(
        _holeNumberMeta,
        holeNumber.isAcceptableOrUnknown(data['hole_number']!, _holeNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_holeNumberMeta);
    }
    if (data.containsKey('par')) {
      context.handle(
        _parMeta,
        par.isAcceptableOrUnknown(data['par']!, _parMeta),
      );
    } else if (isInserting) {
      context.missing(_parMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('yards')) {
      context.handle(
        _yardsMeta,
        yards.isAcceptableOrUnknown(data['yards']!, _yardsMeta),
      );
    } else if (isInserting) {
      context.missing(_yardsMeta);
    }
    if (data.containsKey('fairway_hit')) {
      context.handle(
        _fairwayHitMeta,
        fairwayHit.isAcceptableOrUnknown(data['fairway_hit']!, _fairwayHitMeta),
      );
    }
    if (data.containsKey('gir')) {
      context.handle(
        _girMeta,
        gir.isAcceptableOrUnknown(data['gir']!, _girMeta),
      );
    } else if (isInserting) {
      context.missing(_girMeta);
    }
    if (data.containsKey('putts')) {
      context.handle(
        _puttsMeta,
        putts.isAcceptableOrUnknown(data['putts']!, _puttsMeta),
      );
    } else if (isInserting) {
      context.missing(_puttsMeta);
    }
    if (data.containsKey('up_down_attempt')) {
      context.handle(
        _upDownAttemptMeta,
        upDownAttempt.isAcceptableOrUnknown(
          data['up_down_attempt']!,
          _upDownAttemptMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_upDownAttemptMeta);
    }
    if (data.containsKey('up_down_success')) {
      context.handle(
        _upDownSuccessMeta,
        upDownSuccess.isAcceptableOrUnknown(
          data['up_down_success']!,
          _upDownSuccessMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_upDownSuccessMeta);
    }
    if (data.containsKey('penalty_strokes')) {
      context.handle(
        _penaltyStrokesMeta,
        penaltyStrokes.isAcceptableOrUnknown(
          data['penalty_strokes']!,
          _penaltyStrokesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_penaltyStrokesMeta);
    }
    if (data.containsKey('bunker_visited')) {
      context.handle(
        _bunkerVisitedMeta,
        bunkerVisited.isAcceptableOrUnknown(
          data['bunker_visited']!,
          _bunkerVisitedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bunkerVisitedMeta);
    }
    if (data.containsKey('sand_save')) {
      context.handle(
        _sandSaveMeta,
        sandSave.isAcceptableOrUnknown(data['sand_save']!, _sandSaveMeta),
      );
    } else if (isInserting) {
      context.missing(_sandSaveMeta);
    }
    if (data.containsKey('drive_distance_yards')) {
      context.handle(
        _driveDistanceYardsMeta,
        driveDistanceYards.isAcceptableOrUnknown(
          data['drive_distance_yards']!,
          _driveDistanceYardsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_driveDistanceYardsMeta);
    }
    if (data.containsKey('approach_distance_yards')) {
      context.handle(
        _approachDistanceYardsMeta,
        approachDistanceYards.isAcceptableOrUnknown(
          data['approach_distance_yards']!,
          _approachDistanceYardsMeta,
        ),
      );
    }
    if (data.containsKey('tee_club')) {
      context.handle(
        _teeClubMeta,
        teeClub.isAcceptableOrUnknown(data['tee_club']!, _teeClubMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {roundId, holeNumber},
  ];
  @override
  HoleResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoleResult(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      roundId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_id'],
      )!,
      holeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hole_number'],
      )!,
      par: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}par'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      yards: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}yards'],
      )!,
      fairwayHit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fairway_hit'],
      ),
      gir: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}gir'],
      )!,
      putts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}putts'],
      )!,
      upDownAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}up_down_attempt'],
      )!,
      upDownSuccess: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}up_down_success'],
      )!,
      penaltyStrokes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}penalty_strokes'],
      )!,
      bunkerVisited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bunker_visited'],
      )!,
      sandSave: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sand_save'],
      )!,
      driveDistanceYards: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}drive_distance_yards'],
      )!,
      approachDistanceYards: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}approach_distance_yards'],
      ),
      teeClub: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tee_club'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $HoleResultsTable createAlias(String alias) {
    return $HoleResultsTable(attachedDatabase, alias);
  }
}

class HoleResult extends DataClass implements Insertable<HoleResult> {
  final int id;
  final int roundId;
  final int holeNumber;
  final int par;
  final int score;
  final int yards;
  final bool? fairwayHit;
  final bool gir;
  final int putts;
  final bool upDownAttempt;
  final bool upDownSuccess;
  final int penaltyStrokes;
  final bool bunkerVisited;
  final bool sandSave;
  final int driveDistanceYards;
  final int? approachDistanceYards;
  final String? teeClub;
  final String? notes;
  const HoleResult({
    required this.id,
    required this.roundId,
    required this.holeNumber,
    required this.par,
    required this.score,
    required this.yards,
    this.fairwayHit,
    required this.gir,
    required this.putts,
    required this.upDownAttempt,
    required this.upDownSuccess,
    required this.penaltyStrokes,
    required this.bunkerVisited,
    required this.sandSave,
    required this.driveDistanceYards,
    this.approachDistanceYards,
    this.teeClub,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['round_id'] = Variable<int>(roundId);
    map['hole_number'] = Variable<int>(holeNumber);
    map['par'] = Variable<int>(par);
    map['score'] = Variable<int>(score);
    map['yards'] = Variable<int>(yards);
    if (!nullToAbsent || fairwayHit != null) {
      map['fairway_hit'] = Variable<bool>(fairwayHit);
    }
    map['gir'] = Variable<bool>(gir);
    map['putts'] = Variable<int>(putts);
    map['up_down_attempt'] = Variable<bool>(upDownAttempt);
    map['up_down_success'] = Variable<bool>(upDownSuccess);
    map['penalty_strokes'] = Variable<int>(penaltyStrokes);
    map['bunker_visited'] = Variable<bool>(bunkerVisited);
    map['sand_save'] = Variable<bool>(sandSave);
    map['drive_distance_yards'] = Variable<int>(driveDistanceYards);
    if (!nullToAbsent || approachDistanceYards != null) {
      map['approach_distance_yards'] = Variable<int>(approachDistanceYards);
    }
    if (!nullToAbsent || teeClub != null) {
      map['tee_club'] = Variable<String>(teeClub);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  HoleResultsCompanion toCompanion(bool nullToAbsent) {
    return HoleResultsCompanion(
      id: Value(id),
      roundId: Value(roundId),
      holeNumber: Value(holeNumber),
      par: Value(par),
      score: Value(score),
      yards: Value(yards),
      fairwayHit: fairwayHit == null && nullToAbsent
          ? const Value.absent()
          : Value(fairwayHit),
      gir: Value(gir),
      putts: Value(putts),
      upDownAttempt: Value(upDownAttempt),
      upDownSuccess: Value(upDownSuccess),
      penaltyStrokes: Value(penaltyStrokes),
      bunkerVisited: Value(bunkerVisited),
      sandSave: Value(sandSave),
      driveDistanceYards: Value(driveDistanceYards),
      approachDistanceYards: approachDistanceYards == null && nullToAbsent
          ? const Value.absent()
          : Value(approachDistanceYards),
      teeClub: teeClub == null && nullToAbsent
          ? const Value.absent()
          : Value(teeClub),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory HoleResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoleResult(
      id: serializer.fromJson<int>(json['id']),
      roundId: serializer.fromJson<int>(json['roundId']),
      holeNumber: serializer.fromJson<int>(json['holeNumber']),
      par: serializer.fromJson<int>(json['par']),
      score: serializer.fromJson<int>(json['score']),
      yards: serializer.fromJson<int>(json['yards']),
      fairwayHit: serializer.fromJson<bool?>(json['fairwayHit']),
      gir: serializer.fromJson<bool>(json['gir']),
      putts: serializer.fromJson<int>(json['putts']),
      upDownAttempt: serializer.fromJson<bool>(json['upDownAttempt']),
      upDownSuccess: serializer.fromJson<bool>(json['upDownSuccess']),
      penaltyStrokes: serializer.fromJson<int>(json['penaltyStrokes']),
      bunkerVisited: serializer.fromJson<bool>(json['bunkerVisited']),
      sandSave: serializer.fromJson<bool>(json['sandSave']),
      driveDistanceYards: serializer.fromJson<int>(json['driveDistanceYards']),
      approachDistanceYards: serializer.fromJson<int?>(
        json['approachDistanceYards'],
      ),
      teeClub: serializer.fromJson<String?>(json['teeClub']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'roundId': serializer.toJson<int>(roundId),
      'holeNumber': serializer.toJson<int>(holeNumber),
      'par': serializer.toJson<int>(par),
      'score': serializer.toJson<int>(score),
      'yards': serializer.toJson<int>(yards),
      'fairwayHit': serializer.toJson<bool?>(fairwayHit),
      'gir': serializer.toJson<bool>(gir),
      'putts': serializer.toJson<int>(putts),
      'upDownAttempt': serializer.toJson<bool>(upDownAttempt),
      'upDownSuccess': serializer.toJson<bool>(upDownSuccess),
      'penaltyStrokes': serializer.toJson<int>(penaltyStrokes),
      'bunkerVisited': serializer.toJson<bool>(bunkerVisited),
      'sandSave': serializer.toJson<bool>(sandSave),
      'driveDistanceYards': serializer.toJson<int>(driveDistanceYards),
      'approachDistanceYards': serializer.toJson<int?>(approachDistanceYards),
      'teeClub': serializer.toJson<String?>(teeClub),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  HoleResult copyWith({
    int? id,
    int? roundId,
    int? holeNumber,
    int? par,
    int? score,
    int? yards,
    Value<bool?> fairwayHit = const Value.absent(),
    bool? gir,
    int? putts,
    bool? upDownAttempt,
    bool? upDownSuccess,
    int? penaltyStrokes,
    bool? bunkerVisited,
    bool? sandSave,
    int? driveDistanceYards,
    Value<int?> approachDistanceYards = const Value.absent(),
    Value<String?> teeClub = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => HoleResult(
    id: id ?? this.id,
    roundId: roundId ?? this.roundId,
    holeNumber: holeNumber ?? this.holeNumber,
    par: par ?? this.par,
    score: score ?? this.score,
    yards: yards ?? this.yards,
    fairwayHit: fairwayHit.present ? fairwayHit.value : this.fairwayHit,
    gir: gir ?? this.gir,
    putts: putts ?? this.putts,
    upDownAttempt: upDownAttempt ?? this.upDownAttempt,
    upDownSuccess: upDownSuccess ?? this.upDownSuccess,
    penaltyStrokes: penaltyStrokes ?? this.penaltyStrokes,
    bunkerVisited: bunkerVisited ?? this.bunkerVisited,
    sandSave: sandSave ?? this.sandSave,
    driveDistanceYards: driveDistanceYards ?? this.driveDistanceYards,
    approachDistanceYards: approachDistanceYards.present
        ? approachDistanceYards.value
        : this.approachDistanceYards,
    teeClub: teeClub.present ? teeClub.value : this.teeClub,
    notes: notes.present ? notes.value : this.notes,
  );
  HoleResult copyWithCompanion(HoleResultsCompanion data) {
    return HoleResult(
      id: data.id.present ? data.id.value : this.id,
      roundId: data.roundId.present ? data.roundId.value : this.roundId,
      holeNumber: data.holeNumber.present
          ? data.holeNumber.value
          : this.holeNumber,
      par: data.par.present ? data.par.value : this.par,
      score: data.score.present ? data.score.value : this.score,
      yards: data.yards.present ? data.yards.value : this.yards,
      fairwayHit: data.fairwayHit.present
          ? data.fairwayHit.value
          : this.fairwayHit,
      gir: data.gir.present ? data.gir.value : this.gir,
      putts: data.putts.present ? data.putts.value : this.putts,
      upDownAttempt: data.upDownAttempt.present
          ? data.upDownAttempt.value
          : this.upDownAttempt,
      upDownSuccess: data.upDownSuccess.present
          ? data.upDownSuccess.value
          : this.upDownSuccess,
      penaltyStrokes: data.penaltyStrokes.present
          ? data.penaltyStrokes.value
          : this.penaltyStrokes,
      bunkerVisited: data.bunkerVisited.present
          ? data.bunkerVisited.value
          : this.bunkerVisited,
      sandSave: data.sandSave.present ? data.sandSave.value : this.sandSave,
      driveDistanceYards: data.driveDistanceYards.present
          ? data.driveDistanceYards.value
          : this.driveDistanceYards,
      approachDistanceYards: data.approachDistanceYards.present
          ? data.approachDistanceYards.value
          : this.approachDistanceYards,
      teeClub: data.teeClub.present ? data.teeClub.value : this.teeClub,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoleResult(')
          ..write('id: $id, ')
          ..write('roundId: $roundId, ')
          ..write('holeNumber: $holeNumber, ')
          ..write('par: $par, ')
          ..write('score: $score, ')
          ..write('yards: $yards, ')
          ..write('fairwayHit: $fairwayHit, ')
          ..write('gir: $gir, ')
          ..write('putts: $putts, ')
          ..write('upDownAttempt: $upDownAttempt, ')
          ..write('upDownSuccess: $upDownSuccess, ')
          ..write('penaltyStrokes: $penaltyStrokes, ')
          ..write('bunkerVisited: $bunkerVisited, ')
          ..write('sandSave: $sandSave, ')
          ..write('driveDistanceYards: $driveDistanceYards, ')
          ..write('approachDistanceYards: $approachDistanceYards, ')
          ..write('teeClub: $teeClub, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    roundId,
    holeNumber,
    par,
    score,
    yards,
    fairwayHit,
    gir,
    putts,
    upDownAttempt,
    upDownSuccess,
    penaltyStrokes,
    bunkerVisited,
    sandSave,
    driveDistanceYards,
    approachDistanceYards,
    teeClub,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoleResult &&
          other.id == this.id &&
          other.roundId == this.roundId &&
          other.holeNumber == this.holeNumber &&
          other.par == this.par &&
          other.score == this.score &&
          other.yards == this.yards &&
          other.fairwayHit == this.fairwayHit &&
          other.gir == this.gir &&
          other.putts == this.putts &&
          other.upDownAttempt == this.upDownAttempt &&
          other.upDownSuccess == this.upDownSuccess &&
          other.penaltyStrokes == this.penaltyStrokes &&
          other.bunkerVisited == this.bunkerVisited &&
          other.sandSave == this.sandSave &&
          other.driveDistanceYards == this.driveDistanceYards &&
          other.approachDistanceYards == this.approachDistanceYards &&
          other.teeClub == this.teeClub &&
          other.notes == this.notes);
}

class HoleResultsCompanion extends UpdateCompanion<HoleResult> {
  final Value<int> id;
  final Value<int> roundId;
  final Value<int> holeNumber;
  final Value<int> par;
  final Value<int> score;
  final Value<int> yards;
  final Value<bool?> fairwayHit;
  final Value<bool> gir;
  final Value<int> putts;
  final Value<bool> upDownAttempt;
  final Value<bool> upDownSuccess;
  final Value<int> penaltyStrokes;
  final Value<bool> bunkerVisited;
  final Value<bool> sandSave;
  final Value<int> driveDistanceYards;
  final Value<int?> approachDistanceYards;
  final Value<String?> teeClub;
  final Value<String?> notes;
  const HoleResultsCompanion({
    this.id = const Value.absent(),
    this.roundId = const Value.absent(),
    this.holeNumber = const Value.absent(),
    this.par = const Value.absent(),
    this.score = const Value.absent(),
    this.yards = const Value.absent(),
    this.fairwayHit = const Value.absent(),
    this.gir = const Value.absent(),
    this.putts = const Value.absent(),
    this.upDownAttempt = const Value.absent(),
    this.upDownSuccess = const Value.absent(),
    this.penaltyStrokes = const Value.absent(),
    this.bunkerVisited = const Value.absent(),
    this.sandSave = const Value.absent(),
    this.driveDistanceYards = const Value.absent(),
    this.approachDistanceYards = const Value.absent(),
    this.teeClub = const Value.absent(),
    this.notes = const Value.absent(),
  });
  HoleResultsCompanion.insert({
    this.id = const Value.absent(),
    required int roundId,
    required int holeNumber,
    required int par,
    required int score,
    required int yards,
    this.fairwayHit = const Value.absent(),
    required bool gir,
    required int putts,
    required bool upDownAttempt,
    required bool upDownSuccess,
    required int penaltyStrokes,
    required bool bunkerVisited,
    required bool sandSave,
    required int driveDistanceYards,
    this.approachDistanceYards = const Value.absent(),
    this.teeClub = const Value.absent(),
    this.notes = const Value.absent(),
  }) : roundId = Value(roundId),
       holeNumber = Value(holeNumber),
       par = Value(par),
       score = Value(score),
       yards = Value(yards),
       gir = Value(gir),
       putts = Value(putts),
       upDownAttempt = Value(upDownAttempt),
       upDownSuccess = Value(upDownSuccess),
       penaltyStrokes = Value(penaltyStrokes),
       bunkerVisited = Value(bunkerVisited),
       sandSave = Value(sandSave),
       driveDistanceYards = Value(driveDistanceYards);
  static Insertable<HoleResult> custom({
    Expression<int>? id,
    Expression<int>? roundId,
    Expression<int>? holeNumber,
    Expression<int>? par,
    Expression<int>? score,
    Expression<int>? yards,
    Expression<bool>? fairwayHit,
    Expression<bool>? gir,
    Expression<int>? putts,
    Expression<bool>? upDownAttempt,
    Expression<bool>? upDownSuccess,
    Expression<int>? penaltyStrokes,
    Expression<bool>? bunkerVisited,
    Expression<bool>? sandSave,
    Expression<int>? driveDistanceYards,
    Expression<int>? approachDistanceYards,
    Expression<String>? teeClub,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roundId != null) 'round_id': roundId,
      if (holeNumber != null) 'hole_number': holeNumber,
      if (par != null) 'par': par,
      if (score != null) 'score': score,
      if (yards != null) 'yards': yards,
      if (fairwayHit != null) 'fairway_hit': fairwayHit,
      if (gir != null) 'gir': gir,
      if (putts != null) 'putts': putts,
      if (upDownAttempt != null) 'up_down_attempt': upDownAttempt,
      if (upDownSuccess != null) 'up_down_success': upDownSuccess,
      if (penaltyStrokes != null) 'penalty_strokes': penaltyStrokes,
      if (bunkerVisited != null) 'bunker_visited': bunkerVisited,
      if (sandSave != null) 'sand_save': sandSave,
      if (driveDistanceYards != null)
        'drive_distance_yards': driveDistanceYards,
      if (approachDistanceYards != null)
        'approach_distance_yards': approachDistanceYards,
      if (teeClub != null) 'tee_club': teeClub,
      if (notes != null) 'notes': notes,
    });
  }

  HoleResultsCompanion copyWith({
    Value<int>? id,
    Value<int>? roundId,
    Value<int>? holeNumber,
    Value<int>? par,
    Value<int>? score,
    Value<int>? yards,
    Value<bool?>? fairwayHit,
    Value<bool>? gir,
    Value<int>? putts,
    Value<bool>? upDownAttempt,
    Value<bool>? upDownSuccess,
    Value<int>? penaltyStrokes,
    Value<bool>? bunkerVisited,
    Value<bool>? sandSave,
    Value<int>? driveDistanceYards,
    Value<int?>? approachDistanceYards,
    Value<String?>? teeClub,
    Value<String?>? notes,
  }) {
    return HoleResultsCompanion(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      holeNumber: holeNumber ?? this.holeNumber,
      par: par ?? this.par,
      score: score ?? this.score,
      yards: yards ?? this.yards,
      fairwayHit: fairwayHit ?? this.fairwayHit,
      gir: gir ?? this.gir,
      putts: putts ?? this.putts,
      upDownAttempt: upDownAttempt ?? this.upDownAttempt,
      upDownSuccess: upDownSuccess ?? this.upDownSuccess,
      penaltyStrokes: penaltyStrokes ?? this.penaltyStrokes,
      bunkerVisited: bunkerVisited ?? this.bunkerVisited,
      sandSave: sandSave ?? this.sandSave,
      driveDistanceYards: driveDistanceYards ?? this.driveDistanceYards,
      approachDistanceYards:
          approachDistanceYards ?? this.approachDistanceYards,
      teeClub: teeClub ?? this.teeClub,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (roundId.present) {
      map['round_id'] = Variable<int>(roundId.value);
    }
    if (holeNumber.present) {
      map['hole_number'] = Variable<int>(holeNumber.value);
    }
    if (par.present) {
      map['par'] = Variable<int>(par.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (yards.present) {
      map['yards'] = Variable<int>(yards.value);
    }
    if (fairwayHit.present) {
      map['fairway_hit'] = Variable<bool>(fairwayHit.value);
    }
    if (gir.present) {
      map['gir'] = Variable<bool>(gir.value);
    }
    if (putts.present) {
      map['putts'] = Variable<int>(putts.value);
    }
    if (upDownAttempt.present) {
      map['up_down_attempt'] = Variable<bool>(upDownAttempt.value);
    }
    if (upDownSuccess.present) {
      map['up_down_success'] = Variable<bool>(upDownSuccess.value);
    }
    if (penaltyStrokes.present) {
      map['penalty_strokes'] = Variable<int>(penaltyStrokes.value);
    }
    if (bunkerVisited.present) {
      map['bunker_visited'] = Variable<bool>(bunkerVisited.value);
    }
    if (sandSave.present) {
      map['sand_save'] = Variable<bool>(sandSave.value);
    }
    if (driveDistanceYards.present) {
      map['drive_distance_yards'] = Variable<int>(driveDistanceYards.value);
    }
    if (approachDistanceYards.present) {
      map['approach_distance_yards'] = Variable<int>(
        approachDistanceYards.value,
      );
    }
    if (teeClub.present) {
      map['tee_club'] = Variable<String>(teeClub.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoleResultsCompanion(')
          ..write('id: $id, ')
          ..write('roundId: $roundId, ')
          ..write('holeNumber: $holeNumber, ')
          ..write('par: $par, ')
          ..write('score: $score, ')
          ..write('yards: $yards, ')
          ..write('fairwayHit: $fairwayHit, ')
          ..write('gir: $gir, ')
          ..write('putts: $putts, ')
          ..write('upDownAttempt: $upDownAttempt, ')
          ..write('upDownSuccess: $upDownSuccess, ')
          ..write('penaltyStrokes: $penaltyStrokes, ')
          ..write('bunkerVisited: $bunkerVisited, ')
          ..write('sandSave: $sandSave, ')
          ..write('driveDistanceYards: $driveDistanceYards, ')
          ..write('approachDistanceYards: $approachDistanceYards, ')
          ..write('teeClub: $teeClub, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

abstract class _$GolfyDatabase extends GeneratedDatabase {
  _$GolfyDatabase(QueryExecutor e) : super(e);
  $GolfyDatabaseManager get managers => $GolfyDatabaseManager(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $RoundsTable rounds = $RoundsTable(this);
  late final $HoleResultsTable holeResults = $HoleResultsTable(this);
  late final Index idxRoundsDate = Index(
    'idx_rounds_date',
    'CREATE INDEX idx_rounds_date ON rounds (date)',
  );
  late final Index idxRoundsCourse = Index(
    'idx_rounds_course',
    'CREATE INDEX idx_rounds_course ON rounds (course_id)',
  );
  late final Index idxHolesRound = Index(
    'idx_holes_round',
    'CREATE INDEX idx_holes_round ON hole_results (round_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    courses,
    rounds,
    holeResults,
    idxRoundsDate,
    idxRoundsCourse,
    idxHolesRound,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rounds',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('hole_results', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CoursesTableCreateCompanionBuilder =
    CoursesCompanion Function({
      Value<int> id,
      required String name,
      required String gameTitle,
    });
typedef $$CoursesTableUpdateCompanionBuilder =
    CoursesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> gameTitle,
    });

final class $$CoursesTableReferences
    extends BaseReferences<_$GolfyDatabase, $CoursesTable, Course> {
  $$CoursesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoundsTable, List<Round>> _roundsRefsTable(
    _$GolfyDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.rounds,
    aliasName: $_aliasNameGenerator(db.courses.id, db.rounds.courseId),
  );

  $$RoundsTableProcessedTableManager get roundsRefs {
    final manager = $$RoundsTableTableManager(
      $_db,
      $_db.rounds,
    ).filter((f) => f.courseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roundsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CoursesTableFilterComposer
    extends Composer<_$GolfyDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameTitle => $composableBuilder(
    column: $table.gameTitle,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> roundsRefs(
    Expression<bool> Function($$RoundsTableFilterComposer f) f,
  ) {
    final $$RoundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoundsTableFilterComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoursesTableOrderingComposer
    extends Composer<_$GolfyDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameTitle => $composableBuilder(
    column: $table.gameTitle,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get gameTitle =>
      $composableBuilder(column: $table.gameTitle, builder: (column) => column);

  Expression<T> roundsRefs<T extends Object>(
    Expression<T> Function($$RoundsTableAnnotationComposer a) f,
  ) {
    final $$RoundsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoundsTableAnnotationComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoursesTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $CoursesTable,
          Course,
          $$CoursesTableFilterComposer,
          $$CoursesTableOrderingComposer,
          $$CoursesTableAnnotationComposer,
          $$CoursesTableCreateCompanionBuilder,
          $$CoursesTableUpdateCompanionBuilder,
          (Course, $$CoursesTableReferences),
          Course,
          PrefetchHooks Function({bool roundsRefs})
        > {
  $$CoursesTableTableManager(_$GolfyDatabase db, $CoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> gameTitle = const Value.absent(),
              }) => CoursesCompanion(id: id, name: name, gameTitle: gameTitle),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String gameTitle,
              }) => CoursesCompanion.insert(
                id: id,
                name: name,
                gameTitle: gameTitle,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CoursesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({roundsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (roundsRefs) db.rounds],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (roundsRefs)
                    await $_getPrefetchedData<Course, $CoursesTable, Round>(
                      currentTable: table,
                      referencedTable: $$CoursesTableReferences
                          ._roundsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CoursesTableReferences(db, table, p0).roundsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.courseId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $CoursesTable,
      Course,
      $$CoursesTableFilterComposer,
      $$CoursesTableOrderingComposer,
      $$CoursesTableAnnotationComposer,
      $$CoursesTableCreateCompanionBuilder,
      $$CoursesTableUpdateCompanionBuilder,
      (Course, $$CoursesTableReferences),
      Course,
      PrefetchHooks Function({bool roundsRefs})
    >;
typedef $$RoundsTableCreateCompanionBuilder =
    RoundsCompanion Function({
      Value<int> id,
      required String date,
      required int courseId,
      Value<int> roundNumber,
      Value<String?> teeSet,
      Value<String?> weather,
      Value<int?> windSpeedMph,
      Value<String?> difficulty,
      Value<String?> notes,
    });
typedef $$RoundsTableUpdateCompanionBuilder =
    RoundsCompanion Function({
      Value<int> id,
      Value<String> date,
      Value<int> courseId,
      Value<int> roundNumber,
      Value<String?> teeSet,
      Value<String?> weather,
      Value<int?> windSpeedMph,
      Value<String?> difficulty,
      Value<String?> notes,
    });

final class $$RoundsTableReferences
    extends BaseReferences<_$GolfyDatabase, $RoundsTable, Round> {
  $$RoundsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$GolfyDatabase db) => db.courses
      .createAlias($_aliasNameGenerator(db.rounds.courseId, db.courses.id));

  $$CoursesTableProcessedTableManager get courseId {
    final $_column = $_itemColumn<int>('course_id')!;

    final manager = $$CoursesTableTableManager(
      $_db,
      $_db.courses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HoleResultsTable, List<HoleResult>>
  _holeResultsRefsTable(_$GolfyDatabase db) => MultiTypedResultKey.fromTable(
    db.holeResults,
    aliasName: $_aliasNameGenerator(db.rounds.id, db.holeResults.roundId),
  );

  $$HoleResultsTableProcessedTableManager get holeResultsRefs {
    final manager = $$HoleResultsTableTableManager(
      $_db,
      $_db.holeResults,
    ).filter((f) => f.roundId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_holeResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RoundsTableFilterComposer
    extends Composer<_$GolfyDatabase, $RoundsTable> {
  $$RoundsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roundNumber => $composableBuilder(
    column: $table.roundNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teeSet => $composableBuilder(
    column: $table.teeSet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windSpeedMph => $composableBuilder(
    column: $table.windSpeedMph,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$CoursesTableFilterComposer get courseId {
    final $$CoursesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableFilterComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> holeResultsRefs(
    Expression<bool> Function($$HoleResultsTableFilterComposer f) f,
  ) {
    final $$HoleResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.holeResults,
      getReferencedColumn: (t) => t.roundId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoleResultsTableFilterComposer(
            $db: $db,
            $table: $db.holeResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoundsTableOrderingComposer
    extends Composer<_$GolfyDatabase, $RoundsTable> {
  $$RoundsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roundNumber => $composableBuilder(
    column: $table.roundNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teeSet => $composableBuilder(
    column: $table.teeSet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windSpeedMph => $composableBuilder(
    column: $table.windSpeedMph,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoursesTableOrderingComposer get courseId {
    final $$CoursesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableOrderingComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoundsTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $RoundsTable> {
  $$RoundsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get roundNumber => $composableBuilder(
    column: $table.roundNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get teeSet =>
      $composableBuilder(column: $table.teeSet, builder: (column) => column);

  GeneratedColumn<String> get weather =>
      $composableBuilder(column: $table.weather, builder: (column) => column);

  GeneratedColumn<int> get windSpeedMph => $composableBuilder(
    column: $table.windSpeedMph,
    builder: (column) => column,
  );

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$CoursesTableAnnotationComposer get courseId {
    final $$CoursesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseId,
      referencedTable: $db.courses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoursesTableAnnotationComposer(
            $db: $db,
            $table: $db.courses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> holeResultsRefs<T extends Object>(
    Expression<T> Function($$HoleResultsTableAnnotationComposer a) f,
  ) {
    final $$HoleResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.holeResults,
      getReferencedColumn: (t) => t.roundId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoleResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.holeResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoundsTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $RoundsTable,
          Round,
          $$RoundsTableFilterComposer,
          $$RoundsTableOrderingComposer,
          $$RoundsTableAnnotationComposer,
          $$RoundsTableCreateCompanionBuilder,
          $$RoundsTableUpdateCompanionBuilder,
          (Round, $$RoundsTableReferences),
          Round,
          PrefetchHooks Function({bool courseId, bool holeResultsRefs})
        > {
  $$RoundsTableTableManager(_$GolfyDatabase db, $RoundsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoundsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoundsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoundsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> courseId = const Value.absent(),
                Value<int> roundNumber = const Value.absent(),
                Value<String?> teeSet = const Value.absent(),
                Value<String?> weather = const Value.absent(),
                Value<int?> windSpeedMph = const Value.absent(),
                Value<String?> difficulty = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => RoundsCompanion(
                id: id,
                date: date,
                courseId: courseId,
                roundNumber: roundNumber,
                teeSet: teeSet,
                weather: weather,
                windSpeedMph: windSpeedMph,
                difficulty: difficulty,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                required int courseId,
                Value<int> roundNumber = const Value.absent(),
                Value<String?> teeSet = const Value.absent(),
                Value<String?> weather = const Value.absent(),
                Value<int?> windSpeedMph = const Value.absent(),
                Value<String?> difficulty = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => RoundsCompanion.insert(
                id: id,
                date: date,
                courseId: courseId,
                roundNumber: roundNumber,
                teeSet: teeSet,
                weather: weather,
                windSpeedMph: windSpeedMph,
                difficulty: difficulty,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RoundsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({courseId = false, holeResultsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (holeResultsRefs) db.holeResults],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (courseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.courseId,
                                referencedTable: $$RoundsTableReferences
                                    ._courseIdTable(db),
                                referencedColumn: $$RoundsTableReferences
                                    ._courseIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (holeResultsRefs)
                    await $_getPrefetchedData<Round, $RoundsTable, HoleResult>(
                      currentTable: table,
                      referencedTable: $$RoundsTableReferences
                          ._holeResultsRefsTable(db),
                      managerFromTypedResult: (p0) => $$RoundsTableReferences(
                        db,
                        table,
                        p0,
                      ).holeResultsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.roundId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoundsTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $RoundsTable,
      Round,
      $$RoundsTableFilterComposer,
      $$RoundsTableOrderingComposer,
      $$RoundsTableAnnotationComposer,
      $$RoundsTableCreateCompanionBuilder,
      $$RoundsTableUpdateCompanionBuilder,
      (Round, $$RoundsTableReferences),
      Round,
      PrefetchHooks Function({bool courseId, bool holeResultsRefs})
    >;
typedef $$HoleResultsTableCreateCompanionBuilder =
    HoleResultsCompanion Function({
      Value<int> id,
      required int roundId,
      required int holeNumber,
      required int par,
      required int score,
      required int yards,
      Value<bool?> fairwayHit,
      required bool gir,
      required int putts,
      required bool upDownAttempt,
      required bool upDownSuccess,
      required int penaltyStrokes,
      required bool bunkerVisited,
      required bool sandSave,
      required int driveDistanceYards,
      Value<int?> approachDistanceYards,
      Value<String?> teeClub,
      Value<String?> notes,
    });
typedef $$HoleResultsTableUpdateCompanionBuilder =
    HoleResultsCompanion Function({
      Value<int> id,
      Value<int> roundId,
      Value<int> holeNumber,
      Value<int> par,
      Value<int> score,
      Value<int> yards,
      Value<bool?> fairwayHit,
      Value<bool> gir,
      Value<int> putts,
      Value<bool> upDownAttempt,
      Value<bool> upDownSuccess,
      Value<int> penaltyStrokes,
      Value<bool> bunkerVisited,
      Value<bool> sandSave,
      Value<int> driveDistanceYards,
      Value<int?> approachDistanceYards,
      Value<String?> teeClub,
      Value<String?> notes,
    });

final class $$HoleResultsTableReferences
    extends BaseReferences<_$GolfyDatabase, $HoleResultsTable, HoleResult> {
  $$HoleResultsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoundsTable _roundIdTable(_$GolfyDatabase db) => db.rounds
      .createAlias($_aliasNameGenerator(db.holeResults.roundId, db.rounds.id));

  $$RoundsTableProcessedTableManager get roundId {
    final $_column = $_itemColumn<int>('round_id')!;

    final manager = $$RoundsTableTableManager(
      $_db,
      $_db.rounds,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roundIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HoleResultsTableFilterComposer
    extends Composer<_$GolfyDatabase, $HoleResultsTable> {
  $$HoleResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get holeNumber => $composableBuilder(
    column: $table.holeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get par => $composableBuilder(
    column: $table.par,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get yards => $composableBuilder(
    column: $table.yards,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fairwayHit => $composableBuilder(
    column: $table.fairwayHit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get gir => $composableBuilder(
    column: $table.gir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get putts => $composableBuilder(
    column: $table.putts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get upDownAttempt => $composableBuilder(
    column: $table.upDownAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get upDownSuccess => $composableBuilder(
    column: $table.upDownSuccess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get penaltyStrokes => $composableBuilder(
    column: $table.penaltyStrokes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bunkerVisited => $composableBuilder(
    column: $table.bunkerVisited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sandSave => $composableBuilder(
    column: $table.sandSave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get driveDistanceYards => $composableBuilder(
    column: $table.driveDistanceYards,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get approachDistanceYards => $composableBuilder(
    column: $table.approachDistanceYards,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teeClub => $composableBuilder(
    column: $table.teeClub,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$RoundsTableFilterComposer get roundId {
    final $$RoundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roundId,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoundsTableFilterComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoleResultsTableOrderingComposer
    extends Composer<_$GolfyDatabase, $HoleResultsTable> {
  $$HoleResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get holeNumber => $composableBuilder(
    column: $table.holeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get par => $composableBuilder(
    column: $table.par,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get yards => $composableBuilder(
    column: $table.yards,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fairwayHit => $composableBuilder(
    column: $table.fairwayHit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get gir => $composableBuilder(
    column: $table.gir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get putts => $composableBuilder(
    column: $table.putts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get upDownAttempt => $composableBuilder(
    column: $table.upDownAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get upDownSuccess => $composableBuilder(
    column: $table.upDownSuccess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get penaltyStrokes => $composableBuilder(
    column: $table.penaltyStrokes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bunkerVisited => $composableBuilder(
    column: $table.bunkerVisited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sandSave => $composableBuilder(
    column: $table.sandSave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get driveDistanceYards => $composableBuilder(
    column: $table.driveDistanceYards,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get approachDistanceYards => $composableBuilder(
    column: $table.approachDistanceYards,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teeClub => $composableBuilder(
    column: $table.teeClub,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$RoundsTableOrderingComposer get roundId {
    final $$RoundsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roundId,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoundsTableOrderingComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoleResultsTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $HoleResultsTable> {
  $$HoleResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get holeNumber => $composableBuilder(
    column: $table.holeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get par =>
      $composableBuilder(column: $table.par, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get yards =>
      $composableBuilder(column: $table.yards, builder: (column) => column);

  GeneratedColumn<bool> get fairwayHit => $composableBuilder(
    column: $table.fairwayHit,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get gir =>
      $composableBuilder(column: $table.gir, builder: (column) => column);

  GeneratedColumn<int> get putts =>
      $composableBuilder(column: $table.putts, builder: (column) => column);

  GeneratedColumn<bool> get upDownAttempt => $composableBuilder(
    column: $table.upDownAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get upDownSuccess => $composableBuilder(
    column: $table.upDownSuccess,
    builder: (column) => column,
  );

  GeneratedColumn<int> get penaltyStrokes => $composableBuilder(
    column: $table.penaltyStrokes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get bunkerVisited => $composableBuilder(
    column: $table.bunkerVisited,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sandSave =>
      $composableBuilder(column: $table.sandSave, builder: (column) => column);

  GeneratedColumn<int> get driveDistanceYards => $composableBuilder(
    column: $table.driveDistanceYards,
    builder: (column) => column,
  );

  GeneratedColumn<int> get approachDistanceYards => $composableBuilder(
    column: $table.approachDistanceYards,
    builder: (column) => column,
  );

  GeneratedColumn<String> get teeClub =>
      $composableBuilder(column: $table.teeClub, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$RoundsTableAnnotationComposer get roundId {
    final $$RoundsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roundId,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoundsTableAnnotationComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoleResultsTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $HoleResultsTable,
          HoleResult,
          $$HoleResultsTableFilterComposer,
          $$HoleResultsTableOrderingComposer,
          $$HoleResultsTableAnnotationComposer,
          $$HoleResultsTableCreateCompanionBuilder,
          $$HoleResultsTableUpdateCompanionBuilder,
          (HoleResult, $$HoleResultsTableReferences),
          HoleResult,
          PrefetchHooks Function({bool roundId})
        > {
  $$HoleResultsTableTableManager(_$GolfyDatabase db, $HoleResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoleResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoleResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoleResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> roundId = const Value.absent(),
                Value<int> holeNumber = const Value.absent(),
                Value<int> par = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> yards = const Value.absent(),
                Value<bool?> fairwayHit = const Value.absent(),
                Value<bool> gir = const Value.absent(),
                Value<int> putts = const Value.absent(),
                Value<bool> upDownAttempt = const Value.absent(),
                Value<bool> upDownSuccess = const Value.absent(),
                Value<int> penaltyStrokes = const Value.absent(),
                Value<bool> bunkerVisited = const Value.absent(),
                Value<bool> sandSave = const Value.absent(),
                Value<int> driveDistanceYards = const Value.absent(),
                Value<int?> approachDistanceYards = const Value.absent(),
                Value<String?> teeClub = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => HoleResultsCompanion(
                id: id,
                roundId: roundId,
                holeNumber: holeNumber,
                par: par,
                score: score,
                yards: yards,
                fairwayHit: fairwayHit,
                gir: gir,
                putts: putts,
                upDownAttempt: upDownAttempt,
                upDownSuccess: upDownSuccess,
                penaltyStrokes: penaltyStrokes,
                bunkerVisited: bunkerVisited,
                sandSave: sandSave,
                driveDistanceYards: driveDistanceYards,
                approachDistanceYards: approachDistanceYards,
                teeClub: teeClub,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int roundId,
                required int holeNumber,
                required int par,
                required int score,
                required int yards,
                Value<bool?> fairwayHit = const Value.absent(),
                required bool gir,
                required int putts,
                required bool upDownAttempt,
                required bool upDownSuccess,
                required int penaltyStrokes,
                required bool bunkerVisited,
                required bool sandSave,
                required int driveDistanceYards,
                Value<int?> approachDistanceYards = const Value.absent(),
                Value<String?> teeClub = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => HoleResultsCompanion.insert(
                id: id,
                roundId: roundId,
                holeNumber: holeNumber,
                par: par,
                score: score,
                yards: yards,
                fairwayHit: fairwayHit,
                gir: gir,
                putts: putts,
                upDownAttempt: upDownAttempt,
                upDownSuccess: upDownSuccess,
                penaltyStrokes: penaltyStrokes,
                bunkerVisited: bunkerVisited,
                sandSave: sandSave,
                driveDistanceYards: driveDistanceYards,
                approachDistanceYards: approachDistanceYards,
                teeClub: teeClub,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HoleResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({roundId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (roundId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.roundId,
                                referencedTable: $$HoleResultsTableReferences
                                    ._roundIdTable(db),
                                referencedColumn: $$HoleResultsTableReferences
                                    ._roundIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HoleResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $HoleResultsTable,
      HoleResult,
      $$HoleResultsTableFilterComposer,
      $$HoleResultsTableOrderingComposer,
      $$HoleResultsTableAnnotationComposer,
      $$HoleResultsTableCreateCompanionBuilder,
      $$HoleResultsTableUpdateCompanionBuilder,
      (HoleResult, $$HoleResultsTableReferences),
      HoleResult,
      PrefetchHooks Function({bool roundId})
    >;

class $GolfyDatabaseManager {
  final _$GolfyDatabase _db;
  $GolfyDatabaseManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db, _db.rounds);
  $$HoleResultsTableTableManager get holeResults =>
      $$HoleResultsTableTableManager(_db, _db.holeResults);
}
