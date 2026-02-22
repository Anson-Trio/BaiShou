import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:flutter/foundation.dart' hide Summary;
// 用于 DateTimeRange
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'missing_summary_detector.g.dart';

class MissingSummary {
  final SummaryType type;
  final DateTime startDate;
  final DateTime endDate;
  final String label;

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
  Future<List<MissingSummary>> getAllMissing() async {
    // 1. 一次性获取所有数据
    final allDiaries = await _diaryRepo.getAllDiaries();
    final allSummaries = await _summaryRepo.getSummaries();

    if (allDiaries.isEmpty) return [];

    // 2. 在 Isolate 中处理计算逻辑
    return compute(_detectMissing, _DetectorInput(allDiaries, allSummaries));
  }
}

class _DetectorInput {
  final List<Diary> diaries;
  final List<Summary> summaries;
  _DetectorInput(this.diaries, this.summaries);
}

// Top-level function for isolate
List<MissingSummary> _detectMissing(_DetectorInput input) {
  final diaries = input.diaries;
  final summaries = input.summaries;

  if (diaries.isEmpty) return [];

  // 预处理总结数据，加速查找
  final summaryMap = <String, List<Summary>>{};
  for (final s in summaries) {
    summaryMap.putIfAbsent(s.type.name, () => []).add(s);
  }

  final weekly = _getMissingWeekly(
    diaries,
    summaryMap[SummaryType.weekly.name] ?? [],
  );
  final monthly = _getMissingMonthly(
    summaryMap[SummaryType.weekly.name] ?? [],
    summaryMap[SummaryType.monthly.name] ?? [],
  );
  final quarterly = _getMissingQuarterly(
    summaryMap[SummaryType.monthly.name] ?? [],
    summaryMap[SummaryType.quarterly.name] ?? [],
  );
  final yearly = _getMissingYearly(
    summaryMap[SummaryType.quarterly.name] ?? [],
    summaryMap[SummaryType.yearly.name] ?? [],
  );

  return [...weekly, ...monthly, ...quarterly, ...yearly]
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
}

// --- 独立计算逻辑 ---

List<MissingSummary> _getMissingWeekly(
  List<Diary> diaries,
  List<Summary> existingSummaries,
) {
  final missing = <MissingSummary>[];
  final dates = diaries.map((d) => d.date).toList()..sort();
  final firstDate = dates.first;
  final now = DateTime.now();

  // 将 firstDate 对齐到周一
  var currentStart = firstDate.subtract(Duration(days: firstDate.weekday - 1));
  currentStart = DateTime(
    currentStart.year,
    currentStart.month,
    currentStart.day,
  );

  while (true) {
    final currentEnd = currentStart.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );

    if (currentEnd.isAfter(now)) break;

    // 检查是否有日记
    bool hasEntry = dates.any(
      (d) =>
          d.isAfter(currentStart.subtract(const Duration(seconds: 1))) &&
          d.isBefore(currentEnd.add(const Duration(seconds: 1))),
    );

    if (hasEntry) {
      // 检查是否已有总结
      final hasSummary = existingSummaries.any(
        (s) =>
            s.startDate.year == currentStart.year &&
            s.startDate.month == currentStart.month &&
            s.startDate.day == currentStart.day,
      ); // 简化判断：周记通常由开始日期唯一确定

      if (!hasSummary) {
        missing.add(
          MissingSummary(
            type: SummaryType.weekly,
            startDate: currentStart,
            endDate: currentEnd,
            label: '${currentStart.year}年第${_getWeekNumber(currentStart)}周',
          ),
        );
      }
    }

    currentStart = currentStart.add(const Duration(days: 7));
    if (currentStart.year > now.year + 1) break;
  }
  return missing;
}

List<MissingSummary> _getMissingMonthly(
  List<Summary> weeklies,
  List<Summary> monthlies,
) {
  if (weeklies.isEmpty) return [];
  final missing = <MissingSummary>[];
  final now = DateTime.now();

  // 识别周记覆盖的月份
  final months = <DateTime>{};
  for (final w in weeklies) {
    months.add(DateTime(w.startDate.year, w.startDate.month, 1));
  }

  for (final m in months) {
    final nextMonth = DateTime(m.year, m.month + 1, 1);
    final monthEnd = nextMonth.subtract(const Duration(seconds: 1));

    if (monthEnd.isAfter(now)) continue;

    final hasMonthly = monthlies.any(
      (s) => s.startDate.year == m.year && s.startDate.month == m.month,
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

List<MissingSummary> _getMissingQuarterly(
  List<Summary> monthlies,
  List<Summary> quarterlies,
) {
  if (monthlies.isEmpty) return [];
  final missing = <MissingSummary>[];
  final now = DateTime.now();

  final quarters = <String>{};
  for (final m in monthlies) {
    final q = (m.startDate.month / 3.0).ceil();
    quarters.add('${m.startDate.year}-$q');
  }

  for (final qKey in quarters) {
    final parts = qKey.split('-');
    final year = int.parse(parts[0]);
    final quarter = int.parse(parts[1]);

    final startMonth = (quarter - 1) * 3 + 1;
    final qStart = DateTime(year, startMonth, 1);
    final qEndMonth = startMonth + 2;
    final qEnd = DateTime(year, qEndMonth + 1, 0, 23, 59, 59);

    if (qEnd.isAfter(now)) continue;

    final hasQuarterly = quarterlies.any(
      (s) =>
          s.startDate.year == year &&
          // 简单判断年份和大概时间，或者更精确类型判断
          s.type == SummaryType.quarterly &&
          (s.startDate.month / 3.0).ceil() == quarter,
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

List<MissingSummary> _getMissingYearly(
  List<Summary> quarterlies,
  List<Summary> yearlies,
) {
  if (quarterlies.isEmpty) return [];
  final missing = <MissingSummary>[];
  final now = DateTime.now();

  final years = <int>{};
  for (final q in quarterlies) {
    years.add(q.startDate.year);
  }

  for (final year in years) {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31, 23, 59, 59);

    if (yearEnd.isAfter(now)) continue;

    final hasYearly = yearlies.any((s) => s.startDate.year == year);

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

int _getWeekNumber(DateTime date) {
  int dayOfYear = int.parse(
    date.difference(DateTime(date.year, 1, 1)).inDays.toString(),
  );
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}

@Riverpod(keepAlive: true)
MissingSummaryDetector missingSummaryDetector(Ref ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final summaryRepo = ref.watch(summaryRepositoryProvider);
  return MissingSummaryDetector(diaryRepo, summaryRepo);
}
