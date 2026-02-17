import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';

abstract class SummaryRepository {
  // 监听特定类型的总结列表
  Stream<List<Summary>> watchSummaries(SummaryType type);

  // 获取单个总结
  Future<Summary?> getSummaryById(int id);

  // 保存总结
  Future<void> saveSummary({
    int? id,
    required SummaryType type,
    required DateTime startDate,
    required DateTime endDate,
    required String content,
    List<String> sourceIds = const [],
  });

  // 删除总结
  Future<void> deleteSummary(int id);
}
