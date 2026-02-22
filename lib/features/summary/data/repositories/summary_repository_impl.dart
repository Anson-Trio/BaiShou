import 'package:baishou/core/database/app_database.dart' as db;
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'summary_repository_impl.g.dart';

class SummaryRepositoryImpl implements SummaryRepository {
  final db.AppDatabase _db;

  SummaryRepositoryImpl(this._db);

  @override
  Stream<List<Summary>> watchSummaries(
    SummaryType type, {
    DateTime? start,
    DateTime? end,
  }) {
    final query = _db.select(_db.summaries)
      ..where((t) => t.type.equals(type.name));

    if (start != null) {
      // 筛选 startDate >= start
      query.where((t) => t.startDate.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      // 筛选 startDate <= end
      query.where((t) => t.startDate.isSmallerOrEqualValue(end));
    }

    return (query..orderBy([
          (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
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
  Future<List<Summary>> getSummaries({DateTime? start, DateTime? end}) async {
    final query = _db.select(_db.summaries);
    if (start != null) {
      query.where((t) => t.startDate.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where((t) => t.endDate.isSmallerOrEqualValue(end));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
    ]);

    final rows = await query.get();
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<Summary?> getSummaryByTypeAndDate(
    SummaryType type,
    DateTime start,
    DateTime end,
  ) async {
    final query = _db.select(_db.summaries)
      ..where((t) => t.type.equalsValue(type))
      ..where((t) => t.startDate.equals(start))
      ..where((t) => t.endDate.equals(end));

    final row = await query.getSingleOrNull();
    return row != null ? _mapToEntity(row) : null;
  }

  @override
  Future<int> addSummary({
    required SummaryType type,
    required DateTime startDate,
    required DateTime endDate,
    required String content,
    List<String> sourceIds = const [],
  }) {
    return _db
        .into(_db.summaries)
        .insert(
          db.SummariesCompanion(
            type: Value(type),
            startDate: Value(startDate),
            endDate: Value(endDate),
            content: Value(content),
            sourceIds: Value(sourceIds.join(',')),
            generatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> batchAddSummaries(List<Summary> summaries) async {
    await _db.batch((batch) {
      for (final summary in summaries) {
        batch.insert(
          _db.summaries,
          db.SummariesCompanion(
            type: Value(summary.type),
            startDate: Value(summary.startDate),
            endDate: Value(summary.endDate),
            content: Value(summary.content),
            sourceIds: Value(summary.sourceIds.join(',')),
            generatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  @override
  Future<void> updateSummary(Summary summary) {
    return (_db.update(
      _db.summaries,
    )..where((t) => t.id.equals(summary.id))).write(
      db.SummariesCompanion(
        content: Value(summary.content),
        // 其他字段通常不会更新
      ),
    );
  }

  @override
  Future<void> deleteSummary(int id) {
    return (_db.delete(_db.summaries)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteAllSummaries() {
    return _db.delete(_db.summaries).go();
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
