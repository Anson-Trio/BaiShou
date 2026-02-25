import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:baishou/i18n/strings.g.dart';

import '../theme/app_theme.dart';

class YearMonthPickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final int minYear;
  final int maxYear;

  const YearMonthPickerSheet({
    super.key,
    this.initialDate,
    this.minYear = 2000,
    this.maxYear = 2200,
  });

  @override
  State<YearMonthPickerSheet> createState() => _YearMonthPickerSheetState();
}

class _YearMonthPickerSheetState extends State<YearMonthPickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = widget.initialDate?.year ?? now.year;
    _selectedMonth = widget.initialDate?.month ?? now.month;

    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - widget.minYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                // 年份选择器
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _yearController,
                    itemExtent: 40,
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        _selectedYear = widget.minYear + index;
                      });
                    },
                    children: List<Widget>.generate(
                      widget.maxYear - widget.minYear + 1,
                      (int index) {
                        return Center(
                          child: Text(
                            '${widget.minYear + index}${t.common.year_suffix}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 月份选择器
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _monthController,
                    itemExtent: 40,
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        _selectedMonth = 1 + index;
                      });
                    },
                    children: List<Widget>.generate(12, (int index) {
                      return Center(
                        child: Text(
                          '${1 + index}${t.common.month_suffix}',
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // 底部操作区域
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    // 返回 DateTime(0) 表示“清除筛选”或“查看全部”
                    Navigator.pop(context, DateTime(0));
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).dividerColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(t.common.view_all),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消（无变更）
            child: Text(
              t.common.cancel,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Text(
            t.diary.select_month,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () {
              final date = DateTime(_selectedYear, _selectedMonth);
              Navigator.pop(context, date);
            },
            child: Text(
              t.common.confirm,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
