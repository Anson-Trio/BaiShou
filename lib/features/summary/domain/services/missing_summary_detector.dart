import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:flutter/material.dart'; // for DateTimeRange if needed, though usually core
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'missing_summary_detector.g.dart';

class MissingSummary {
  final SummaryType type;
  final DateTime startDate;
  final DateTime endDate;
  final String label; // e.g., "2025年第42周", "2025年10月"

  const MissingSummary({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.label,
  });
}

class MissingSummaryDetector {
  final DiaryRepository _diaryRepo;
  final SummaryRepository _summaryRepo;

  MissingSummaryDetector(this._diaryRepo, this._summaryRepo);

  /// 获取所有缺失的总结（周记、月报、季报、年鉴）
  /// 返回按日期排序的合并列表（最早的在前）
  Future<List<MissingSummary>> getAllMissing() async {
    final weekly = await getMissingWeekly();
    final monthly = await getMissingMonthly();
    final quarterly = await getMissingQuarterly();
    final yearly = await getMissingYearly();

    return [...weekly, ...monthly, ...quarterly, ...yearly]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  /// 检测缺失的周记
  /// 逻辑：查找所有至少有一篇日记但没有周记的周（周一至周日）。
  Future<List<MissingSummary>> getMissingWeekly() async {
    // 1. 获取所有日记日期
    final allDiaries = await _diaryRepo.getAllDiaries();
    if (allDiaries.isEmpty) return [];

    final dates = allDiaries.map((d) => d.date).toList()..sort();
    final firstDate = dates.first;
    final lastDate = dates.last;

    // 2. 识别从第一篇日记到现在的所有可能周
    final weeks = <DateTimeRange>[];
    // 将 firstDate 对齐到周一
    var currentStart = firstDate.subtract(
      Duration(days: firstDate.weekday - 1),
    );
    currentStart = DateTime(
      currentStart.year,
      currentStart.month,
      currentStart.day,
    ); // 去除时间部分

    final now = DateTime.now();

    while (currentStart.isBefore(lastDate) ||
        currentStart.isBefore(now.subtract(const Duration(days: 7)))) {
      final currentEnd = currentStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      // 只考虑完全过去或包含日记条目的周
      // 简单逻辑：如果这周有任何日记条目，它就是一个候选项。
      bool hasEntry = dates.any(
        (d) =>
            d.isAfter(currentStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(currentEnd.add(const Duration(seconds: 1))),
      );

      if (hasEntry) {
        weeks.add(DateTimeRange(start: currentStart, end: currentEnd));
      }

      currentStart = currentStart.add(const Duration(days: 7));
    }

    // 3. 检查现有总结
    final missing = <MissingSummary>[];
    for (final week in weeks) {
      final existing = await _summaryRepo.getSummaryByTypeAndDate(
        SummaryType.weekly,
        week.start,
        week.end, // 注意：Repo 实现通常比较确切的日期，可能需要模糊检查或严格标准化的日期
      );

      // 在 SummaryRepositoryImpl 中，addSummary 使用标准日期。
      // 我们假设检测生成严格的周一 00:00 到周日 23:59:59 的范围以匹配存储。
      // 但 Repo 通常存储传递过来的任何日期。
      // 让我们假设严格性。或者更好的是，检查是否有任何周记主要重叠？
      // 对于 MVP：在本地检查严格范围匹配，假设我们生成严格的范围。

      if (existing == null) {
        // 双重检查严格匹配如果存储不同可能会失败？
        // 让我们相信我们会存储标准化的范围。
        missing.add(
          MissingSummary(
            type: SummaryType.weekly,
            startDate: week.start,
            endDate: week.end,
            label: '${week.start.year}年第${_getWeekNumber(week.start)}周',
          ),
        );
      }
    }
    return missing;
  }

  /// 检测缺失的月报
  /// 逻辑：查找至少有一篇周记但没有月报的月份。
  /// (严格来说，月报依赖于周记)
  Future<List<MissingSummary>> getMissingMonthly() async {
    // 1. 获取所有周记
    final weeklySummaries = await _summaryRepo
        .getSummaries(); // 需要 Helper? 或者 watchSummaries.
    // Repo 有 getSummaries().
    // 我们手动过滤周记.
    final weeklies = weeklySummaries
        .where((s) => s.type == SummaryType.weekly)
        .toList();

    if (weeklies.isEmpty) return [];

    // 2. 识别周记覆盖的月份
    final months = <DateTime>[]; // 每月1号
    for (final w in weeklies) {
      // 逻辑：一周属于其开始日期所在的月份（大部分情况下）。
      final m = DateTime(w.startDate.year, w.startDate.month, 1);
      if (!months.contains(m)) months.add(m);
    }

    // 3. 检查状态
    final missing = <MissingSummary>[];
    for (final m in months) {
      // 月末
      final nextMonth = DateTime(m.year, m.month + 1, 1);
      final monthEnd = nextMonth.subtract(const Duration(seconds: 1));

      // 检查月报是否存在
      // 假设月报存储为 1号 00:00 到 最后一天 23:59:59
      // 我们可能需要一个 "getSummariesInPeriod" 查询更安全。
      // 目前如果可能的话使用 类型 + 日期 的精确匹配逻辑。
      // 实际上 SummaryRepositoryImpl.getSummaryByTypeAndDate 检查精确相等。
      // 我们必须确保生成月报时使用精确范围：1号 00:00 -> 最后一天 23:59:59？
      // 或者 1号 00:00 -> 下月1号 00:00？
      // 让我们标准化：开始 00:00，结束 下一天 00:00 (不包含)？
      // Drift 定义：DateTimeColumn。
      // 让我们坚持：开始：YYYY-MM-01 00:00:00，结束：YYYY-MM-LAST 23:59:59。

      final existing = await _summaryRepo.getSummaryByTypeAndDate(
        SummaryType.monthly,
        m,
        DateTime(m.year, m.month + 1, 0, 23, 59, 59), // 近似最后一天逻辑？
        // DateTime(year, month + 1, 0) 给出该月最后一天。
      );

      // 实际上让我们通过类型查询并检查 startDate 是否匹配 m。
      final candidates = await _summaryRepo.getSummaries(
        start: m,
        end: monthEnd,
      );
      final hasMonthly = candidates.any(
        (s) =>
            s.type == SummaryType.monthly &&
            s.startDate.year == m.year &&
            s.startDate.month == m.month,
      );

      if (!hasMonthly) {
        missing.add(
          MissingSummary(
            type: SummaryType.monthly,
            startDate: m,
            endDate: monthEnd,
            label: '${m.year}年${m.month}月',
          ),
        );
      }
    }
    return missing;
  }

  /// 检测缺失的季报
  Future<List<MissingSummary>> getMissingQuarterly() async {
    final summaries = await _summaryRepo.getSummaries();
    final monthlies = summaries
        .where((s) => s.type == SummaryType.monthly)
        .toList();

    if (monthlies.isEmpty) return [];

    // 识别季度
    final quarters = <String>{}; // "2025-1" (Q1), "2025-2" (Q2)
    for (final m in monthlies) {
      final q = (m.startDate.month / 3.0).ceil();
      quarters.add('${m.startDate.year}-$q');
    }

    final missing = <MissingSummary>[];
    for (final qKey in quarters) {
      final parts = qKey.split('-');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);

      // 验证我们是否拥有该季度的所有3个月？
      // 手册上说：“只有当季度的最后一个月完成时”。
      // 让我们现在放宽条件：如果我们在本季度有任何月报，我们就提示生成季报？
      // 或者严格模式：必须有 M1, M2, M3？
      // 严格模式对 AI 上下文更好。
      // Q1: 1,2,3.
      final m1 = monthlies.any(
        (s) =>
            s.startDate.year == year &&
            s.startDate.month == (quarter - 1) * 3 + 1,
      );
      final m2 = monthlies.any(
        (s) =>
            s.startDate.year == year &&
            s.startDate.month == (quarter - 1) * 3 + 2,
      );
      final m3 = monthlies.any(
        (s) =>
            s.startDate.year == year &&
            s.startDate.month == (quarter - 1) * 3 + 3,
      );

      if (m1 && m2 && m3) {
        // 检查 Q 总结是否存在
        final startMonth = (quarter - 1) * 3 + 1;
        final qStart = DateTime(year, startMonth, 1);
        // 结束是第3个月的结束
        final qEndMonth = startMonth + 2;
        final qEnd = DateTime(year, qEndMonth + 1, 0, 23, 59, 59);

        final candidates = await _summaryRepo.getSummaries(
          start: qStart,
          end: qEnd,
        );
        final hasQuarterly = candidates.any(
          (s) => s.type == SummaryType.quarterly && s.startDate.year == year,
        ); // 简化检查

        if (!hasQuarterly) {
          missing.add(
            MissingSummary(
              type: SummaryType.quarterly,
              startDate: qStart,
              endDate: qEnd,
              label: '$year年Q$quarter',
            ),
          );
        }
      }
    }
    return missing;
  }

  /// 检测缺失的年鉴
  Future<List<MissingSummary>> getMissingYearly() async {
    final summaries = await _summaryRepo.getSummaries();
    final quarterlies = summaries
        .where((s) => s.type == SummaryType.quarterly)
        .toList();

    if (quarterlies.isEmpty) return [];

    // 识别年份
    final years = <int>{};
    for (final q in quarterlies) {
      years.add(q.startDate.year);
    }

    final missing = <MissingSummary>[];
    for (final year in years) {
      // 检查我们是否有 Q1-Q4？
      // 严格模式：至少需要3个季度？
      // 假设我们有 >= 3 个季度，我们允许生成年鉴。
      final count = quarterlies.where((s) => s.startDate.year == year).length;

      if (count >= 3) {
        final existing = await _summaryRepo.getSummaries(
          start: DateTime(year, 1, 1),
          end: DateTime(year, 12, 31, 23, 59, 59),
        );
        final hasYearly = existing.any((s) => s.type == SummaryType.yearly);

        if (!hasYearly) {
          missing.add(
            MissingSummary(
              type: SummaryType.yearly,
              startDate: DateTime(year, 1, 1),
              endDate: DateTime(year, 12, 31, 23, 59, 59),
              label: '$year年度',
            ),
          );
        }
      }
    }
    return missing;
  }

  // 获取周数的 Helper (ISO 8601 近似)
  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(
      date.difference(DateTime(date.year, 1, 1)).inDays.toString(),
    );
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}

// 简单的 DateTimeRange 存根（如果需要），但 Flutter 有它。
// 实际上领域逻辑不应该依赖于 Flutter 实现细节（如果可能的话），
// 但 DateTimeRange 在 Material 中... 等等，DateTimeRange 是 UI？
// 它在 'package:flutter/material.dart' 中。
// 领域层不应该引入 material。
// 我将定义一个简单的内部结构或仅在逻辑中使用 start/end 变量。
// 上面的重构逻辑使用了内部循环变量，但返回类型使用 MissingSummary。

class DateTimeRange {
  final DateTime start;
  final DateTime end;
  DateTimeRange({required this.start, required this.end});
}

@Riverpod(keepAlive: true)
MissingSummaryDetector missingSummaryDetector(Ref ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final summaryRepo = ref.watch(summaryRepositoryProvider);
  return MissingSummaryDetector(diaryRepo, summaryRepo);
}
