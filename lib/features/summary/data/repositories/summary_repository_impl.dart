import 'package:baishou/core/database/app_database.dart' as db;
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Summary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'summary_repository_impl.g.dart';

class SummaryRepositoryImpl implements SummaryRepository {
  final db.AppDatabase _db;

  SummaryRepositoryImpl(this._db);

  @override
  Stream<List<Summary>> watchSummaries(SummaryType type) {
    return (_db.select(_db.summaries)
          ..where((t) => t.type.equals(type.name))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Future<Summary?> getSummaryById(int id) async {
    final query = _db.select(_db.summaries)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _mapToEntity(row) : null;
  }

  @override
  Future<void> saveSummary({
    int? id,
    required SummaryType type,
    required DateTime startDate,
    required DateTime endDate,
    required String content,
    List<String> sourceIds = const [],
  }) async {
    final companion = db.SummariesCompanion(
      type: Value(type),
      startDate: Value(startDate),
      endDate: Value(endDate),
      content: Value(content),
      sourceIds: Value(sourceIds.join(',')),
      generatedAt: Value(DateTime.now()),
    );

    try {
      if (id != null) {
        await (_db.update(
          _db.summaries,
        )..where((t) => t.id.equals(id))).write(companion);
      } else {
        await _db.into(_db.summaries).insert(companion);
      }
    } catch (e) {
      debugPrint('SummaryRepository: Failed to save summary. Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteSummary(int id) {
    return (_db.delete(_db.summaries)..where((t) => t.id.equals(id))).go();
  }

  Summary _mapToEntity(db.Summary row) {
    return Summary(
      id: row.id,
      type: row.type,
      startDate: row.startDate,
      endDate: row.endDate,
      content: row.content,
      generatedAt: row.generatedAt,
      sourceIds:
          row.sourceIds
              ?.split(',')
              .where((s) => s.trim().isNotEmpty)
              .toList() ??
          [],
    );
  }
}

@Riverpod(keepAlive: true)
SummaryRepository summaryRepository(Ref ref) {
  final dbInstance = ref.watch(db.appDatabaseProvider);
  return SummaryRepositoryImpl(dbInstance);
}
