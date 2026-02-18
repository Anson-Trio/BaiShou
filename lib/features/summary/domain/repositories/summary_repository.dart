import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';

abstract class SummaryRepository {
  // 监听特定类型的总结列表 (可选日期筛选)
  Stream<List<Summary>> watchSummaries(
    SummaryType type, {
    DateTime? start,
    DateTime? end,
  });

  // 获取单个总结
  Future<Summary?> getSummaryById(int id);

  // 保存总结
  // 获取所有总结 (可按时间范围筛选)
  Future<List<Summary>> getSummaries({DateTime? start, DateTime? end});

  // 获取单个总结 (按类型和日期范围，用于查重)
  Future<Summary?> getSummaryByTypeAndDate(
    SummaryType type,
    DateTime start,
    DateTime end,
  );

  // 添加总结
  Future<int> addSummary({
    required SummaryType type,
    required DateTime startDate,
    required DateTime endDate,
    required String content,
    List<String> sourceIds = const [],
  });

  // 更新总结内容
  Future<void> updateSummary(Summary summary);

  // 删除总结
  Future<void> deleteSummary(int id);
}
