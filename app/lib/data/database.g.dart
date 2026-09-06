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

class $CourseSetsTable extends CourseSets
    with TableInfo<$CourseSetsTable, CourseSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourseSetsTable(this.attachedDatabase, [this._alias]);
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
      'REFERENCES courses (id) ON DELETE CASCADE',
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
  @override
  List<GeneratedColumn> get $columns => [id, courseId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'course_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {courseId, name},
  ];
  @override
  CourseSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $CourseSetsTable createAlias(String alias) {
    return $CourseSetsTable(attachedDatabase, alias);
  }
}

class CourseSet extends DataClass implements Insertable<CourseSet> {
  final int id;
  final int courseId;
  final String name;
  const CourseSet({
    required this.id,
    required this.courseId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['course_id'] = Variable<int>(courseId);
    map['name'] = Variable<String>(name);
    return map;
  }

  CourseSetsCompanion toCompanion(bool nullToAbsent) {
    return CourseSetsCompanion(
      id: Value(id),
      courseId: Value(courseId),
      name: Value(name),
    );
  }

  factory CourseSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseSet(
      id: serializer.fromJson<int>(json['id']),
      courseId: serializer.fromJson<int>(json['courseId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'courseId': serializer.toJson<int>(courseId),
      'name': serializer.toJson<String>(name),
    };
  }

  CourseSet copyWith({int? id, int? courseId, String? name}) => CourseSet(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    name: name ?? this.name,
  );
  CourseSet copyWithCompanion(CourseSetsCompanion data) {
    return CourseSet(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseSet(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, courseId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseSet &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.name == this.name);
}

class CourseSetsCompanion extends UpdateCompanion<CourseSet> {
  final Value<int> id;
  final Value<int> courseId;
  final Value<String> name;
  const CourseSetsCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.name = const Value.absent(),
  });
  CourseSetsCompanion.insert({
    this.id = const Value.absent(),
    required int courseId,
    required String name,
  }) : courseId = Value(courseId),
       name = Value(name);
  static Insertable<CourseSet> custom({
    Expression<int>? id,
    Expression<int>? courseId,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (name != null) 'name': name,
    });
  }

  CourseSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? courseId,
    Value<String>? name,
  }) {
    return CourseSetsCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourseSetsCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _finishPositionMeta = const VerificationMeta(
    'finishPosition',
  );
  @override
  late final GeneratedColumn<int> finishPosition = GeneratedColumn<int>(
    'finish_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tiedMeta = const VerificationMeta('tied');
  @override
  late final GeneratedColumn<bool> tied = GeneratedColumn<bool>(
    'tied',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tied" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _missedCutMeta = const VerificationMeta(
    'missedCut',
  );
  @override
  late final GeneratedColumn<bool> missedCut = GeneratedColumn<bool>(
    'missed_cut',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missed_cut" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    season,
    finishPosition,
    tied,
    missedCut,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
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
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('finish_position')) {
      context.handle(
        _finishPositionMeta,
        finishPosition.isAcceptableOrUnknown(
          data['finish_position']!,
          _finishPositionMeta,
        ),
      );
    }
    if (data.containsKey('tied')) {
      context.handle(
        _tiedMeta,
        tied.isAcceptableOrUnknown(data['tied']!, _tiedMeta),
      );
    }
    if (data.containsKey('missed_cut')) {
      context.handle(
        _missedCutMeta,
        missedCut.isAcceptableOrUnknown(data['missed_cut']!, _missedCutMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, season},
  ];
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      )!,
      finishPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}finish_position'],
      ),
      tied: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tied'],
      )!,
      missedCut: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missed_cut'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class Event extends DataClass implements Insertable<Event> {
  final int id;
  final String name;

  /// Which occurrence of [name] this is — a 1-based season number (#47).
  /// NOT NULL with a default of 1 (the first/sole occurrence): a nullable
  /// season would defeat the `(name, season)` UNIQUE, since SQLite treats NULLs
  /// as distinct and would let unlimited same-name rows through.
  final int season;

  /// Finishing position (1 = win). Null until a result is recorded.
  final int? finishPosition;

  /// Whether [finishPosition] was a tie (renders "T-3"). Requires a position.
  final bool tied;

  /// Player missed the cut. Mutually exclusive with [finishPosition] / [tied].
  final bool missedCut;
  const Event({
    required this.id,
    required this.name,
    required this.season,
    this.finishPosition,
    required this.tied,
    required this.missedCut,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['season'] = Variable<int>(season);
    if (!nullToAbsent || finishPosition != null) {
      map['finish_position'] = Variable<int>(finishPosition);
    }
    map['tied'] = Variable<bool>(tied);
    map['missed_cut'] = Variable<bool>(missedCut);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      name: Value(name),
      season: Value(season),
      finishPosition: finishPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(finishPosition),
      tied: Value(tied),
      missedCut: Value(missedCut),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      season: serializer.fromJson<int>(json['season']),
      finishPosition: serializer.fromJson<int?>(json['finishPosition']),
      tied: serializer.fromJson<bool>(json['tied']),
      missedCut: serializer.fromJson<bool>(json['missedCut']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'season': serializer.toJson<int>(season),
      'finishPosition': serializer.toJson<int?>(finishPosition),
      'tied': serializer.toJson<bool>(tied),
      'missedCut': serializer.toJson<bool>(missedCut),
    };
  }

  Event copyWith({
    int? id,
    String? name,
    int? season,
    Value<int?> finishPosition = const Value.absent(),
    bool? tied,
    bool? missedCut,
  }) => Event(
    id: id ?? this.id,
    name: name ?? this.name,
    season: season ?? this.season,
    finishPosition: finishPosition.present
        ? finishPosition.value
        : this.finishPosition,
    tied: tied ?? this.tied,
    missedCut: missedCut ?? this.missedCut,
  );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      season: data.season.present ? data.season.value : this.season,
      finishPosition: data.finishPosition.present
          ? data.finishPosition.value
          : this.finishPosition,
      tied: data.tied.present ? data.tied.value : this.tied,
      missedCut: data.missedCut.present ? data.missedCut.value : this.missedCut,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('season: $season, ')
          ..write('finishPosition: $finishPosition, ')
          ..write('tied: $tied, ')
          ..write('missedCut: $missedCut')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, season, finishPosition, tied, missedCut);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.name == this.name &&
          other.season == this.season &&
          other.finishPosition == this.finishPosition &&
          other.tied == this.tied &&
          other.missedCut == this.missedCut);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> season;
  final Value<int?> finishPosition;
  final Value<bool> tied;
  final Value<bool> missedCut;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.season = const Value.absent(),
    this.finishPosition = const Value.absent(),
    this.tied = const Value.absent(),
    this.missedCut = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.season = const Value.absent(),
    this.finishPosition = const Value.absent(),
    this.tied = const Value.absent(),
    this.missedCut = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Event> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? season,
    Expression<int>? finishPosition,
    Expression<bool>? tied,
    Expression<bool>? missedCut,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (season != null) 'season': season,
      if (finishPosition != null) 'finish_position': finishPosition,
      if (tied != null) 'tied': tied,
      if (missedCut != null) 'missed_cut': missedCut,
    });
  }

  EventsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? season,
    Value<int?>? finishPosition,
    Value<bool>? tied,
    Value<bool>? missedCut,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      season: season ?? this.season,
      finishPosition: finishPosition ?? this.finishPosition,
      tied: tied ?? this.tied,
      missedCut: missedCut ?? this.missedCut,
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
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (finishPosition.present) {
      map['finish_position'] = Variable<int>(finishPosition.value);
    }
    if (tied.present) {
      map['tied'] = Variable<bool>(tied.value);
    }
    if (missedCut.present) {
      map['missed_cut'] = Variable<bool>(missedCut.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('season: $season, ')
          ..write('finishPosition: $finishPosition, ')
          ..write('tied: $tied, ')
          ..write('missedCut: $missedCut')
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
  static const VerificationMeta _courseSetIdMeta = const VerificationMeta(
    'courseSetId',
  );
  @override
  late final GeneratedColumn<int> courseSetId = GeneratedColumn<int>(
    'course_set_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES course_sets (id) ON DELETE SET NULL',
    ),
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
  static const VerificationMeta _migrationCanaryMeta = const VerificationMeta(
    'migrationCanary',
  );
  @override
  late final GeneratedColumn<String> migrationCanary = GeneratedColumn<String>(
    'migration_canary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    courseId,
    roundNumber,
    teeSet,
    courseSetId,
    weather,
    windSpeedMph,
    difficulty,
    notes,
    migrationCanary,
    eventId,
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
    if (data.containsKey('course_set_id')) {
      context.handle(
        _courseSetIdMeta,
        courseSetId.isAcceptableOrUnknown(
          data['course_set_id']!,
          _courseSetIdMeta,
        ),
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
    if (data.containsKey('migration_canary')) {
      context.handle(
        _migrationCanaryMeta,
        migrationCanary.isAcceptableOrUnknown(
          data['migration_canary']!,
          _migrationCanaryMeta,
        ),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
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
      courseSetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_set_id'],
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
      migrationCanary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}migration_canary'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
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

  /// Legacy free-text tee-set label from the original schema. Never written by
  /// the app; superseded by [courseSetId] (#36) and left in place only so the
  /// v6 migration stays additive. Safe to drop in a later tidy.
  final String? teeSet;

  /// The [CourseSets] yardage set this round was played on (#36), or null for a
  /// round with no set chosen. `SET NULL` on delete so removing a set detaches
  /// its rounds rather than destroying them; Hole Entry pulls the round's
  /// yardages from this set.
  final int? courseSetId;
  final String? weather;
  final int? windSpeedMph;
  final String? difficulty;
  final String? notes;

  /// Inert column added in schema v2 to prove the drift migration pipeline
  /// end to end (#24). It carries no behaviour and is intentionally nullable so
  /// the upgrade is a plain `addColumn`. A later real migration (e.g. #22) may
  /// drop it.
  final String? migrationCanary;

  /// Optional link to the [Events] competition this round belongs to (#35).
  /// Nullable because casual rounds have no event; `SET NULL` on delete so
  /// removing an event detaches its rounds rather than destroying their holes.
  final int? eventId;
  const Round({
    required this.id,
    required this.date,
    required this.courseId,
    required this.roundNumber,
    this.teeSet,
    this.courseSetId,
    this.weather,
    this.windSpeedMph,
    this.difficulty,
    this.notes,
    this.migrationCanary,
    this.eventId,
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
    if (!nullToAbsent || courseSetId != null) {
      map['course_set_id'] = Variable<int>(courseSetId);
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
    if (!nullToAbsent || migrationCanary != null) {
      map['migration_canary'] = Variable<String>(migrationCanary);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<int>(eventId);
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
      courseSetId: courseSetId == null && nullToAbsent
          ? const Value.absent()
          : Value(courseSetId),
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
      migrationCanary: migrationCanary == null && nullToAbsent
          ? const Value.absent()
          : Value(migrationCanary),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
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
      courseSetId: serializer.fromJson<int?>(json['courseSetId']),
      weather: serializer.fromJson<String?>(json['weather']),
      windSpeedMph: serializer.fromJson<int?>(json['windSpeedMph']),
      difficulty: serializer.fromJson<String?>(json['difficulty']),
      notes: serializer.fromJson<String?>(json['notes']),
      migrationCanary: serializer.fromJson<String?>(json['migrationCanary']),
      eventId: serializer.fromJson<int?>(json['eventId']),
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
      'courseSetId': serializer.toJson<int?>(courseSetId),
      'weather': serializer.toJson<String?>(weather),
      'windSpeedMph': serializer.toJson<int?>(windSpeedMph),
      'difficulty': serializer.toJson<String?>(difficulty),
      'notes': serializer.toJson<String?>(notes),
      'migrationCanary': serializer.toJson<String?>(migrationCanary),
      'eventId': serializer.toJson<int?>(eventId),
    };
  }

  Round copyWith({
    int? id,
    String? date,
    int? courseId,
    int? roundNumber,
    Value<String?> teeSet = const Value.absent(),
    Value<int?> courseSetId = const Value.absent(),
    Value<String?> weather = const Value.absent(),
    Value<int?> windSpeedMph = const Value.absent(),
    Value<String?> difficulty = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> migrationCanary = const Value.absent(),
    Value<int?> eventId = const Value.absent(),
  }) => Round(
    id: id ?? this.id,
    date: date ?? this.date,
    courseId: courseId ?? this.courseId,
    roundNumber: roundNumber ?? this.roundNumber,
    teeSet: teeSet.present ? teeSet.value : this.teeSet,
    courseSetId: courseSetId.present ? courseSetId.value : this.courseSetId,
    weather: weather.present ? weather.value : this.weather,
    windSpeedMph: windSpeedMph.present ? windSpeedMph.value : this.windSpeedMph,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    notes: notes.present ? notes.value : this.notes,
    migrationCanary: migrationCanary.present
        ? migrationCanary.value
        : this.migrationCanary,
    eventId: eventId.present ? eventId.value : this.eventId,
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
      courseSetId: data.courseSetId.present
          ? data.courseSetId.value
          : this.courseSetId,
      weather: data.weather.present ? data.weather.value : this.weather,
      windSpeedMph: data.windSpeedMph.present
          ? data.windSpeedMph.value
          : this.windSpeedMph,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      notes: data.notes.present ? data.notes.value : this.notes,
      migrationCanary: data.migrationCanary.present
          ? data.migrationCanary.value
          : this.migrationCanary,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
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
          ..write('courseSetId: $courseSetId, ')
          ..write('weather: $weather, ')
          ..write('windSpeedMph: $windSpeedMph, ')
          ..write('difficulty: $difficulty, ')
          ..write('notes: $notes, ')
          ..write('migrationCanary: $migrationCanary, ')
          ..write('eventId: $eventId')
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
    courseSetId,
    weather,
    windSpeedMph,
    difficulty,
    notes,
    migrationCanary,
    eventId,
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
          other.courseSetId == this.courseSetId &&
          other.weather == this.weather &&
          other.windSpeedMph == this.windSpeedMph &&
          other.difficulty == this.difficulty &&
          other.notes == this.notes &&
          other.migrationCanary == this.migrationCanary &&
          other.eventId == this.eventId);
}

class RoundsCompanion extends UpdateCompanion<Round> {
  final Value<int> id;
  final Value<String> date;
  final Value<int> courseId;
  final Value<int> roundNumber;
  final Value<String?> teeSet;
  final Value<int?> courseSetId;
  final Value<String?> weather;
  final Value<int?> windSpeedMph;
  final Value<String?> difficulty;
  final Value<String?> notes;
  final Value<String?> migrationCanary;
  final Value<int?> eventId;
  const RoundsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.courseId = const Value.absent(),
    this.roundNumber = const Value.absent(),
    this.teeSet = const Value.absent(),
    this.courseSetId = const Value.absent(),
    this.weather = const Value.absent(),
    this.windSpeedMph = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.notes = const Value.absent(),
    this.migrationCanary = const Value.absent(),
    this.eventId = const Value.absent(),
  });
  RoundsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required int courseId,
    this.roundNumber = const Value.absent(),
    this.teeSet = const Value.absent(),
    this.courseSetId = const Value.absent(),
    this.weather = const Value.absent(),
    this.windSpeedMph = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.notes = const Value.absent(),
    this.migrationCanary = const Value.absent(),
    this.eventId = const Value.absent(),
  }) : date = Value(date),
       courseId = Value(courseId);
  static Insertable<Round> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<int>? courseId,
    Expression<int>? roundNumber,
    Expression<String>? teeSet,
    Expression<int>? courseSetId,
    Expression<String>? weather,
    Expression<int>? windSpeedMph,
    Expression<String>? difficulty,
    Expression<String>? notes,
    Expression<String>? migrationCanary,
    Expression<int>? eventId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (courseId != null) 'course_id': courseId,
      if (roundNumber != null) 'round_number': roundNumber,
      if (teeSet != null) 'tee_set': teeSet,
      if (courseSetId != null) 'course_set_id': courseSetId,
      if (weather != null) 'weather': weather,
      if (windSpeedMph != null) 'wind_speed_mph': windSpeedMph,
      if (difficulty != null) 'difficulty': difficulty,
      if (notes != null) 'notes': notes,
      if (migrationCanary != null) 'migration_canary': migrationCanary,
      if (eventId != null) 'event_id': eventId,
    });
  }

  RoundsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<int>? courseId,
    Value<int>? roundNumber,
    Value<String?>? teeSet,
    Value<int?>? courseSetId,
    Value<String?>? weather,
    Value<int?>? windSpeedMph,
    Value<String?>? difficulty,
    Value<String?>? notes,
    Value<String?>? migrationCanary,
    Value<int?>? eventId,
  }) {
    return RoundsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      courseId: courseId ?? this.courseId,
      roundNumber: roundNumber ?? this.roundNumber,
      teeSet: teeSet ?? this.teeSet,
      courseSetId: courseSetId ?? this.courseSetId,
      weather: weather ?? this.weather,
      windSpeedMph: windSpeedMph ?? this.windSpeedMph,
      difficulty: difficulty ?? this.difficulty,
      notes: notes ?? this.notes,
      migrationCanary: migrationCanary ?? this.migrationCanary,
      eventId: eventId ?? this.eventId,
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
    if (courseSetId.present) {
      map['course_set_id'] = Variable<int>(courseSetId.value);
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
    if (migrationCanary.present) {
      map['migration_canary'] = Variable<String>(migrationCanary.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
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
          ..write('courseSetId: $courseSetId, ')
          ..write('weather: $weather, ')
          ..write('windSpeedMph: $windSpeedMph, ')
          ..write('difficulty: $difficulty, ')
          ..write('notes: $notes, ')
          ..write('migrationCanary: $migrationCanary, ')
          ..write('eventId: $eventId')
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
       sandSave = Value(sandSave);
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
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $CourseHolesTable extends CourseHoles
    with TableInfo<$CourseHolesTable, CourseHole> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourseHolesTable(this.attachedDatabase, [this._alias]);
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
      'REFERENCES courses (id) ON DELETE CASCADE',
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
  static const VerificationMeta _strokeIndexMeta = const VerificationMeta(
    'strokeIndex',
  );
  @override
  late final GeneratedColumn<int> strokeIndex = GeneratedColumn<int>(
    'stroke_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (stroke_index BETWEEN 1 AND 18)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    holeNumber,
    par,
    strokeIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'course_holes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseHole> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
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
    if (data.containsKey('stroke_index')) {
      context.handle(
        _strokeIndexMeta,
        strokeIndex.isAcceptableOrUnknown(
          data['stroke_index']!,
          _strokeIndexMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {courseId, holeNumber},
  ];
  @override
  CourseHole map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseHole(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      )!,
      holeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hole_number'],
      )!,
      par: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}par'],
      )!,
      strokeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stroke_index'],
      ),
    );
  }

  @override
  $CourseHolesTable createAlias(String alias) {
    return $CourseHolesTable(attachedDatabase, alias);
  }
}

class CourseHole extends DataClass implements Insertable<CourseHole> {
  final int id;
  final int courseId;
  final int holeNumber;
  final int par;

  /// Handicap stroke index (1 = hardest hole … 18 = easiest). Optional — many
  /// video-game courses don't surface it — so nullable, with the 1–18 CHECK
  /// applied only when a value is present.
  final int? strokeIndex;
  const CourseHole({
    required this.id,
    required this.courseId,
    required this.holeNumber,
    required this.par,
    this.strokeIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['course_id'] = Variable<int>(courseId);
    map['hole_number'] = Variable<int>(holeNumber);
    map['par'] = Variable<int>(par);
    if (!nullToAbsent || strokeIndex != null) {
      map['stroke_index'] = Variable<int>(strokeIndex);
    }
    return map;
  }

  CourseHolesCompanion toCompanion(bool nullToAbsent) {
    return CourseHolesCompanion(
      id: Value(id),
      courseId: Value(courseId),
      holeNumber: Value(holeNumber),
      par: Value(par),
      strokeIndex: strokeIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(strokeIndex),
    );
  }

  factory CourseHole.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseHole(
      id: serializer.fromJson<int>(json['id']),
      courseId: serializer.fromJson<int>(json['courseId']),
      holeNumber: serializer.fromJson<int>(json['holeNumber']),
      par: serializer.fromJson<int>(json['par']),
      strokeIndex: serializer.fromJson<int?>(json['strokeIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'courseId': serializer.toJson<int>(courseId),
      'holeNumber': serializer.toJson<int>(holeNumber),
      'par': serializer.toJson<int>(par),
      'strokeIndex': serializer.toJson<int?>(strokeIndex),
    };
  }

  CourseHole copyWith({
    int? id,
    int? courseId,
    int? holeNumber,
    int? par,
    Value<int?> strokeIndex = const Value.absent(),
  }) => CourseHole(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    holeNumber: holeNumber ?? this.holeNumber,
    par: par ?? this.par,
    strokeIndex: strokeIndex.present ? strokeIndex.value : this.strokeIndex,
  );
  CourseHole copyWithCompanion(CourseHolesCompanion data) {
    return CourseHole(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      holeNumber: data.holeNumber.present
          ? data.holeNumber.value
          : this.holeNumber,
      par: data.par.present ? data.par.value : this.par,
      strokeIndex: data.strokeIndex.present
          ? data.strokeIndex.value
          : this.strokeIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseHole(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('holeNumber: $holeNumber, ')
          ..write('par: $par, ')
          ..write('strokeIndex: $strokeIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, courseId, holeNumber, par, strokeIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseHole &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.holeNumber == this.holeNumber &&
          other.par == this.par &&
          other.strokeIndex == this.strokeIndex);
}

class CourseHolesCompanion extends UpdateCompanion<CourseHole> {
  final Value<int> id;
  final Value<int> courseId;
  final Value<int> holeNumber;
  final Value<int> par;
  final Value<int?> strokeIndex;
  const CourseHolesCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.holeNumber = const Value.absent(),
    this.par = const Value.absent(),
    this.strokeIndex = const Value.absent(),
  });
  CourseHolesCompanion.insert({
    this.id = const Value.absent(),
    required int courseId,
    required int holeNumber,
    required int par,
    this.strokeIndex = const Value.absent(),
  }) : courseId = Value(courseId),
       holeNumber = Value(holeNumber),
       par = Value(par);
  static Insertable<CourseHole> custom({
    Expression<int>? id,
    Expression<int>? courseId,
    Expression<int>? holeNumber,
    Expression<int>? par,
    Expression<int>? strokeIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (holeNumber != null) 'hole_number': holeNumber,
      if (par != null) 'par': par,
      if (strokeIndex != null) 'stroke_index': strokeIndex,
    });
  }

  CourseHolesCompanion copyWith({
    Value<int>? id,
    Value<int>? courseId,
    Value<int>? holeNumber,
    Value<int>? par,
    Value<int?>? strokeIndex,
  }) {
    return CourseHolesCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      holeNumber: holeNumber ?? this.holeNumber,
      par: par ?? this.par,
      strokeIndex: strokeIndex ?? this.strokeIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (holeNumber.present) {
      map['hole_number'] = Variable<int>(holeNumber.value);
    }
    if (par.present) {
      map['par'] = Variable<int>(par.value);
    }
    if (strokeIndex.present) {
      map['stroke_index'] = Variable<int>(strokeIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourseHolesCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('holeNumber: $holeNumber, ')
          ..write('par: $par, ')
          ..write('strokeIndex: $strokeIndex')
          ..write(')'))
        .toString();
  }
}

class $CourseSetYardsTable extends CourseSetYards
    with TableInfo<$CourseSetYardsTable, CourseSetYard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CourseSetYardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _courseSetIdMeta = const VerificationMeta(
    'courseSetId',
  );
  @override
  late final GeneratedColumn<int> courseSetId = GeneratedColumn<int>(
    'course_set_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES course_sets (id) ON DELETE CASCADE',
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
  @override
  List<GeneratedColumn> get $columns => [id, courseSetId, holeNumber, yards];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'course_set_yards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CourseSetYard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('course_set_id')) {
      context.handle(
        _courseSetIdMeta,
        courseSetId.isAcceptableOrUnknown(
          data['course_set_id']!,
          _courseSetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_courseSetIdMeta);
    }
    if (data.containsKey('hole_number')) {
      context.handle(
        _holeNumberMeta,
        holeNumber.isAcceptableOrUnknown(data['hole_number']!, _holeNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_holeNumberMeta);
    }
    if (data.containsKey('yards')) {
      context.handle(
        _yardsMeta,
        yards.isAcceptableOrUnknown(data['yards']!, _yardsMeta),
      );
    } else if (isInserting) {
      context.missing(_yardsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {courseSetId, holeNumber},
  ];
  @override
  CourseSetYard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseSetYard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      courseSetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_set_id'],
      )!,
      holeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hole_number'],
      )!,
      yards: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}yards'],
      )!,
    );
  }

  @override
  $CourseSetYardsTable createAlias(String alias) {
    return $CourseSetYardsTable(attachedDatabase, alias);
  }
}

class CourseSetYard extends DataClass implements Insertable<CourseSetYard> {
  final int id;
  final int courseSetId;
  final int holeNumber;
  final int yards;
  const CourseSetYard({
    required this.id,
    required this.courseSetId,
    required this.holeNumber,
    required this.yards,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['course_set_id'] = Variable<int>(courseSetId);
    map['hole_number'] = Variable<int>(holeNumber);
    map['yards'] = Variable<int>(yards);
    return map;
  }

  CourseSetYardsCompanion toCompanion(bool nullToAbsent) {
    return CourseSetYardsCompanion(
      id: Value(id),
      courseSetId: Value(courseSetId),
      holeNumber: Value(holeNumber),
      yards: Value(yards),
    );
  }

  factory CourseSetYard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseSetYard(
      id: serializer.fromJson<int>(json['id']),
      courseSetId: serializer.fromJson<int>(json['courseSetId']),
      holeNumber: serializer.fromJson<int>(json['holeNumber']),
      yards: serializer.fromJson<int>(json['yards']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'courseSetId': serializer.toJson<int>(courseSetId),
      'holeNumber': serializer.toJson<int>(holeNumber),
      'yards': serializer.toJson<int>(yards),
    };
  }

  CourseSetYard copyWith({
    int? id,
    int? courseSetId,
    int? holeNumber,
    int? yards,
  }) => CourseSetYard(
    id: id ?? this.id,
    courseSetId: courseSetId ?? this.courseSetId,
    holeNumber: holeNumber ?? this.holeNumber,
    yards: yards ?? this.yards,
  );
  CourseSetYard copyWithCompanion(CourseSetYardsCompanion data) {
    return CourseSetYard(
      id: data.id.present ? data.id.value : this.id,
      courseSetId: data.courseSetId.present
          ? data.courseSetId.value
          : this.courseSetId,
      holeNumber: data.holeNumber.present
          ? data.holeNumber.value
          : this.holeNumber,
      yards: data.yards.present ? data.yards.value : this.yards,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseSetYard(')
          ..write('id: $id, ')
          ..write('courseSetId: $courseSetId, ')
          ..write('holeNumber: $holeNumber, ')
          ..write('yards: $yards')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, courseSetId, holeNumber, yards);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseSetYard &&
          other.id == this.id &&
          other.courseSetId == this.courseSetId &&
          other.holeNumber == this.holeNumber &&
          other.yards == this.yards);
}

class CourseSetYardsCompanion extends UpdateCompanion<CourseSetYard> {
  final Value<int> id;
  final Value<int> courseSetId;
  final Value<int> holeNumber;
  final Value<int> yards;
  const CourseSetYardsCompanion({
    this.id = const Value.absent(),
    this.courseSetId = const Value.absent(),
    this.holeNumber = const Value.absent(),
    this.yards = const Value.absent(),
  });
  CourseSetYardsCompanion.insert({
    this.id = const Value.absent(),
    required int courseSetId,
    required int holeNumber,
    required int yards,
  }) : courseSetId = Value(courseSetId),
       holeNumber = Value(holeNumber),
       yards = Value(yards);
  static Insertable<CourseSetYard> custom({
    Expression<int>? id,
    Expression<int>? courseSetId,
    Expression<int>? holeNumber,
    Expression<int>? yards,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseSetId != null) 'course_set_id': courseSetId,
      if (holeNumber != null) 'hole_number': holeNumber,
      if (yards != null) 'yards': yards,
    });
  }

  CourseSetYardsCompanion copyWith({
    Value<int>? id,
    Value<int>? courseSetId,
    Value<int>? holeNumber,
    Value<int>? yards,
  }) {
    return CourseSetYardsCompanion(
      id: id ?? this.id,
      courseSetId: courseSetId ?? this.courseSetId,
      holeNumber: holeNumber ?? this.holeNumber,
      yards: yards ?? this.yards,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (courseSetId.present) {
      map['course_set_id'] = Variable<int>(courseSetId.value);
    }
    if (holeNumber.present) {
      map['hole_number'] = Variable<int>(holeNumber.value);
    }
    if (yards.present) {
      map['yards'] = Variable<int>(yards.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CourseSetYardsCompanion(')
          ..write('id: $id, ')
          ..write('courseSetId: $courseSetId, ')
          ..write('holeNumber: $holeNumber, ')
          ..write('yards: $yards')
          ..write(')'))
        .toString();
  }
}

class $HoleShotsTable extends HoleShots
    with TableInfo<$HoleShotsTable, HoleShot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoleShotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _holeResultIdMeta = const VerificationMeta(
    'holeResultId',
  );
  @override
  late final GeneratedColumn<int> holeResultId = GeneratedColumn<int>(
    'hole_result_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES hole_results (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _shotNumberMeta = const VerificationMeta(
    'shotNumber',
  );
  @override
  late final GeneratedColumn<int> shotNumber = GeneratedColumn<int>(
    'shot_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (shot_number >= 1)',
  );
  static const VerificationMeta _clubMeta = const VerificationMeta('club');
  @override
  late final GeneratedColumn<String> club = GeneratedColumn<String>(
    'club',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceYardsMeta = const VerificationMeta(
    'distanceYards',
  );
  @override
  late final GeneratedColumn<int> distanceYards = GeneratedColumn<int>(
    'distance_yards',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (distance_yards >= 0)',
  );
  static const VerificationMeta _lieMeta = const VerificationMeta('lie');
  @override
  late final GeneratedColumn<String> lie = GeneratedColumn<String>(
    'lie',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    holeResultId,
    shotNumber,
    club,
    distanceYards,
    lie,
    result,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hole_shots';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoleShot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('hole_result_id')) {
      context.handle(
        _holeResultIdMeta,
        holeResultId.isAcceptableOrUnknown(
          data['hole_result_id']!,
          _holeResultIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_holeResultIdMeta);
    }
    if (data.containsKey('shot_number')) {
      context.handle(
        _shotNumberMeta,
        shotNumber.isAcceptableOrUnknown(data['shot_number']!, _shotNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_shotNumberMeta);
    }
    if (data.containsKey('club')) {
      context.handle(
        _clubMeta,
        club.isAcceptableOrUnknown(data['club']!, _clubMeta),
      );
    }
    if (data.containsKey('distance_yards')) {
      context.handle(
        _distanceYardsMeta,
        distanceYards.isAcceptableOrUnknown(
          data['distance_yards']!,
          _distanceYardsMeta,
        ),
      );
    }
    if (data.containsKey('lie')) {
      context.handle(
        _lieMeta,
        lie.isAcceptableOrUnknown(data['lie']!, _lieMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {holeResultId, shotNumber},
  ];
  @override
  HoleShot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoleShot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      holeResultId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hole_result_id'],
      )!,
      shotNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shot_number'],
      )!,
      club: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}club'],
      ),
      distanceYards: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distance_yards'],
      ),
      lie: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lie'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
    );
  }

  @override
  $HoleShotsTable createAlias(String alias) {
    return $HoleShotsTable(attachedDatabase, alias);
  }
}

class HoleShot extends DataClass implements Insertable<HoleShot> {
  final int id;
  final int holeResultId;
  final int shotNumber;
  final String? club;
  final int? distanceYards;

  /// Where the shot was played from — e.g. Tee / Fairway / Rough / Bunker /
  /// Green / Recovery. Free-ish text (a small preset list in the UI).
  final String? lie;

  /// Where the shot finished / its outcome — e.g. Fairway / Green / Rough /
  /// Bunker / Sand / Holed / Penalty. Free-ish text (a small preset list).
  final String? result;
  const HoleShot({
    required this.id,
    required this.holeResultId,
    required this.shotNumber,
    this.club,
    this.distanceYards,
    this.lie,
    this.result,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['hole_result_id'] = Variable<int>(holeResultId);
    map['shot_number'] = Variable<int>(shotNumber);
    if (!nullToAbsent || club != null) {
      map['club'] = Variable<String>(club);
    }
    if (!nullToAbsent || distanceYards != null) {
      map['distance_yards'] = Variable<int>(distanceYards);
    }
    if (!nullToAbsent || lie != null) {
      map['lie'] = Variable<String>(lie);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    return map;
  }

  HoleShotsCompanion toCompanion(bool nullToAbsent) {
    return HoleShotsCompanion(
      id: Value(id),
      holeResultId: Value(holeResultId),
      shotNumber: Value(shotNumber),
      club: club == null && nullToAbsent ? const Value.absent() : Value(club),
      distanceYards: distanceYards == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceYards),
      lie: lie == null && nullToAbsent ? const Value.absent() : Value(lie),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
    );
  }

  factory HoleShot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoleShot(
      id: serializer.fromJson<int>(json['id']),
      holeResultId: serializer.fromJson<int>(json['holeResultId']),
      shotNumber: serializer.fromJson<int>(json['shotNumber']),
      club: serializer.fromJson<String?>(json['club']),
      distanceYards: serializer.fromJson<int?>(json['distanceYards']),
      lie: serializer.fromJson<String?>(json['lie']),
      result: serializer.fromJson<String?>(json['result']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'holeResultId': serializer.toJson<int>(holeResultId),
      'shotNumber': serializer.toJson<int>(shotNumber),
      'club': serializer.toJson<String?>(club),
      'distanceYards': serializer.toJson<int?>(distanceYards),
      'lie': serializer.toJson<String?>(lie),
      'result': serializer.toJson<String?>(result),
    };
  }

  HoleShot copyWith({
    int? id,
    int? holeResultId,
    int? shotNumber,
    Value<String?> club = const Value.absent(),
    Value<int?> distanceYards = const Value.absent(),
    Value<String?> lie = const Value.absent(),
    Value<String?> result = const Value.absent(),
  }) => HoleShot(
    id: id ?? this.id,
    holeResultId: holeResultId ?? this.holeResultId,
    shotNumber: shotNumber ?? this.shotNumber,
    club: club.present ? club.value : this.club,
    distanceYards: distanceYards.present
        ? distanceYards.value
        : this.distanceYards,
    lie: lie.present ? lie.value : this.lie,
    result: result.present ? result.value : this.result,
  );
  HoleShot copyWithCompanion(HoleShotsCompanion data) {
    return HoleShot(
      id: data.id.present ? data.id.value : this.id,
      holeResultId: data.holeResultId.present
          ? data.holeResultId.value
          : this.holeResultId,
      shotNumber: data.shotNumber.present
          ? data.shotNumber.value
          : this.shotNumber,
      club: data.club.present ? data.club.value : this.club,
      distanceYards: data.distanceYards.present
          ? data.distanceYards.value
          : this.distanceYards,
      lie: data.lie.present ? data.lie.value : this.lie,
      result: data.result.present ? data.result.value : this.result,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoleShot(')
          ..write('id: $id, ')
          ..write('holeResultId: $holeResultId, ')
          ..write('shotNumber: $shotNumber, ')
          ..write('club: $club, ')
          ..write('distanceYards: $distanceYards, ')
          ..write('lie: $lie, ')
          ..write('result: $result')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    holeResultId,
    shotNumber,
    club,
    distanceYards,
    lie,
    result,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoleShot &&
          other.id == this.id &&
          other.holeResultId == this.holeResultId &&
          other.shotNumber == this.shotNumber &&
          other.club == this.club &&
          other.distanceYards == this.distanceYards &&
          other.lie == this.lie &&
          other.result == this.result);
}

class HoleShotsCompanion extends UpdateCompanion<HoleShot> {
  final Value<int> id;
  final Value<int> holeResultId;
  final Value<int> shotNumber;
  final Value<String?> club;
  final Value<int?> distanceYards;
  final Value<String?> lie;
  final Value<String?> result;
  const HoleShotsCompanion({
    this.id = const Value.absent(),
    this.holeResultId = const Value.absent(),
    this.shotNumber = const Value.absent(),
    this.club = const Value.absent(),
    this.distanceYards = const Value.absent(),
    this.lie = const Value.absent(),
    this.result = const Value.absent(),
  });
  HoleShotsCompanion.insert({
    this.id = const Value.absent(),
    required int holeResultId,
    required int shotNumber,
    this.club = const Value.absent(),
    this.distanceYards = const Value.absent(),
    this.lie = const Value.absent(),
    this.result = const Value.absent(),
  }) : holeResultId = Value(holeResultId),
       shotNumber = Value(shotNumber);
  static Insertable<HoleShot> custom({
    Expression<int>? id,
    Expression<int>? holeResultId,
    Expression<int>? shotNumber,
    Expression<String>? club,
    Expression<int>? distanceYards,
    Expression<String>? lie,
    Expression<String>? result,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (holeResultId != null) 'hole_result_id': holeResultId,
      if (shotNumber != null) 'shot_number': shotNumber,
      if (club != null) 'club': club,
      if (distanceYards != null) 'distance_yards': distanceYards,
      if (lie != null) 'lie': lie,
      if (result != null) 'result': result,
    });
  }

  HoleShotsCompanion copyWith({
    Value<int>? id,
    Value<int>? holeResultId,
    Value<int>? shotNumber,
    Value<String?>? club,
    Value<int?>? distanceYards,
    Value<String?>? lie,
    Value<String?>? result,
  }) {
    return HoleShotsCompanion(
      id: id ?? this.id,
      holeResultId: holeResultId ?? this.holeResultId,
      shotNumber: shotNumber ?? this.shotNumber,
      club: club ?? this.club,
      distanceYards: distanceYards ?? this.distanceYards,
      lie: lie ?? this.lie,
      result: result ?? this.result,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (holeResultId.present) {
      map['hole_result_id'] = Variable<int>(holeResultId.value);
    }
    if (shotNumber.present) {
      map['shot_number'] = Variable<int>(shotNumber.value);
    }
    if (club.present) {
      map['club'] = Variable<String>(club.value);
    }
    if (distanceYards.present) {
      map['distance_yards'] = Variable<int>(distanceYards.value);
    }
    if (lie.present) {
      map['lie'] = Variable<String>(lie.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoleShotsCompanion(')
          ..write('id: $id, ')
          ..write('holeResultId: $holeResultId, ')
          ..write('shotNumber: $shotNumber, ')
          ..write('club: $club, ')
          ..write('distanceYards: $distanceYards, ')
          ..write('lie: $lie, ')
          ..write('result: $result')
          ..write(')'))
        .toString();
  }
}

abstract class _$GolfyDatabase extends GeneratedDatabase {
  _$GolfyDatabase(QueryExecutor e) : super(e);
  $GolfyDatabaseManager get managers => $GolfyDatabaseManager(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $CourseSetsTable courseSets = $CourseSetsTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $RoundsTable rounds = $RoundsTable(this);
  late final $HoleResultsTable holeResults = $HoleResultsTable(this);
  late final $CourseHolesTable courseHoles = $CourseHolesTable(this);
  late final $CourseSetYardsTable courseSetYards = $CourseSetYardsTable(this);
  late final $HoleShotsTable holeShots = $HoleShotsTable(this);
  late final Index idxRoundsDate = Index(
    'idx_rounds_date',
    'CREATE INDEX idx_rounds_date ON rounds (date)',
  );
  late final Index idxRoundsCourse = Index(
    'idx_rounds_course',
    'CREATE INDEX idx_rounds_course ON rounds (course_id)',
  );
  late final Index idxRoundsEvent = Index(
    'idx_rounds_event',
    'CREATE INDEX idx_rounds_event ON rounds (event_id)',
  );
  late final Index idxRoundsCourseSet = Index(
    'idx_rounds_course_set',
    'CREATE INDEX idx_rounds_course_set ON rounds (course_set_id)',
  );
  late final Index idxHolesRound = Index(
    'idx_holes_round',
    'CREATE INDEX idx_holes_round ON hole_results (round_id)',
  );
  late final Index idxCourseHolesCourse = Index(
    'idx_course_holes_course',
    'CREATE INDEX idx_course_holes_course ON course_holes (course_id)',
  );
  late final Index idxCourseSetsCourse = Index(
    'idx_course_sets_course',
    'CREATE INDEX idx_course_sets_course ON course_sets (course_id)',
  );
  late final Index idxCourseSetYardsSet = Index(
    'idx_course_set_yards_set',
    'CREATE INDEX idx_course_set_yards_set ON course_set_yards (course_set_id)',
  );
  late final Index idxHoleShotsResult = Index(
    'idx_hole_shots_result',
    'CREATE INDEX idx_hole_shots_result ON hole_shots (hole_result_id)',
  );
  late final CourseDao courseDao = CourseDao(this as GolfyDatabase);
  late final CourseHoleDao courseHoleDao = CourseHoleDao(this as GolfyDatabase);
  late final CourseSetDao courseSetDao = CourseSetDao(this as GolfyDatabase);
  late final RoundDao roundDao = RoundDao(this as GolfyDatabase);
  late final HoleResultDao holeResultDao = HoleResultDao(this as GolfyDatabase);
  late final HoleShotDao holeShotDao = HoleShotDao(this as GolfyDatabase);
  late final DashboardDao dashboardDao = DashboardDao(this as GolfyDatabase);
  late final EventDao eventDao = EventDao(this as GolfyDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    courses,
    courseSets,
    events,
    rounds,
    holeResults,
    courseHoles,
    courseSetYards,
    holeShots,
    idxRoundsDate,
    idxRoundsCourse,
    idxRoundsEvent,
    idxRoundsCourseSet,
    idxHolesRound,
    idxCourseHolesCourse,
    idxCourseSetsCourse,
    idxCourseSetYardsSet,
    idxHoleShotsResult,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'courses',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('course_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'course_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rounds', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rounds', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rounds',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('hole_results', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'courses',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('course_holes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'course_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('course_set_yards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'hole_results',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('hole_shots', kind: UpdateKind.delete)],
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

  static MultiTypedResultKey<$CourseSetsTable, List<CourseSet>>
  _courseSetsRefsTable(_$GolfyDatabase db) => MultiTypedResultKey.fromTable(
    db.courseSets,
    aliasName: $_aliasNameGenerator(db.courses.id, db.courseSets.courseId),
  );

  $$CourseSetsTableProcessedTableManager get courseSetsRefs {
    final manager = $$CourseSetsTableTableManager(
      $_db,
      $_db.courseSets,
    ).filter((f) => f.courseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_courseSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

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

  static MultiTypedResultKey<$CourseHolesTable, List<CourseHole>>
  _courseHolesRefsTable(_$GolfyDatabase db) => MultiTypedResultKey.fromTable(
    db.courseHoles,
    aliasName: $_aliasNameGenerator(db.courses.id, db.courseHoles.courseId),
  );

  $$CourseHolesTableProcessedTableManager get courseHolesRefs {
    final manager = $$CourseHolesTableTableManager(
      $_db,
      $_db.courseHoles,
    ).filter((f) => f.courseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_courseHolesRefsTable($_db));
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

  Expression<bool> courseSetsRefs(
    Expression<bool> Function($$CourseSetsTableFilterComposer f) f,
  ) {
    final $$CourseSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableFilterComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

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

  Expression<bool> courseHolesRefs(
    Expression<bool> Function($$CourseHolesTableFilterComposer f) f,
  ) {
    final $$CourseHolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courseHoles,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseHolesTableFilterComposer(
            $db: $db,
            $table: $db.courseHoles,
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

  Expression<T> courseSetsRefs<T extends Object>(
    Expression<T> Function($$CourseSetsTableAnnotationComposer a) f,
  ) {
    final $$CourseSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

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

  Expression<T> courseHolesRefs<T extends Object>(
    Expression<T> Function($$CourseHolesTableAnnotationComposer a) f,
  ) {
    final $$CourseHolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courseHoles,
      getReferencedColumn: (t) => t.courseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseHolesTableAnnotationComposer(
            $db: $db,
            $table: $db.courseHoles,
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
          PrefetchHooks Function({
            bool courseSetsRefs,
            bool roundsRefs,
            bool courseHolesRefs,
          })
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
          prefetchHooksCallback:
              ({
                courseSetsRefs = false,
                roundsRefs = false,
                courseHolesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (courseSetsRefs) db.courseSets,
                    if (roundsRefs) db.rounds,
                    if (courseHolesRefs) db.courseHoles,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (courseSetsRefs)
                        await $_getPrefetchedData<
                          Course,
                          $CoursesTable,
                          CourseSet
                        >(
                          currentTable: table,
                          referencedTable: $$CoursesTableReferences
                              ._courseSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoursesTableReferences(
                                db,
                                table,
                                p0,
                              ).courseSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (roundsRefs)
                        await $_getPrefetchedData<Course, $CoursesTable, Round>(
                          currentTable: table,
                          referencedTable: $$CoursesTableReferences
                              ._roundsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoursesTableReferences(
                                db,
                                table,
                                p0,
                              ).roundsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (courseHolesRefs)
                        await $_getPrefetchedData<
                          Course,
                          $CoursesTable,
                          CourseHole
                        >(
                          currentTable: table,
                          referencedTable: $$CoursesTableReferences
                              ._courseHolesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoursesTableReferences(
                                db,
                                table,
                                p0,
                              ).courseHolesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courseId == item.id,
                              ),
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
      PrefetchHooks Function({
        bool courseSetsRefs,
        bool roundsRefs,
        bool courseHolesRefs,
      })
    >;
typedef $$CourseSetsTableCreateCompanionBuilder =
    CourseSetsCompanion Function({
      Value<int> id,
      required int courseId,
      required String name,
    });
typedef $$CourseSetsTableUpdateCompanionBuilder =
    CourseSetsCompanion Function({
      Value<int> id,
      Value<int> courseId,
      Value<String> name,
    });

final class $$CourseSetsTableReferences
    extends BaseReferences<_$GolfyDatabase, $CourseSetsTable, CourseSet> {
  $$CourseSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$GolfyDatabase db) => db.courses
      .createAlias($_aliasNameGenerator(db.courseSets.courseId, db.courses.id));

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

  static MultiTypedResultKey<$RoundsTable, List<Round>> _roundsRefsTable(
    _$GolfyDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.rounds,
    aliasName: $_aliasNameGenerator(db.courseSets.id, db.rounds.courseSetId),
  );

  $$RoundsTableProcessedTableManager get roundsRefs {
    final manager = $$RoundsTableTableManager(
      $_db,
      $_db.rounds,
    ).filter((f) => f.courseSetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roundsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CourseSetYardsTable, List<CourseSetYard>>
  _courseSetYardsRefsTable(_$GolfyDatabase db) => MultiTypedResultKey.fromTable(
    db.courseSetYards,
    aliasName: $_aliasNameGenerator(
      db.courseSets.id,
      db.courseSetYards.courseSetId,
    ),
  );

  $$CourseSetYardsTableProcessedTableManager get courseSetYardsRefs {
    final manager = $$CourseSetYardsTableTableManager(
      $_db,
      $_db.courseSetYards,
    ).filter((f) => f.courseSetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_courseSetYardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CourseSetsTableFilterComposer
    extends Composer<_$GolfyDatabase, $CourseSetsTable> {
  $$CourseSetsTableFilterComposer({
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

  Expression<bool> roundsRefs(
    Expression<bool> Function($$RoundsTableFilterComposer f) f,
  ) {
    final $$RoundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.courseSetId,
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

  Expression<bool> courseSetYardsRefs(
    Expression<bool> Function($$CourseSetYardsTableFilterComposer f) f,
  ) {
    final $$CourseSetYardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courseSetYards,
      getReferencedColumn: (t) => t.courseSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetYardsTableFilterComposer(
            $db: $db,
            $table: $db.courseSetYards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CourseSetsTableOrderingComposer
    extends Composer<_$GolfyDatabase, $CourseSetsTable> {
  $$CourseSetsTableOrderingComposer({
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

class $$CourseSetsTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $CourseSetsTable> {
  $$CourseSetsTableAnnotationComposer({
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

  Expression<T> roundsRefs<T extends Object>(
    Expression<T> Function($$RoundsTableAnnotationComposer a) f,
  ) {
    final $$RoundsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.courseSetId,
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

  Expression<T> courseSetYardsRefs<T extends Object>(
    Expression<T> Function($$CourseSetYardsTableAnnotationComposer a) f,
  ) {
    final $$CourseSetYardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.courseSetYards,
      getReferencedColumn: (t) => t.courseSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetYardsTableAnnotationComposer(
            $db: $db,
            $table: $db.courseSetYards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CourseSetsTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $CourseSetsTable,
          CourseSet,
          $$CourseSetsTableFilterComposer,
          $$CourseSetsTableOrderingComposer,
          $$CourseSetsTableAnnotationComposer,
          $$CourseSetsTableCreateCompanionBuilder,
          $$CourseSetsTableUpdateCompanionBuilder,
          (CourseSet, $$CourseSetsTableReferences),
          CourseSet,
          PrefetchHooks Function({
            bool courseId,
            bool roundsRefs,
            bool courseSetYardsRefs,
          })
        > {
  $$CourseSetsTableTableManager(_$GolfyDatabase db, $CourseSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourseSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourseSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourseSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> courseId = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => CourseSetsCompanion(id: id, courseId: courseId, name: name),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int courseId,
                required String name,
              }) => CourseSetsCompanion.insert(
                id: id,
                courseId: courseId,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CourseSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                courseId = false,
                roundsRefs = false,
                courseSetYardsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (roundsRefs) db.rounds,
                    if (courseSetYardsRefs) db.courseSetYards,
                  ],
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
                                    referencedTable: $$CourseSetsTableReferences
                                        ._courseIdTable(db),
                                    referencedColumn:
                                        $$CourseSetsTableReferences
                                            ._courseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (roundsRefs)
                        await $_getPrefetchedData<
                          CourseSet,
                          $CourseSetsTable,
                          Round
                        >(
                          currentTable: table,
                          referencedTable: $$CourseSetsTableReferences
                              ._roundsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourseSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).roundsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courseSetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (courseSetYardsRefs)
                        await $_getPrefetchedData<
                          CourseSet,
                          $CourseSetsTable,
                          CourseSetYard
                        >(
                          currentTable: table,
                          referencedTable: $$CourseSetsTableReferences
                              ._courseSetYardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CourseSetsTableReferences(
                                db,
                                table,
                                p0,
                              ).courseSetYardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.courseSetId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CourseSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $CourseSetsTable,
      CourseSet,
      $$CourseSetsTableFilterComposer,
      $$CourseSetsTableOrderingComposer,
      $$CourseSetsTableAnnotationComposer,
      $$CourseSetsTableCreateCompanionBuilder,
      $$CourseSetsTableUpdateCompanionBuilder,
      (CourseSet, $$CourseSetsTableReferences),
      CourseSet,
      PrefetchHooks Function({
        bool courseId,
        bool roundsRefs,
        bool courseSetYardsRefs,
      })
    >;
typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> season,
      Value<int?> finishPosition,
      Value<bool> tied,
      Value<bool> missedCut,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> season,
      Value<int?> finishPosition,
      Value<bool> tied,
      Value<bool> missedCut,
    });

final class $$EventsTableReferences
    extends BaseReferences<_$GolfyDatabase, $EventsTable, Event> {
  $$EventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoundsTable, List<Round>> _roundsRefsTable(
    _$GolfyDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.rounds,
    aliasName: $_aliasNameGenerator(db.events.id, db.rounds.eventId),
  );

  $$RoundsTableProcessedTableManager get roundsRefs {
    final manager = $$RoundsTableTableManager(
      $_db,
      $_db.rounds,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roundsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventsTableFilterComposer
    extends Composer<_$GolfyDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
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

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finishPosition => $composableBuilder(
    column: $table.finishPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tied => $composableBuilder(
    column: $table.tied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missedCut => $composableBuilder(
    column: $table.missedCut,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> roundsRefs(
    Expression<bool> Function($$RoundsTableFilterComposer f) f,
  ) {
    final $$RoundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.eventId,
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

class $$EventsTableOrderingComposer
    extends Composer<_$GolfyDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
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

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishPosition => $composableBuilder(
    column: $table.finishPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tied => $composableBuilder(
    column: $table.tied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missedCut => $composableBuilder(
    column: $table.missedCut,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
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

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get finishPosition => $composableBuilder(
    column: $table.finishPosition,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tied =>
      $composableBuilder(column: $table.tied, builder: (column) => column);

  GeneratedColumn<bool> get missedCut =>
      $composableBuilder(column: $table.missedCut, builder: (column) => column);

  Expression<T> roundsRefs<T extends Object>(
    Expression<T> Function($$RoundsTableAnnotationComposer a) f,
  ) {
    final $$RoundsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.eventId,
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

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, $$EventsTableReferences),
          Event,
          PrefetchHooks Function({bool roundsRefs})
        > {
  $$EventsTableTableManager(_$GolfyDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> season = const Value.absent(),
                Value<int?> finishPosition = const Value.absent(),
                Value<bool> tied = const Value.absent(),
                Value<bool> missedCut = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                name: name,
                season: season,
                finishPosition: finishPosition,
                tied: tied,
                missedCut: missedCut,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> season = const Value.absent(),
                Value<int?> finishPosition = const Value.absent(),
                Value<bool> tied = const Value.absent(),
                Value<bool> missedCut = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                name: name,
                season: season,
                finishPosition: finishPosition,
                tied: tied,
                missedCut: missedCut,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$EventsTableReferences(db, table, e)),
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
                    await $_getPrefetchedData<Event, $EventsTable, Round>(
                      currentTable: table,
                      referencedTable: $$EventsTableReferences._roundsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$EventsTableReferences(db, table, p0).roundsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, $$EventsTableReferences),
      Event,
      PrefetchHooks Function({bool roundsRefs})
    >;
typedef $$RoundsTableCreateCompanionBuilder =
    RoundsCompanion Function({
      Value<int> id,
      required String date,
      required int courseId,
      Value<int> roundNumber,
      Value<String?> teeSet,
      Value<int?> courseSetId,
      Value<String?> weather,
      Value<int?> windSpeedMph,
      Value<String?> difficulty,
      Value<String?> notes,
      Value<String?> migrationCanary,
      Value<int?> eventId,
    });
typedef $$RoundsTableUpdateCompanionBuilder =
    RoundsCompanion Function({
      Value<int> id,
      Value<String> date,
      Value<int> courseId,
      Value<int> roundNumber,
      Value<String?> teeSet,
      Value<int?> courseSetId,
      Value<String?> weather,
      Value<int?> windSpeedMph,
      Value<String?> difficulty,
      Value<String?> notes,
      Value<String?> migrationCanary,
      Value<int?> eventId,
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

  static $CourseSetsTable _courseSetIdTable(_$GolfyDatabase db) =>
      db.courseSets.createAlias(
        $_aliasNameGenerator(db.rounds.courseSetId, db.courseSets.id),
      );

  $$CourseSetsTableProcessedTableManager? get courseSetId {
    final $_column = $_itemColumn<int>('course_set_id');
    if ($_column == null) return null;
    final manager = $$CourseSetsTableTableManager(
      $_db,
      $_db.courseSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseSetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EventsTable _eventIdTable(_$GolfyDatabase db) => db.events
      .createAlias($_aliasNameGenerator(db.rounds.eventId, db.events.id));

  $$EventsTableProcessedTableManager? get eventId {
    final $_column = $_itemColumn<int>('event_id');
    if ($_column == null) return null;
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
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

  ColumnFilters<String> get migrationCanary => $composableBuilder(
    column: $table.migrationCanary,
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

  $$CourseSetsTableFilterComposer get courseSetId {
    final $$CourseSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseSetId,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableFilterComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EventsTableFilterComposer get eventId {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
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

  ColumnOrderings<String> get migrationCanary => $composableBuilder(
    column: $table.migrationCanary,
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

  $$CourseSetsTableOrderingComposer get courseSetId {
    final $$CourseSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseSetId,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableOrderingComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EventsTableOrderingComposer get eventId {
    final $$EventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableOrderingComposer(
            $db: $db,
            $table: $db.events,
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

  GeneratedColumn<String> get migrationCanary => $composableBuilder(
    column: $table.migrationCanary,
    builder: (column) => column,
  );

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

  $$CourseSetsTableAnnotationComposer get courseSetId {
    final $$CourseSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseSetId,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EventsTableAnnotationComposer get eventId {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
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
          PrefetchHooks Function({
            bool courseId,
            bool courseSetId,
            bool eventId,
            bool holeResultsRefs,
          })
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
                Value<int?> courseSetId = const Value.absent(),
                Value<String?> weather = const Value.absent(),
                Value<int?> windSpeedMph = const Value.absent(),
                Value<String?> difficulty = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> migrationCanary = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
              }) => RoundsCompanion(
                id: id,
                date: date,
                courseId: courseId,
                roundNumber: roundNumber,
                teeSet: teeSet,
                courseSetId: courseSetId,
                weather: weather,
                windSpeedMph: windSpeedMph,
                difficulty: difficulty,
                notes: notes,
                migrationCanary: migrationCanary,
                eventId: eventId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                required int courseId,
                Value<int> roundNumber = const Value.absent(),
                Value<String?> teeSet = const Value.absent(),
                Value<int?> courseSetId = const Value.absent(),
                Value<String?> weather = const Value.absent(),
                Value<int?> windSpeedMph = const Value.absent(),
                Value<String?> difficulty = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> migrationCanary = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
              }) => RoundsCompanion.insert(
                id: id,
                date: date,
                courseId: courseId,
                roundNumber: roundNumber,
                teeSet: teeSet,
                courseSetId: courseSetId,
                weather: weather,
                windSpeedMph: windSpeedMph,
                difficulty: difficulty,
                notes: notes,
                migrationCanary: migrationCanary,
                eventId: eventId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RoundsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                courseId = false,
                courseSetId = false,
                eventId = false,
                holeResultsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (holeResultsRefs) db.holeResults,
                  ],
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
                        if (courseSetId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.courseSetId,
                                    referencedTable: $$RoundsTableReferences
                                        ._courseSetIdTable(db),
                                    referencedColumn: $$RoundsTableReferences
                                        ._courseSetIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (eventId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.eventId,
                                    referencedTable: $$RoundsTableReferences
                                        ._eventIdTable(db),
                                    referencedColumn: $$RoundsTableReferences
                                        ._eventIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (holeResultsRefs)
                        await $_getPrefetchedData<
                          Round,
                          $RoundsTable,
                          HoleResult
                        >(
                          currentTable: table,
                          referencedTable: $$RoundsTableReferences
                              ._holeResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RoundsTableReferences(
                                db,
                                table,
                                p0,
                              ).holeResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roundId == item.id,
                              ),
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
      PrefetchHooks Function({
        bool courseId,
        bool courseSetId,
        bool eventId,
        bool holeResultsRefs,
      })
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

  static MultiTypedResultKey<$HoleShotsTable, List<HoleShot>>
  _holeShotsRefsTable(_$GolfyDatabase db) => MultiTypedResultKey.fromTable(
    db.holeShots,
    aliasName: $_aliasNameGenerator(
      db.holeResults.id,
      db.holeShots.holeResultId,
    ),
  );

  $$HoleShotsTableProcessedTableManager get holeShotsRefs {
    final manager = $$HoleShotsTableTableManager(
      $_db,
      $_db.holeShots,
    ).filter((f) => f.holeResultId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_holeShotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  Expression<bool> holeShotsRefs(
    Expression<bool> Function($$HoleShotsTableFilterComposer f) f,
  ) {
    final $$HoleShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.holeShots,
      getReferencedColumn: (t) => t.holeResultId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoleShotsTableFilterComposer(
            $db: $db,
            $table: $db.holeShots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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

  Expression<T> holeShotsRefs<T extends Object>(
    Expression<T> Function($$HoleShotsTableAnnotationComposer a) f,
  ) {
    final $$HoleShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.holeShots,
      getReferencedColumn: (t) => t.holeResultId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoleShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.holeShots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
          PrefetchHooks Function({bool roundId, bool holeShotsRefs})
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
          prefetchHooksCallback: ({roundId = false, holeShotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (holeShotsRefs) db.holeShots],
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
                return [
                  if (holeShotsRefs)
                    await $_getPrefetchedData<
                      HoleResult,
                      $HoleResultsTable,
                      HoleShot
                    >(
                      currentTable: table,
                      referencedTable: $$HoleResultsTableReferences
                          ._holeShotsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$HoleResultsTableReferences(
                            db,
                            table,
                            p0,
                          ).holeShotsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.holeResultId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
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
      PrefetchHooks Function({bool roundId, bool holeShotsRefs})
    >;
typedef $$CourseHolesTableCreateCompanionBuilder =
    CourseHolesCompanion Function({
      Value<int> id,
      required int courseId,
      required int holeNumber,
      required int par,
      Value<int?> strokeIndex,
    });
typedef $$CourseHolesTableUpdateCompanionBuilder =
    CourseHolesCompanion Function({
      Value<int> id,
      Value<int> courseId,
      Value<int> holeNumber,
      Value<int> par,
      Value<int?> strokeIndex,
    });

final class $$CourseHolesTableReferences
    extends BaseReferences<_$GolfyDatabase, $CourseHolesTable, CourseHole> {
  $$CourseHolesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoursesTable _courseIdTable(_$GolfyDatabase db) =>
      db.courses.createAlias(
        $_aliasNameGenerator(db.courseHoles.courseId, db.courses.id),
      );

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
}

class $$CourseHolesTableFilterComposer
    extends Composer<_$GolfyDatabase, $CourseHolesTable> {
  $$CourseHolesTableFilterComposer({
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

  ColumnFilters<int> get strokeIndex => $composableBuilder(
    column: $table.strokeIndex,
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
}

class $$CourseHolesTableOrderingComposer
    extends Composer<_$GolfyDatabase, $CourseHolesTable> {
  $$CourseHolesTableOrderingComposer({
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

  ColumnOrderings<int> get strokeIndex => $composableBuilder(
    column: $table.strokeIndex,
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

class $$CourseHolesTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $CourseHolesTable> {
  $$CourseHolesTableAnnotationComposer({
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

  GeneratedColumn<int> get strokeIndex => $composableBuilder(
    column: $table.strokeIndex,
    builder: (column) => column,
  );

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
}

class $$CourseHolesTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $CourseHolesTable,
          CourseHole,
          $$CourseHolesTableFilterComposer,
          $$CourseHolesTableOrderingComposer,
          $$CourseHolesTableAnnotationComposer,
          $$CourseHolesTableCreateCompanionBuilder,
          $$CourseHolesTableUpdateCompanionBuilder,
          (CourseHole, $$CourseHolesTableReferences),
          CourseHole,
          PrefetchHooks Function({bool courseId})
        > {
  $$CourseHolesTableTableManager(_$GolfyDatabase db, $CourseHolesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourseHolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourseHolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourseHolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> courseId = const Value.absent(),
                Value<int> holeNumber = const Value.absent(),
                Value<int> par = const Value.absent(),
                Value<int?> strokeIndex = const Value.absent(),
              }) => CourseHolesCompanion(
                id: id,
                courseId: courseId,
                holeNumber: holeNumber,
                par: par,
                strokeIndex: strokeIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int courseId,
                required int holeNumber,
                required int par,
                Value<int?> strokeIndex = const Value.absent(),
              }) => CourseHolesCompanion.insert(
                id: id,
                courseId: courseId,
                holeNumber: holeNumber,
                par: par,
                strokeIndex: strokeIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CourseHolesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({courseId = false}) {
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
                    if (courseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.courseId,
                                referencedTable: $$CourseHolesTableReferences
                                    ._courseIdTable(db),
                                referencedColumn: $$CourseHolesTableReferences
                                    ._courseIdTable(db)
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

typedef $$CourseHolesTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $CourseHolesTable,
      CourseHole,
      $$CourseHolesTableFilterComposer,
      $$CourseHolesTableOrderingComposer,
      $$CourseHolesTableAnnotationComposer,
      $$CourseHolesTableCreateCompanionBuilder,
      $$CourseHolesTableUpdateCompanionBuilder,
      (CourseHole, $$CourseHolesTableReferences),
      CourseHole,
      PrefetchHooks Function({bool courseId})
    >;
typedef $$CourseSetYardsTableCreateCompanionBuilder =
    CourseSetYardsCompanion Function({
      Value<int> id,
      required int courseSetId,
      required int holeNumber,
      required int yards,
    });
typedef $$CourseSetYardsTableUpdateCompanionBuilder =
    CourseSetYardsCompanion Function({
      Value<int> id,
      Value<int> courseSetId,
      Value<int> holeNumber,
      Value<int> yards,
    });

final class $$CourseSetYardsTableReferences
    extends
        BaseReferences<_$GolfyDatabase, $CourseSetYardsTable, CourseSetYard> {
  $$CourseSetYardsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CourseSetsTable _courseSetIdTable(_$GolfyDatabase db) =>
      db.courseSets.createAlias(
        $_aliasNameGenerator(db.courseSetYards.courseSetId, db.courseSets.id),
      );

  $$CourseSetsTableProcessedTableManager get courseSetId {
    final $_column = $_itemColumn<int>('course_set_id')!;

    final manager = $$CourseSetsTableTableManager(
      $_db,
      $_db.courseSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_courseSetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CourseSetYardsTableFilterComposer
    extends Composer<_$GolfyDatabase, $CourseSetYardsTable> {
  $$CourseSetYardsTableFilterComposer({
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

  ColumnFilters<int> get yards => $composableBuilder(
    column: $table.yards,
    builder: (column) => ColumnFilters(column),
  );

  $$CourseSetsTableFilterComposer get courseSetId {
    final $$CourseSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseSetId,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableFilterComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CourseSetYardsTableOrderingComposer
    extends Composer<_$GolfyDatabase, $CourseSetYardsTable> {
  $$CourseSetYardsTableOrderingComposer({
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

  ColumnOrderings<int> get yards => $composableBuilder(
    column: $table.yards,
    builder: (column) => ColumnOrderings(column),
  );

  $$CourseSetsTableOrderingComposer get courseSetId {
    final $$CourseSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseSetId,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableOrderingComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CourseSetYardsTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $CourseSetYardsTable> {
  $$CourseSetYardsTableAnnotationComposer({
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

  GeneratedColumn<int> get yards =>
      $composableBuilder(column: $table.yards, builder: (column) => column);

  $$CourseSetsTableAnnotationComposer get courseSetId {
    final $$CourseSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.courseSetId,
      referencedTable: $db.courseSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CourseSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.courseSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CourseSetYardsTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $CourseSetYardsTable,
          CourseSetYard,
          $$CourseSetYardsTableFilterComposer,
          $$CourseSetYardsTableOrderingComposer,
          $$CourseSetYardsTableAnnotationComposer,
          $$CourseSetYardsTableCreateCompanionBuilder,
          $$CourseSetYardsTableUpdateCompanionBuilder,
          (CourseSetYard, $$CourseSetYardsTableReferences),
          CourseSetYard,
          PrefetchHooks Function({bool courseSetId})
        > {
  $$CourseSetYardsTableTableManager(
    _$GolfyDatabase db,
    $CourseSetYardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CourseSetYardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CourseSetYardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CourseSetYardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> courseSetId = const Value.absent(),
                Value<int> holeNumber = const Value.absent(),
                Value<int> yards = const Value.absent(),
              }) => CourseSetYardsCompanion(
                id: id,
                courseSetId: courseSetId,
                holeNumber: holeNumber,
                yards: yards,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int courseSetId,
                required int holeNumber,
                required int yards,
              }) => CourseSetYardsCompanion.insert(
                id: id,
                courseSetId: courseSetId,
                holeNumber: holeNumber,
                yards: yards,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CourseSetYardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({courseSetId = false}) {
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
                    if (courseSetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.courseSetId,
                                referencedTable: $$CourseSetYardsTableReferences
                                    ._courseSetIdTable(db),
                                referencedColumn:
                                    $$CourseSetYardsTableReferences
                                        ._courseSetIdTable(db)
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

typedef $$CourseSetYardsTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $CourseSetYardsTable,
      CourseSetYard,
      $$CourseSetYardsTableFilterComposer,
      $$CourseSetYardsTableOrderingComposer,
      $$CourseSetYardsTableAnnotationComposer,
      $$CourseSetYardsTableCreateCompanionBuilder,
      $$CourseSetYardsTableUpdateCompanionBuilder,
      (CourseSetYard, $$CourseSetYardsTableReferences),
      CourseSetYard,
      PrefetchHooks Function({bool courseSetId})
    >;
typedef $$HoleShotsTableCreateCompanionBuilder =
    HoleShotsCompanion Function({
      Value<int> id,
      required int holeResultId,
      required int shotNumber,
      Value<String?> club,
      Value<int?> distanceYards,
      Value<String?> lie,
      Value<String?> result,
    });
typedef $$HoleShotsTableUpdateCompanionBuilder =
    HoleShotsCompanion Function({
      Value<int> id,
      Value<int> holeResultId,
      Value<int> shotNumber,
      Value<String?> club,
      Value<int?> distanceYards,
      Value<String?> lie,
      Value<String?> result,
    });

final class $$HoleShotsTableReferences
    extends BaseReferences<_$GolfyDatabase, $HoleShotsTable, HoleShot> {
  $$HoleShotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HoleResultsTable _holeResultIdTable(_$GolfyDatabase db) =>
      db.holeResults.createAlias(
        $_aliasNameGenerator(db.holeShots.holeResultId, db.holeResults.id),
      );

  $$HoleResultsTableProcessedTableManager get holeResultId {
    final $_column = $_itemColumn<int>('hole_result_id')!;

    final manager = $$HoleResultsTableTableManager(
      $_db,
      $_db.holeResults,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_holeResultIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HoleShotsTableFilterComposer
    extends Composer<_$GolfyDatabase, $HoleShotsTable> {
  $$HoleShotsTableFilterComposer({
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

  ColumnFilters<int> get shotNumber => $composableBuilder(
    column: $table.shotNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get club => $composableBuilder(
    column: $table.club,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distanceYards => $composableBuilder(
    column: $table.distanceYards,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lie => $composableBuilder(
    column: $table.lie,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  $$HoleResultsTableFilterComposer get holeResultId {
    final $$HoleResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.holeResultId,
      referencedTable: $db.holeResults,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$HoleShotsTableOrderingComposer
    extends Composer<_$GolfyDatabase, $HoleShotsTable> {
  $$HoleShotsTableOrderingComposer({
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

  ColumnOrderings<int> get shotNumber => $composableBuilder(
    column: $table.shotNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get club => $composableBuilder(
    column: $table.club,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distanceYards => $composableBuilder(
    column: $table.distanceYards,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lie => $composableBuilder(
    column: $table.lie,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  $$HoleResultsTableOrderingComposer get holeResultId {
    final $$HoleResultsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.holeResultId,
      referencedTable: $db.holeResults,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HoleResultsTableOrderingComposer(
            $db: $db,
            $table: $db.holeResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HoleShotsTableAnnotationComposer
    extends Composer<_$GolfyDatabase, $HoleShotsTable> {
  $$HoleShotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get shotNumber => $composableBuilder(
    column: $table.shotNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get club =>
      $composableBuilder(column: $table.club, builder: (column) => column);

  GeneratedColumn<int> get distanceYards => $composableBuilder(
    column: $table.distanceYards,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lie =>
      $composableBuilder(column: $table.lie, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  $$HoleResultsTableAnnotationComposer get holeResultId {
    final $$HoleResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.holeResultId,
      referencedTable: $db.holeResults,
      getReferencedColumn: (t) => t.id,
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
    return composer;
  }
}

class $$HoleShotsTableTableManager
    extends
        RootTableManager<
          _$GolfyDatabase,
          $HoleShotsTable,
          HoleShot,
          $$HoleShotsTableFilterComposer,
          $$HoleShotsTableOrderingComposer,
          $$HoleShotsTableAnnotationComposer,
          $$HoleShotsTableCreateCompanionBuilder,
          $$HoleShotsTableUpdateCompanionBuilder,
          (HoleShot, $$HoleShotsTableReferences),
          HoleShot,
          PrefetchHooks Function({bool holeResultId})
        > {
  $$HoleShotsTableTableManager(_$GolfyDatabase db, $HoleShotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoleShotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoleShotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoleShotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> holeResultId = const Value.absent(),
                Value<int> shotNumber = const Value.absent(),
                Value<String?> club = const Value.absent(),
                Value<int?> distanceYards = const Value.absent(),
                Value<String?> lie = const Value.absent(),
                Value<String?> result = const Value.absent(),
              }) => HoleShotsCompanion(
                id: id,
                holeResultId: holeResultId,
                shotNumber: shotNumber,
                club: club,
                distanceYards: distanceYards,
                lie: lie,
                result: result,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int holeResultId,
                required int shotNumber,
                Value<String?> club = const Value.absent(),
                Value<int?> distanceYards = const Value.absent(),
                Value<String?> lie = const Value.absent(),
                Value<String?> result = const Value.absent(),
              }) => HoleShotsCompanion.insert(
                id: id,
                holeResultId: holeResultId,
                shotNumber: shotNumber,
                club: club,
                distanceYards: distanceYards,
                lie: lie,
                result: result,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HoleShotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({holeResultId = false}) {
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
                    if (holeResultId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.holeResultId,
                                referencedTable: $$HoleShotsTableReferences
                                    ._holeResultIdTable(db),
                                referencedColumn: $$HoleShotsTableReferences
                                    ._holeResultIdTable(db)
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

typedef $$HoleShotsTableProcessedTableManager =
    ProcessedTableManager<
      _$GolfyDatabase,
      $HoleShotsTable,
      HoleShot,
      $$HoleShotsTableFilterComposer,
      $$HoleShotsTableOrderingComposer,
      $$HoleShotsTableAnnotationComposer,
      $$HoleShotsTableCreateCompanionBuilder,
      $$HoleShotsTableUpdateCompanionBuilder,
      (HoleShot, $$HoleShotsTableReferences),
      HoleShot,
      PrefetchHooks Function({bool holeResultId})
    >;

class $GolfyDatabaseManager {
  final _$GolfyDatabase _db;
  $GolfyDatabaseManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$CourseSetsTableTableManager get courseSets =>
      $$CourseSetsTableTableManager(_db, _db.courseSets);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$RoundsTableTableManager get rounds =>
      $$RoundsTableTableManager(_db, _db.rounds);
  $$HoleResultsTableTableManager get holeResults =>
      $$HoleResultsTableTableManager(_db, _db.holeResults);
  $$CourseHolesTableTableManager get courseHoles =>
      $$CourseHolesTableTableManager(_db, _db.courseHoles);
  $$CourseSetYardsTableTableManager get courseSetYards =>
      $$CourseSetYardsTableTableManager(_db, _db.courseSetYards);
  $$HoleShotsTableTableManager get holeShots =>
      $$HoleShotsTableTableManager(_db, _db.holeShots);
}
