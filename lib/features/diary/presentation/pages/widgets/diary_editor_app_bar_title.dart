import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DiaryEditorAppBarTitle extends StatelessWidget {
  final bool isSummaryMode;
  final SummaryType? summaryType;
  final DateTime selectedDate;
  final DateTime? summaryStartDate;
  final DateTime? summaryEndDate;
  final ValueChanged<DateTime> onDateChanged;
  final void Function(DateTime start, DateTime end)? onSummaryDateChanged;

  const DiaryEditorAppBarTitle({
    super.key,
    required this.isSummaryMode,
    this.summaryType,
    required this.selectedDate,
    this.summaryStartDate,
    this.summaryEndDate,
    required this.onDateChanged,
    this.onSummaryDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isSummaryMode && summaryType != null) {
      String dateText = '';
      String subText = '';

      switch (summaryType!) {
        case SummaryType.weekly:
          subText = t.summary.stats_weekly;
          if (summaryStartDate != null && summaryEndDate != null) {
            dateText =
                '${summaryStartDate!.month}.${summaryStartDate!.day} - ${summaryEndDate!.month}.${summaryEndDate!.day}';
          }
          break;
        case SummaryType.monthly:
          subText = t.summary.stats_monthly;
          if (summaryStartDate != null) {
            dateText =
                '${summaryStartDate!.year}${t.common.year_suffix} ${summaryStartDate!.month}${t.common.month_suffix}';
          }
          break;
        case SummaryType.quarterly:
          subText = t.summary.stats_quarterly;
          if (summaryStartDate != null) {
            final q = (summaryStartDate!.month / 3).ceil();
            dateText =
                '${summaryStartDate!.year}${t.common.year_suffix} ${t.common.quarter_prefix}$q';
          }
          break;
        case SummaryType.yearly:
          subText = t.summary.stats_yearly;
          if (summaryStartDate != null) {
            dateText = '${summaryStartDate!.year}${t.common.year_suffix}';
          }
          break;
      }

      return GestureDetector(
        onTap: () => _pickSummaryDate(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    final dateStr = DateFormat(t.diary.date_format_editor).format(selectedDate);
    final localeStr = LocaleSettings.currentLocale.flutterLocale.toString();
    final weekDay = DateFormat('EEEE', localeStr).format(selectedDate);

    return GestureDetector(
      onTap: () => _pickDate(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekDay,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      onDateChanged(picked);
    }
  }

  Future<void> _pickSummaryDate(BuildContext context) async {
    if (summaryType == null || onSummaryDateChanged == null) return;

    final now = DateTime.now();
    switch (summaryType!) {
      case SummaryType.weekly:
        final result = await showDateRangePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          initialDateRange: (summaryStartDate != null && summaryEndDate != null)
              ? DateTimeRange(start: summaryStartDate!, end: summaryEndDate!)
              : null,
        );
        if (result != null) {
          onSummaryDateChanged!(result.start, result.end);
        }
        break;

      case SummaryType.monthly:
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          initialDate: summaryStartDate ?? now,
          initialDatePickerMode: DatePickerMode.year,
          helpText: t.diary.select_month,
        );
        if (date != null) {
          final start = DateTime(date.year, date.month, 1);
          final end = DateTime(date.year, date.month + 1, 0);
          onSummaryDateChanged!(start, end);
        }
        break;

      case SummaryType.quarterly:
        int year = summaryStartDate?.year ?? now.year;
        int quarter = summaryStartDate != null
            ? (summaryStartDate!.month / 3).ceil()
            : 1;

        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(t.diary.select_quarter),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<int>(
                      value: year,
                      items: List.generate(201, (i) => 1900 + i)
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y${t.common.year_suffix}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => year = v!),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [1, 2, 3, 4]
                          .map(
                            (q) => ChoiceChip(
                              label: Text('Q$q'),
                              selected: quarter == q,
                              onSelected: (b) {
                                if (b) setDialogState(() => quarter = q);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t.common.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      final start = DateTime(year, (quarter - 1) * 3 + 1, 1);
                      final end = DateTime(year, (quarter - 1) * 3 + 3 + 1, 0);
                      onSummaryDateChanged!(start, end);
                      Navigator.pop(context);
                    },
                    child: Text(t.common.confirm),
                  ),
                ],
              );
            },
          ),
        );
        break;

      case SummaryType.yearly:
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(t.summary.filter_year),
              content: SizedBox(
                width: 300,
                height: 300,
                child: YearPicker(
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                  selectedDate: summaryStartDate ?? now,
                  onChanged: (DateTime dateTime) {
                    final start = DateTime(dateTime.year, 1, 1);
                    final end = DateTime(dateTime.year, 12, 31);
                    onSummaryDateChanged!(start, end);
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          },
        );
        break;
    }
  }
}
