import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_preferences_provider.dart';

/// 汇总筛选状态模型
class SummaryFilterState {
  final DateTime? weeklyStartDate;
  final DateTime? weeklyEndDate;
  final DateTime? monthlyDate;
  final DateTime? quarterlyDate;
  final int lookbackMonths;

  const SummaryFilterState({
    this.weeklyStartDate,
    this.weeklyEndDate,
    this.monthlyDate,
    this.quarterlyDate,
    this.lookbackMonths = 12,
  });

  SummaryFilterState copyWith({
    DateTime? weeklyStartDate,
    DateTime? weeklyEndDate,
    DateTime? monthlyDate,
    DateTime? quarterlyDate,
    int? lookbackMonths,
    bool clearWeekly = false,
    bool clearMonthly = false,
    bool clearQuarterly = false,
  }) {
    return SummaryFilterState(
      weeklyStartDate: clearWeekly
          ? null
          : (weeklyStartDate ?? this.weeklyStartDate),
      weeklyEndDate: clearWeekly ? null : (weeklyEndDate ?? this.weeklyEndDate),
      monthlyDate: clearMonthly ? null : (monthlyDate ?? this.monthlyDate),
      quarterlyDate: clearQuarterly
          ? null
          : (quarterlyDate ?? this.quarterlyDate),
      lookbackMonths: lookbackMonths ?? this.lookbackMonths,
    );
  }
}

class SummaryFilterNotifier extends Notifier<SummaryFilterState> {
  static const String _keyWeeklyStart = 'summary_filter_weekly_start';
  static const String _keyWeeklyEnd = 'summary_filter_weekly_end';
  static const String _keyMonthly = 'summary_filter_monthly';
  static const String _keyQuarterly = 'summary_filter_quarterly';
  static const String _keyLookback = 'summary_filter_lookback';

  late SharedPreferences _prefs;

  @override
  SummaryFilterState build() {
    _prefs = ref.watch(sharedPreferencesProvider);

    final weeklyStartStr = _prefs.getString(_keyWeeklyStart);
    final weeklyEndStr = _prefs.getString(_keyWeeklyEnd);
    final monthlyStr = _prefs.getString(_keyMonthly);
    final quarterlyStr = _prefs.getString(_keyQuarterly);
    final lookback = _prefs.getInt(_keyLookback) ?? 12;

    return SummaryFilterState(
      weeklyStartDate: weeklyStartStr != null
          ? DateTime.parse(weeklyStartStr)
          : null,
      weeklyEndDate: weeklyEndStr != null ? DateTime.parse(weeklyEndStr) : null,
      monthlyDate: monthlyStr != null ? DateTime.parse(monthlyStr) : null,
      quarterlyDate: quarterlyStr != null ? DateTime.parse(quarterlyStr) : null,
      lookbackMonths: lookback,
    );
  }

  Future<void> updateWeeklyFilter(DateTime? start, DateTime? end) async {
    if (start == null || end == null) {
      await _prefs.remove(_keyWeeklyStart);
      await _prefs.remove(_keyWeeklyEnd);
    } else {
      await _prefs.setString(_keyWeeklyStart, start.toIso8601String());
      await _prefs.setString(_keyWeeklyEnd, end.toIso8601String());
    }
    state = state.copyWith(
      weeklyStartDate: start,
      weeklyEndDate: end,
      clearWeekly: start == null,
    );
  }

  Future<void> updateMonthlyFilter(DateTime? date) async {
    if (date == null) {
      await _prefs.remove(_keyMonthly);
    } else {
      await _prefs.setString(_keyMonthly, date.toIso8601String());
    }
    state = state.copyWith(monthlyDate: date, clearMonthly: date == null);
  }

  Future<void> updateQuarterlyFilter(DateTime? date) async {
    if (date == null) {
      await _prefs.remove(_keyQuarterly);
    } else {
      await _prefs.setString(_keyQuarterly, date.toIso8601String());
    }
    state = state.copyWith(quarterlyDate: date, clearQuarterly: date == null);
  }

  Future<void> clearFilter(int index) async {
    switch (index) {
      case 0:
        await updateWeeklyFilter(null, null);
        break;
      case 1:
        await updateMonthlyFilter(null);
        break;
      case 2:
        await updateQuarterlyFilter(null);
        break;
    }
  }

  Future<void> updateLookbackMonths(int months) async {
    await _prefs.setInt(_keyLookback, months);
    state = state.copyWith(lookbackMonths: months);
  }
}

final summaryFilterProvider =
    NotifierProvider<SummaryFilterNotifier, SummaryFilterState>(
      SummaryFilterNotifier.new,
    );
