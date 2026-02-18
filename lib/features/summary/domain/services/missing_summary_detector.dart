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
  /// 严格限制：只能生成已经完全结束的周。
  Future<List<MissingSummary>> getMissingWeekly() async {
    // 1. 获取所有日记日期
    final allDiaries = await _diaryRepo.getAllDiaries();
    if (allDiaries.isEmpty) return [];

    final dates = allDiaries.map((d) => d.date).toList()..sort();
    final firstDate = dates.first;

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
    // 只有当这一周的结束时间早于现在时，才认为这周是"历史"的
    // 周一 00:00 -> 下周一 00:00 (不含) 或者 周日 23:59:59

    while (true) {
      final currentEnd = currentStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      // 停止条件：如果这一周还没有结束（结束时间在未来），则停止
      if (currentEnd.isAfter(now)) {
        break;
      }

      // 这周已经结束了。检查是否有日记。
      bool hasEntry = dates.any(
        (d) =>
            d.isAfter(currentStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(currentEnd.add(const Duration(seconds: 1))),
      );

      if (hasEntry) {
        weeks.add(DateTimeRange(start: currentStart, end: currentEnd));
      }

      currentStart = currentStart.add(const Duration(days: 7));

      // 安全出口：防止死循环（虽然上面的 break 应该够了）
      if (currentStart.year > now.year + 1) break;
    }

    // 3. 检查现有总结
    final missing = <MissingSummary>[];
    for (final week in weeks) {
      final existing = await _summaryRepo.getSummaryByTypeAndDate(
        SummaryType.weekly,
        week.start,
        week.end,
      );

      if (existing == null) {
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
  /// 严格限制：只能生成已经完全结束的月份。
  Future<List<MissingSummary>> getMissingMonthly() async {
    // 1. 获取所有周记
    final weeklySummaries = await _summaryRepo.getSummaries();
    final weeklies = weeklySummaries
        .where((s) => s.type == SummaryType.weekly)
        .toList();

    if (weeklies.isEmpty) return [];

    // 2. 识别周记覆盖的月份
    final months = <DateTime>[]; // 每月1号
    for (final w in weeklies) {
      final m = DateTime(w.startDate.year, w.startDate.month, 1);
      if (!months.contains(m)) months.add(m);
    }

    final now = DateTime.now();

    // 3. 检查状态
    final missing = <MissingSummary>[];
    for (final m in months) {
      // 月末
      final nextMonth = DateTime(m.year, m.month + 1, 1);
      final monthEnd = nextMonth.subtract(const Duration(seconds: 1));

      // 只有当这个月完全过完（月末时间早于现在）才允许生成
      if (monthEnd.isAfter(now)) {
        continue;
      }

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
  /// 严格限制：只能生成已经完全结束的季度。
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

    final now = DateTime.now();
    final missing = <MissingSummary>[];

    for (final qKey in quarters) {
      final parts = qKey.split('-');
      final year = int.parse(parts[0]);
      final quarter = int.parse(parts[1]);

      final startMonth = (quarter - 1) * 3 + 1;
      final qStart = DateTime(year, startMonth, 1);
      final qEndMonth = startMonth + 2;
      final qEnd = DateTime(year, qEndMonth + 1, 0, 23, 59, 59);

      // 只有当这个季度完全过完（季度末时间早于现在）才允许生成
      if (qEnd.isAfter(now)) {
        continue;
      }

      // 检查我们是否有该季度的月报（这里放宽一点，只要本季度有月报且季度已过完，就提示生成）
      // 或者保持严格：必须有至少一个月报？上面的逻辑是基于 monthlies 存在的季度。
      // 所以只要有月报落在这个季度，并且季度已结束，就检查是否有季报。

      final candidates = await _summaryRepo.getSummaries(
        start: qStart,
        end: qEnd,
      );
      final hasQuarterly = candidates.any(
        (s) => s.type == SummaryType.quarterly && s.startDate.year == year,
      );

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
    return missing;
  }

  /// 检测缺失的年鉴
  /// 严格限制：只能生成已经完全结束的年份。
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

    final now = DateTime.now();
    final missing = <MissingSummary>[];

    for (final year in years) {
      final yearStart = DateTime(year, 1, 1);
      final yearEnd = DateTime(year, 12, 31, 23, 59, 59);

      // 只有当这一年完全过完（年末时间早于现在）才允许生成
      if (yearEnd.isAfter(now)) {
        continue;
      }

      // 检查年鉴
      final existing = await _summaryRepo.getSummaries(
        start: yearStart,
        end: yearEnd,
      );
      final hasYearly = existing.any((s) => s.type == SummaryType.yearly);

      if (!hasYearly) {
        missing.add(
          MissingSummary(
            type: SummaryType.yearly,
            startDate: yearStart,
            endDate: yearEnd,
            label: '$year年度',
          ),
        );
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
