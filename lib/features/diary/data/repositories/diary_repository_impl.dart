import 'package:baishou/core/database/app_database.dart' as db;
import 'package:baishou/features/diary/data/initial_data.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_repository_impl.g.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  final db.AppDatabase _db;

  DiaryRepositoryImpl(this._db);

  @override
  Stream<List<Diary>> watchAllDiaries() {
    return (_db.select(_db.diaries)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch()
        .map((rows) => rows.map(_mapToEntity).toList());
  }

  /// 手动加载演示数据（仅通过调试页面触发）
  /// [force] 为 true 时强制写入，不检查是否已有数据
  Future<void> ensureInitialData({bool force = false}) async {
    try {
      if (!force) {
        final existingCount = await (_db.select(
          _db.diaries,
        )).get().then((v) => v.length);
        if (existingCount > 0) return;
      }

      debugPrint('DiaryRepository: Seeding initial data...');
      for (final diary in initialDiaries) {
        final companion = db.DiariesCompanion(
          date: Value(DateTime.parse(diary['date'] as String)),
          content: Value(diary['content'] as String),
          tags: Value((diary['tags'] as List).join(',')),
          updatedAt: Value(DateTime.now()),
        );
        await _db.into(_db.diaries).insert(companion);
      }
      debugPrint('DiaryRepository: Seeding completed.');
    } catch (e) {
      debugPrint('DiaryRepository: Failed to seed initial data. Error: $e');
      rethrow;
    }
  }

  @override
  Future<Diary?> getDiaryById(int id) async {
    final query = _db.select(_db.diaries)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _mapToEntity(row) : null;
  }

  @override
  Future<void> saveDiary({
    int? id,
    required DateTime date,
    required String content,
    List<String> tags = const [],
  }) async {
    final companion = db.DiariesCompanion(
      date: Value(date),
      content: Value(content),
      tags: Value(tags.join(',')),
      updatedAt: Value(DateTime.now()),
    );

    try {
      if (id != null) {
        // 更新现有
        await (_db.update(
          _db.diaries,
        )..where((t) => t.id.equals(id))).write(companion);
      } else {
        // 创建新
        await _db.into(_db.diaries).insert(companion);
      }
    } catch (e) {
      debugPrint('DiaryRepository: Failed to save diary. Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> batchSaveDiaries(List<Diary> diaries) async {
    await _db.batch((batch) {
      for (final diary in diaries) {
        final companion = db.DiariesCompanion(
          date: Value(diary.date),
          content: Value(diary.content),
          tags: Value(diary.tags.join(',')),
          updatedAt: Value(DateTime.now()),
        );
        batch.insert(_db.diaries, companion);
      }
    });
  }

  @override
  Future<void> deleteDiary(int id) {
    return (_db.delete(_db.diaries)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteAllDiaries() {
    return _db.delete(_db.diaries).go();
  }

  @override
  Future<List<Diary>> getDiariesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final query = _db.select(_db.diaries)
      ..where(
        (t) =>
            t.date.isBiggerOrEqualValue(start) &
            t.date.isSmallerOrEqualValue(end),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc),
      ]);

    final rows = await query.get();
    return rows.map(_mapToEntity).toList();
  }

  // 将数据库行转换为领域实体
  Diary _mapToEntity(db.Diary row) {
    return Diary(
      id: row.id,
      date: row.date,
      content: row.content,
      tags:
          row.tags
              ?.split(',')
              .where((s) => s.trim().isNotEmpty)
              .map((s) => s.trim())
              .toList() ??
          [],
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<List<Diary>> getAllDiaries() async {
    final query = _db.select(_db.diaries)
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc),
      ]);
    final rows = await query.get();
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<List<Diary>> getDiariesInRange(DateTime start, DateTime end) {
    return getDiariesByDateRange(start, end);
  }

  @override
  Future<DateTime?> getOldestDiaryDate() async {
    final query = _db.selectOnly(_db.diaries)
      ..addColumns([_db.diaries.date.min()]);
    final row = await query.getSingle();
    return row.read(_db.diaries.date.min());
  }
}

@Riverpod(keepAlive: true)
DiaryRepository diaryRepository(Ref ref) {
  final dbInstance = ref.watch(db.appDatabaseProvider);
  return DiaryRepositoryImpl(dbInstance);
}
