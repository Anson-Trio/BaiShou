// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DiariesTable extends Diaries with TableInfo<$DiariesTable, Diary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiariesTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    content,
    tags,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Diary> instance, {
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
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Diary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Diary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DiariesTable createAlias(String alias) {
    return $DiariesTable(attachedDatabase, alias);
  }
}

class Diary extends DataClass implements Insertable<Diary> {
  /// 主键 ID (自增)
  final int id;

  /// 日记日期 (建立索引方便查询)
  final DateTime date;

  /// 日记内容 (Markdown格式)
  final String content;

  /// 标签 (以逗号分隔的字符串存储，简单起见)
  final String? tags;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;
  const Diary({
    required this.id,
    required this.date,
    required this.content,
    this.tags,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DiariesCompanion toCompanion(bool nullToAbsent) {
    return DiariesCompanion(
      id: Value(id),
      date: Value(date),
      content: Value(content),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Diary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Diary(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      content: serializer.fromJson<String>(json['content']),
      tags: serializer.fromJson<String?>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'content': serializer.toJson<String>(content),
      'tags': serializer.toJson<String?>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Diary copyWith({
    int? id,
    DateTime? date,
    String? content,
    Value<String?> tags = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Diary(
    id: id ?? this.id,
    date: date ?? this.date,
    content: content ?? this.content,
    tags: tags.present ? tags.value : this.tags,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Diary copyWithCompanion(DiariesCompanion data) {
    return Diary(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      content: data.content.present ? data.content.value : this.content,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Diary(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, content, tags, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Diary &&
          other.id == this.id &&
          other.date == this.date &&
          other.content == this.content &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DiariesCompanion extends UpdateCompanion<Diary> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> content;
  final Value<String?> tags;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DiariesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.content = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DiariesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String content,
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : date = Value(date),
       content = Value(content);
  static Insertable<Diary> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? content,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (content != null) 'content': content,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DiariesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? content,
    Value<String?>? tags,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DiariesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiariesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('content: $content, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SummariesTable extends Summaries
    with TableInfo<$SummariesTable, Summary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SummariesTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<SummaryType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SummaryType>($SummariesTable.$convertertype);
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sourceIdsMeta = const VerificationMeta(
    'sourceIds',
  );
  @override
  late final GeneratedColumn<String> sourceIds = GeneratedColumn<String>(
    'source_ids',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    startDate,
    endDate,
    content,
    generatedAt,
    sourceIds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Summary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    }
    if (data.containsKey('source_ids')) {
      context.handle(
        _sourceIdsMeta,
        sourceIds.isAcceptableOrUnknown(data['source_ids']!, _sourceIdsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {type, startDate, endDate},
  ];
  @override
  Summary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Summary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $SummariesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      )!,
      sourceIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ids'],
      ),
    );
  }

  @override
  $SummariesTable createAlias(String alias) {
    return $SummariesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SummaryType, String, String> $convertertype =
      const EnumNameConverter<SummaryType>(SummaryType.values);
}

class Summary extends DataClass implements Insertable<Summary> {
  /// 主键 ID (自增)
  final int id;

  /// 总结类型 (WEEKLY, MONTHLY, etc.)
  final SummaryType type;

  /// 覆盖的起始日期
  final DateTime startDate;

  /// 覆盖的结束日期
  final DateTime endDate;

  /// 总结内容 (Markdown格式)
  final String content;

  /// 生成时间
  final DateTime generatedAt;

  /// 关联的原始数据ID列表 (JSON存储或逗号分隔，用于溯源)
  /// 在MVP阶段，我们暂时只存储 coverage range，不强制关联每一条ID
  final String? sourceIds;
  const Summary({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.content,
    required this.generatedAt,
    this.sourceIds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>(
        $SummariesTable.$convertertype.toSql(type),
      );
    }
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['content'] = Variable<String>(content);
    map['generated_at'] = Variable<DateTime>(generatedAt);
    if (!nullToAbsent || sourceIds != null) {
      map['source_ids'] = Variable<String>(sourceIds);
    }
    return map;
  }

  SummariesCompanion toCompanion(bool nullToAbsent) {
    return SummariesCompanion(
      id: Value(id),
      type: Value(type),
      startDate: Value(startDate),
      endDate: Value(endDate),
      content: Value(content),
      generatedAt: Value(generatedAt),
      sourceIds: sourceIds == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceIds),
    );
  }

  factory Summary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Summary(
      id: serializer.fromJson<int>(json['id']),
      type: $SummariesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      content: serializer.fromJson<String>(json['content']),
      generatedAt: serializer.fromJson<DateTime>(json['generatedAt']),
      sourceIds: serializer.fromJson<String?>(json['sourceIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $SummariesTable.$convertertype.toJson(type),
      ),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'content': serializer.toJson<String>(content),
      'generatedAt': serializer.toJson<DateTime>(generatedAt),
      'sourceIds': serializer.toJson<String?>(sourceIds),
    };
  }

  Summary copyWith({
    int? id,
    SummaryType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? content,
    DateTime? generatedAt,
    Value<String?> sourceIds = const Value.absent(),
  }) => Summary(
    id: id ?? this.id,
    type: type ?? this.type,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    content: content ?? this.content,
    generatedAt: generatedAt ?? this.generatedAt,
    sourceIds: sourceIds.present ? sourceIds.value : this.sourceIds,
  );
  Summary copyWithCompanion(SummariesCompanion data) {
    return Summary(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      content: data.content.present ? data.content.value : this.content,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      sourceIds: data.sourceIds.present ? data.sourceIds.value : this.sourceIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Summary(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('content: $content, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('sourceIds: $sourceIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    startDate,
    endDate,
    content,
    generatedAt,
    sourceIds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Summary &&
          other.id == this.id &&
          other.type == this.type &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.content == this.content &&
          other.generatedAt == this.generatedAt &&
          other.sourceIds == this.sourceIds);
}

class SummariesCompanion extends UpdateCompanion<Summary> {
  final Value<int> id;
  final Value<SummaryType> type;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<String> content;
  final Value<DateTime> generatedAt;
  final Value<String?> sourceIds;
  const SummariesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.content = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.sourceIds = const Value.absent(),
  });
  SummariesCompanion.insert({
    this.id = const Value.absent(),
    required SummaryType type,
    required DateTime startDate,
    required DateTime endDate,
    required String content,
    this.generatedAt = const Value.absent(),
    this.sourceIds = const Value.absent(),
  }) : type = Value(type),
       startDate = Value(startDate),
       endDate = Value(endDate),
       content = Value(content);
  static Insertable<Summary> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? content,
    Expression<DateTime>? generatedAt,
    Expression<String>? sourceIds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (content != null) 'content': content,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (sourceIds != null) 'source_ids': sourceIds,
    });
  }

  SummariesCompanion copyWith({
    Value<int>? id,
    Value<SummaryType>? type,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<String>? content,
    Value<DateTime>? generatedAt,
    Value<String?>? sourceIds,
  }) {
    return SummariesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      content: content ?? this.content,
      generatedAt: generatedAt ?? this.generatedAt,
      sourceIds: sourceIds ?? this.sourceIds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $SummariesTable.$convertertype.toSql(type.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (sourceIds.present) {
      map['source_ids'] = Variable<String>(sourceIds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SummariesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('content: $content, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('sourceIds: $sourceIds')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DiariesTable diaries = $DiariesTable(this);
  late final $SummariesTable summaries = $SummariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [diaries, summaries];
}

typedef $$DiariesTableCreateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      required DateTime date,
      required String content,
      Value<String?> tags,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$DiariesTableUpdateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> content,
      Value<String?> tags,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DiariesTableFilterComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableFilterComposer({
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

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiariesTable,
          Diary,
          $$DiariesTableFilterComposer,
          $$DiariesTableOrderingComposer,
          $$DiariesTableAnnotationComposer,
          $$DiariesTableCreateCompanionBuilder,
          $$DiariesTableUpdateCompanionBuilder,
          (Diary, BaseReferences<_$AppDatabase, $DiariesTable, Diary>),
          Diary,
          PrefetchHooks Function()
        > {
  $$DiariesTableTableManager(_$AppDatabase db, $DiariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DiariesCompanion(
                id: id,
                date: date,
                content: content,
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String content,
                Value<String?> tags = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DiariesCompanion.insert(
                id: id,
                date: date,
                content: content,
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiariesTable,
      Diary,
      $$DiariesTableFilterComposer,
      $$DiariesTableOrderingComposer,
      $$DiariesTableAnnotationComposer,
      $$DiariesTableCreateCompanionBuilder,
      $$DiariesTableUpdateCompanionBuilder,
      (Diary, BaseReferences<_$AppDatabase, $DiariesTable, Diary>),
      Diary,
      PrefetchHooks Function()
    >;
typedef $$SummariesTableCreateCompanionBuilder =
    SummariesCompanion Function({
      Value<int> id,
      required SummaryType type,
      required DateTime startDate,
      required DateTime endDate,
      required String content,
      Value<DateTime> generatedAt,
      Value<String?> sourceIds,
    });
typedef $$SummariesTableUpdateCompanionBuilder =
    SummariesCompanion Function({
      Value<int> id,
      Value<SummaryType> type,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<String> content,
      Value<DateTime> generatedAt,
      Value<String?> sourceIds,
    });

class $$SummariesTableFilterComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<SummaryType, SummaryType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceIds => $composableBuilder(
    column: $table.sourceIds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceIds => $composableBuilder(
    column: $table.sourceIds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SummariesTable> {
  $$SummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SummaryType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceIds =>
      $composableBuilder(column: $table.sourceIds, builder: (column) => column);
}

class $$SummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SummariesTable,
          Summary,
          $$SummariesTableFilterComposer,
          $$SummariesTableOrderingComposer,
          $$SummariesTableAnnotationComposer,
          $$SummariesTableCreateCompanionBuilder,
          $$SummariesTableUpdateCompanionBuilder,
          (Summary, BaseReferences<_$AppDatabase, $SummariesTable, Summary>),
          Summary,
          PrefetchHooks Function()
        > {
  $$SummariesTableTableManager(_$AppDatabase db, $SummariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<SummaryType> type = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> generatedAt = const Value.absent(),
                Value<String?> sourceIds = const Value.absent(),
              }) => SummariesCompanion(
                id: id,
                type: type,
                startDate: startDate,
                endDate: endDate,
                content: content,
                generatedAt: generatedAt,
                sourceIds: sourceIds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required SummaryType type,
                required DateTime startDate,
                required DateTime endDate,
                required String content,
                Value<DateTime> generatedAt = const Value.absent(),
                Value<String?> sourceIds = const Value.absent(),
              }) => SummariesCompanion.insert(
                id: id,
                type: type,
                startDate: startDate,
                endDate: endDate,
                content: content,
                generatedAt: generatedAt,
                sourceIds: sourceIds,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SummariesTable,
      Summary,
      $$SummariesTableFilterComposer,
      $$SummariesTableOrderingComposer,
      $$SummariesTableAnnotationComposer,
      $$SummariesTableCreateCompanionBuilder,
      $$SummariesTableUpdateCompanionBuilder,
      (Summary, BaseReferences<_$AppDatabase, $SummariesTable, Summary>),
      Summary,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DiariesTableTableManager get diaries =>
      $$DiariesTableTableManager(_db, _db.diaries);
  $$SummariesTableTableManager get summaries =>
      $$SummariesTableTableManager(_db, _db.summaries);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 提供数据库实例

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// 提供数据库实例

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// 提供数据库实例
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'8c69eb46d45206533c176c88a926608e79ca927d';
