import 'package:baishou/core/database/app_database.dart' as db;
import 'package:baishou/features/diary/data/initial_data.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        .asyncMap((rows) async {
          if (rows.isEmpty) {
            final count = await _db
                .select(_db.diaries)
                .get()
                .then((v) => v.length);
            if (count == 0) {
              await _seedInitialData();
              // After seeding, we don't need to do anything, the stream will emit again
              // because we are watching the table.
              // However, watch() emits immediately, so we might need to handle the first empty emit
              // or let the UI handle it.
              // Here we just return empty list for the first emit, next one will have data.
              return <Diary>[];
            }
          }
          return rows.map(_mapToEntity).toList();
        });
  }

  Future<void> _seedInitialData() async {
    try {
      final existingCount = await (_db.select(
        _db.diaries,
      )).get().then((v) => v.length);
      if (existingCount > 0) return;

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
        // Update existing
        await (_db.update(
          _db.diaries,
        )..where((t) => t.id.equals(id))).write(companion);
      } else {
        // Create new
        await _db.into(_db.diaries).insert(companion);
      }
    } catch (e) {
      debugPrint('DiaryRepository: Failed to save diary. Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDiary(int id) {
    return (_db.delete(_db.diaries)..where((t) => t.id.equals(id))).go();
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
}

@Riverpod(keepAlive: true)
DiaryRepository diaryRepository(Ref ref) {
  final dbInstance = ref.watch(db.appDatabaseProvider);
  return DiaryRepositoryImpl(dbInstance);
}
