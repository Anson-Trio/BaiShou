import 'package:baishou/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 日期时间选择器底部弹出组件
class DateTimePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final TimeOfDay initialTime;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const DateTimePickerSheet({
    super.key,
    required this.initialDate,
    required this.initialTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  State<DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<DateTimePickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  final int _minYear = 2000;
  final int _maxYear = 2200;

  // Cache widgets to improve performance
  late List<Widget> _yearWidgets;
  late List<Widget> _monthWidgets;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;

    // Clamp initial date to valid range just in case
    if (_selectedYear < _minYear) _selectedYear = _minYear;
    if (_selectedYear > _maxYear) _selectedYear = _maxYear;

    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _minYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);

    // Initialize cached widgets
    _yearWidgets = List.generate(
      _maxYear - _minYear + 1,
      (index) => Center(
        child: Text(
          '${_minYear + index}年',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );

    _monthWidgets = List.generate(
      12,
      (index) => Center(
        child: Text('${index + 1}月', style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      final bool isLeapYear =
          (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const daysInMonth = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonth[month];
  }

  void _updateDate() {
    final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
    if (_selectedDay > daysInMonth) {
      _selectedDay = daysInMonth;
    }
    if (_dayController.hasClients &&
        _dayController.selectedItem > daysInMonth - 1) {
      _dayController.jumpToItem(daysInMonth - 1);
    }

    widget.onDateChanged(DateTime(_selectedYear, _selectedMonth, _selectedDay));
  }

  /// 构建滚动选择器
  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required List<Widget> children,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      onSelectedItemChanged: onSelectedItemChanged,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(
              color: AppTheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
      ),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: '日期'),
              Tab(text: '时间'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 日期选择
                Row(
                  children: [
                    // 年
                    Expanded(
                      flex: 2,
                      child: _buildPicker(
                        controller: _yearController,
                        children: _yearWidgets,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedYear = _minYear + index;
                            _updateDate();
                          });
                        },
                      ),
                    ),
                    // 月
                    Expanded(
                      flex: 1,
                      child: _buildPicker(
                        controller: _monthController,
                        children: _monthWidgets,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedMonth = index + 1;
                            _updateDate();
                          });
                        },
                      ),
                    ),
                    // 日
                    Expanded(
                      flex: 1,
                      child: _buildPicker(
                        controller: _dayController,
                        children: List.generate(
                          _getDaysInMonth(_selectedYear, _selectedMonth),
                          (index) => Center(
                            child: Text(
                              '${index + 1}日',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedDay = index + 1;
                            _updateDate();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // 时间选择
                CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2020,
                    1,
                    1,
                    widget.initialTime.hour,
                    widget.initialTime.minute,
                  ),
                  use24hFormat: true,
                  onDateTimeChanged: (dt) {
                    widget.onTimeChanged(TimeOfDay.fromDateTime(dt));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
