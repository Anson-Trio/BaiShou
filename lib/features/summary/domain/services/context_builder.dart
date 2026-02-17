import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'context_builder.g.dart';

class ContextBuilder {
  final DiaryRepository _diaryRepo;
  final SummaryRepository _summaryRepo;

  ContextBuilder(this._diaryRepo, this._summaryRepo);

  Future<ContextResult> buildLifeBookContext({int months = 12}) async {
    final now = DateTime.now();
    // Calculate start date: subtract months (approximate 30 days per month)
    // Or use precise month subtraction logic
    final startDate = DateTime(now.year, now.month - months, 1);

    // Fetch all data
    // optimization: fetch distinct types if specific query is available,
    // but here we fetch all summaries for simplicity of cascade logic
    final allSummaries = await _summaryRepo.getSummaries();
    final allDiaries = await _diaryRepo.getDiariesByDateRange(startDate, now);

    // 2. Filter Summaries by Date (End date must be after start date to be relevant)
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

    // 3. Cascading Filter Logic

    // Set of "YYYYMM" that are covered by higher level summaries
    final Set<String> coveredMonthKeys = {};

    // Helper: Add months covered by summary to set
    void markMonthsCovered(Summary s) {
      DateTime current = DateTime(s.startDate.year, s.startDate.month);
      // Iterate until end date's month
      // Note: endDate is usually end of month/quarter.
      // E.g. 2024-03-31. Month is 3.
      final endMonthDate = DateTime(s.endDate.year, s.endDate.month);

      while (current.isBefore(endMonthDate) ||
          current.isAtSameMomentAs(endMonthDate)) {
        final key = DateFormat('yyyyMM').format(current);
        coveredMonthKeys.add(key);
        // Add 1 month
        current = DateTime(current.year, current.month + 1);
      }
    }

    // 3.1 Quarters cover Months
    for (final q in qList) {
      markMonthsCovered(q);
    }

    // 3.2 Filter visible Months (exclude if covered by Q)
    final visibleMonths = mList.where((m) {
      final key = DateFormat('yyyyMM').format(m.startDate);
      // If month summary's month is in covered keys, skip it?
      // Yes. Wait, mList items themselves cover 'key'.
      // If 'key' is already in coveredMonthKeys (populated by Q), then this M is redundant.
      return !coveredMonthKeys.contains(key);
    }).toList();

    // 3.3 Add visible Months to covered set (for Weeks/Dailies filtering)
    for (final m in visibleMonths) {
      markMonthsCovered(m);
    }

    // Now coveredMonthKeys contains months covered by Q OR M.

    // 3.4 Filter visible Weeks
    final visibleWeeks = wList.where((w) {
      // Week covers a range. If that range falls into a covered month(s).
      // Logic: If the week's end date's month is in covered keys?
      // Usually week is assigned to the month of its end date or majority.
      // Script: `visibleWeeks = wList.filter(w => !allCoveredMonths.has(w.monthKey))`
      // `monthKey` for week in script was `wEnd.format("YYYYMM")`.
      final key = DateFormat('yyyyMM').format(w.endDate);
      return !coveredMonthKeys.contains(key);
    }).toList();

    // 3.5 Filter visible Dailies
    // Cutoff date: Max end date of visible weeks.
    // Script: `if (wEndStr > cutoff) cutoff = wEndStr;`
    // Diaries before cutoff are assumed to be covered by weeks (even if weeks are visible).
    // Wait, if week is visible, then diaries IN that week should be hidden? Yes.
    // If week is NOT visible (hidden by M/Q), then diaries IN that week are definitely hidden (by M/Q).
    // So basically, if a date is covered by ANY visible higher level summary (or covered implicit summary), hide it.

    DateTime? cutoffDate;
    if (visibleWeeks.isNotEmpty) {
      // Find max end date
      cutoffDate = visibleWeeks
          .map((w) => w.endDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }

    final visibleDiaries = allDiaries.where((d) {
      final key = DateFormat('yyyyMM').format(d.date);
      // 1. Check if month is covered by Q or M
      if (coveredMonthKeys.contains(key)) return false;

      // 2. Check if covered by Weekly summaries logic
      // In script: if (d.date <= cutoff) return false;
      // This implies that visibleWeeks cover all days up to the last visible week.
      // Is this safe?
      // Assuming visibleWeeks are continuous up to `cutoff`.
      // If there is a gap in weeks, those diaries might be lost?
      // But typically weekly summaries are generated continuously.
      // If cutoff is available and d.date is before cutoff, skip.
      if (cutoffDate != null &&
          (d.date.isBefore(cutoffDate) ||
              d.date.isAtSameMomentAs(cutoffDate))) {
        return false;
      }
      return true;
    }).toList();

    // 4. Construct Markdown
    final buffer = StringBuffer();
    buffer.writeln('# 共同的回忆 (过去 $months 个月 - 白守算法已折叠)');
    buffer.writeln();

    // Sort all by date? Or group by type?
    // Script: `yList`, `visibleQuarters`, `visibleMonths`... pushed to ioPromises.
    // results sorted by path (usually date).
    // Here we can output by hierarchy or date.
    // Let's output by hierarchy for clarity in Context, or Date for chronological?
    // Chronological is better for AI context.

    final allItems = <_ContextItem>[];

    for (var i in yList) allItems.add(_ContextItem(i.startDate, i, '👑 年度'));
    for (var i in qList) allItems.add(_ContextItem(i.startDate, i, '🏆 季度'));
    for (var i in visibleMonths)
      allItems.add(_ContextItem(i.startDate, i, '🌙 月度'));
    for (var i in visibleWeeks)
      allItems.add(_ContextItem(i.startDate, i, '📆 周度'));

    // Diaries
    final diaryItems = visibleDiaries
        .map((d) => _ContextItem(d.date, d, '📝 日记'))
        .toList();
    allItems.addAll(diaryItems);

    // Sort by date ASC
    allItems.sort((a, b) => a.date.compareTo(b.date));

    // Render
    for (final item in allItems) {
      if (item.data is Summary) {
        buffer.writeln('## ${item.prefix} ${_formatDate(item.date)}');
        buffer.writeln((item.data as Summary).content);
      } else if (item.data is Diary) {
        final d = item.data as Diary;
        buffer.writeln('## ${item.prefix} ${_formatDate(d.date)}');
        buffer.writeln(d.content); // Diary content
      }
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    // Append Meta to text?
    // Usually meta is for debugging or dashboard.
    // User context string might not need meta stats at the end if UI shows it.
    // But keeping it in text is good for LLM to know context volume.
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
