import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:flutter/foundation.dart' hide Summary;
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'context_builder.g.dart';

class ContextBuilder {
  final DiaryRepository _diaryRepo;
  final SummaryRepository _summaryRepo;

  ContextBuilder(this._diaryRepo, this._summaryRepo);

  Future<ContextResult> buildLifeBookContext({int months = 12}) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months, 1);

    // 1. 获取所有数据 (在主线程/IO线程)
    final allSummaries = await _summaryRepo.getSummaries();
    final allDiaries = await _diaryRepo.getDiariesByDateRange(startDate, now);

    // 2. 在 Isolate 中处理数据
    return compute(
      _processContextData,
      _ContextInput(
        summaries: allSummaries,
        diaries: allDiaries,
        startDate: startDate,
        months: months,
      ),
    );
  }
}

class _ContextInput {
  final List<Summary> summaries;
  final List<Diary> diaries;
  final DateTime startDate;
  final int months;

  _ContextInput({
    required this.summaries,
    required this.diaries,
    required this.startDate,
    required this.months,
  });
}

Future<ContextResult> _processContextData(_ContextInput input) async {
  final allSummaries = input.summaries;
  final allDiaries = input.diaries;
  final startDate = input.startDate;
  final months = input.months;

  // 2. 按日期过滤总结（结束日期必须在开始日期之后才相关）
  final relevantSummaries = allSummaries
      .where((s) => s.endDate.isAfter(startDate))
      .toList();

  final yList = relevantSummaries
      .where((s) => s.type == SummaryType.yearly)
      .toList();
  final qList = relevantSummaries
      .where((s) => s.type == SummaryType.quarterly)
      .toList();
  final mList = relevantSummaries
      .where((s) => s.type == SummaryType.monthly)
      .toList();
  final wList = relevantSummaries
      .where((s) => s.type == SummaryType.weekly)
      .toList();

  // 3. 级联过滤逻辑

  // 被更高级别总结覆盖的 "YYYYMM" 集合
  final Set<String> coveredMonthKeys = {};

  // 辅助方法：将总结覆盖的月份添加到集合
  void markMonthsCovered(Summary s) {
    DateTime current = DateTime(s.startDate.year, s.startDate.month);
    // 迭代直到结束日期的月份
    // 注意：endDate 通常是月末/季度末。

    final endMonthDate = DateTime(s.endDate.year, s.endDate.month);

    while (current.isBefore(endMonthDate) ||
        current.isAtSameMomentAs(endMonthDate)) {
      final key = DateFormat('yyyyMM').format(current);
      coveredMonthKeys.add(key);
      // 增加 1 个月
      current = DateTime(current.year, current.month + 1);
    }
  }

  // 3.1 季度覆盖月份
  for (final q in qList) {
    markMonthsCovered(q);
  }

  // 3.2 过滤可见月份（如果被 Q 覆盖则排除）
  final visibleMonths = mList.where((m) {
    final key = DateFormat('yyyyMM').format(m.startDate);
    // 如果总结的月份在覆盖键中，则跳过
    return !coveredMonthKeys.contains(key);
  }).toList();

  // 3.3 将可见月份添加到覆盖集合（用于周/日记过滤）
  for (final m in visibleMonths) {
    markMonthsCovered(m);
  }

  // 现在 coveredMonthKeys 包含被 Q 或 M 覆盖的月份。

  // 3.4 过滤可见周
  final visibleWeeks = wList.where((w) {
    // 周覆盖一个范围。如果该范围落入覆盖的月份中。
    // 逻辑：如果周的结束日期的月份在覆盖键中？
    // 通常周被分配给其结束日期的月份或大多数时间所在的月份。
    final key = DateFormat('yyyyMM').format(w.endDate);
    return !coveredMonthKeys.contains(key);
  }).toList();

  // 3.5 过滤可见日记
  // 截止日期：可见周的最大结束日期。
  // 如果日期被任何可见的更高级别总结（或覆盖的隐式总结）覆盖，则隐藏它。

  DateTime? cutoffDate;
  if (visibleWeeks.isNotEmpty) {
    // 查找最大结束日期
    cutoffDate = visibleWeeks
        .map((w) => w.endDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  final visibleDiaries = allDiaries.where((d) {
    final key = DateFormat('yyyyMM').format(d.date);
    // 1. 检查月份是否被 Q 或 M 覆盖
    if (coveredMonthKeys.contains(key)) return false;

    // 2. 检查是否被周记覆盖
    // 假设 visibleWeeks 连续到 `cutoff`。
    // 如果有截止日期且 d.date 在截止日期之前，则跳过。
    if (cutoffDate != null &&
        (d.date.isBefore(cutoffDate) || d.date.isAtSameMomentAs(cutoffDate))) {
      return false;
    }
    return true;
  }).toList();

  // 4. 构建 Markdown
  final buffer = StringBuffer();
  buffer.writeln('# 共同的回忆 (过去 $months 个月 - 白守算法已折叠)');
  buffer.writeln();

  // 最好按时间顺序输出以便于 AI 上下文。

  final allItems = <_ContextItem>[];

  for (var i in yList) {
    allItems.add(_ContextItem(i.startDate, i, '👑 年度'));
  }
  for (var i in qList) {
    allItems.add(_ContextItem(i.startDate, i, '🏆 季度'));
  }
  for (var i in visibleMonths) {
    allItems.add(_ContextItem(i.startDate, i, '🌙 月度'));
  }
  for (var i in visibleWeeks) {
    allItems.add(_ContextItem(i.startDate, i, '📆 周度'));
  }

  // 日记
  final diaryItems = visibleDiaries
      .map((d) => _ContextItem(d.date, d, '📝 日记'))
      .toList();
  allItems.addAll(diaryItems);

  // 按日期升序排序
  allItems.sort((a, b) => a.date.compareTo(b.date));

  // 渲染
  for (final item in allItems) {
    if (item.data is Summary) {
      buffer.writeln('## ${item.prefix} ${_formatDate(item.date)}');
      buffer.writeln((item.data as Summary).content);
    } else if (item.data is Diary) {
      final d = item.data as Diary;
      buffer.writeln('## ${item.prefix} ${_formatDate(d.date)}');
      buffer.writeln(d.content); // 日记内容
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
  }

  // 将元数据附加到文本？
  // 通常元数据用于调试在仪表板。
  // 保持在文本中以便 LLM 了解上下文量。
  buffer.writeln('__Meta Statistics__');
  buffer.writeln('- Yearly: ${yList.length}');
  buffer.writeln('- Quarterly: ${qList.length}');
  buffer.writeln('- Monthly: ${visibleMonths.length}');
  buffer.writeln('- Weekly: ${visibleWeeks.length}');
  buffer.writeln('- Dailies: ${visibleDiaries.length}');

  return ContextResult(
    text: buffer.toString(),
    yearCount: yList.length,
    quarterCount: qList.length,
    monthCount: visibleMonths.length,
    weekCount: visibleWeeks.length,
    diaryCount: visibleDiaries.length,
  );
}

String _formatDate(DateTime d) {
  return DateFormat('yyyy-MM-dd').format(d);
}

class ContextResult {
  final String text;
  final int yearCount;
  final int quarterCount;
  final int monthCount;
  final int weekCount;
  final int diaryCount;

  ContextResult({
    required this.text,
    required this.yearCount,
    required this.quarterCount,
    required this.monthCount,
    required this.weekCount,
    required this.diaryCount,
  });
}

class _ContextItem {
  final DateTime date;
  final dynamic data;
  final String prefix;
  _ContextItem(this.date, this.data, this.prefix);
}

@Riverpod(keepAlive: true)
ContextBuilder contextBuilder(Ref ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final summaryRepo = ref.watch(summaryRepositoryProvider);
  return ContextBuilder(diaryRepo, summaryRepo);
}
