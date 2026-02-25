import 'dart:io';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';

import 'package:baishou/core/widgets/year_month_picker_sheet.dart';
import 'package:baishou/core/widgets/year_picker_sheet.dart';
import 'package:baishou/features/summary/presentation/widgets/summary_dashboard_view.dart';
import 'package:baishou/features/summary/presentation/widgets/summary_list_view.dart';
import 'package:baishou/features/summary/presentation/widgets/summary_raw_data_view.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 总结主页面
/// 聚合了数据仪表盘（各维度总结）与原始数据导出两个核心子视图。
class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isMobile = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isMobile = true;
      }
    } catch (e) {}

    return DefaultTabController(
      length: 3,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.go('/');
        },
        child: SafeArea(
          top: isMobile,
          bottom: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(t.summary.dashboard_title),
              centerTitle: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              bottom: TabBar(
                tabs: [
                  Tab(text: t.summary.collective_memories_title),
                  Tab(text: t.summary.raw_data_tab),
                  Tab(text: t.summary.history_tab),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                SummaryDashboardView(),
                SummaryRawDataView(),
                _SummaryArchiveView(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// _SummaryArchiveView 需要为每个标签页管理筛选器
class _SummaryArchiveView extends StatefulWidget {
  const _SummaryArchiveView();

  @override
  State<_SummaryArchiveView> createState() => _SummaryArchiveViewState();
}

class _SummaryArchiveViewState extends State<_SummaryArchiveView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 筛选状态
  DateTime? _weeklyStartDate;
  DateTime? _weeklyEndDate;
  DateTime? _monthlyDate; // 年-月
  DateTime? _quarterlyDate; // 年-季度

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: [
                  Tab(text: t.summary.tab_weekly),
                  Tab(text: t.summary.tab_monthly),
                  Tab(text: t.summary.tab_quarterly),
                  Tab(text: t.summary.tab_yearly),
                ],
              ),
            ),
            // 筛选栏
            _buildFilterBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SummaryListView(
                    type: SummaryType.weekly,
                    startDate: _weeklyStartDate,
                    endDate: _weeklyEndDate,
                  ),
                  SummaryListView(
                    type: SummaryType.monthly,
                    startDate: _monthlyDate,
                    endDate: _monthlyDate != null
                        ? DateTime(
                            _monthlyDate!.year,
                            12,
                            31,
                            23,
                            59,
                            59,
                          ) // 覆盖整年到最后一秒
                        : null,
                  ),
                  SummaryListView(
                    type: SummaryType.quarterly,
                    startDate: _quarterlyDate, // 这里表示年份（1月1日）
                    endDate: _quarterlyDate != null
                        ? DateTime(
                            _quarterlyDate!.year,
                            12,
                            31,
                            23,
                            59,
                            59,
                          ) // 覆盖整年到最后一秒
                        : null,
                  ),
                  SummaryListView(
                    type: SummaryType.yearly,
                    startDate: null, // 无筛选
                    endDate: null,
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddSummaryDialog(context),
            backgroundColor: AppTheme.primary,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final index = _tabController.index;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).cardColor.withOpacity(0.5),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getFilterText(index),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_hasFilter(index))
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => _clearFilter(index),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate(int index) async {
    final now = DateTime.now();
    switch (index) {
      case 0: // 周记 - 年月选择器 -> 按月筛选
        final date = await showModalBottomSheet<DateTime>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              YearMonthPickerSheet(initialDate: _weeklyStartDate ?? now),
        );
        if (date != null) {
          setState(() {
            if (date.year == 0) {
              _weeklyStartDate = null;
              _weeklyEndDate = null;
            } else {
              _weeklyStartDate = date;
              // 筛选该月内开始的所有周记
              _weeklyEndDate = DateTime(date.year, date.month + 1, 0);
            }
          });
        }
        break;

      case 1: // 月报 - 年份选择器 (原为年月)
        // 用户反馈：月报筛选器应改为年份选择器。选择年份后显示该年所有月报。
        final date = await showModalBottomSheet<DateTime>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              YearPickerSheet(initialDate: _monthlyDate ?? now),
        );
        if (date != null) {
          setState(() {
            if (date.year == 0) {
              _monthlyDate = null;
            } else {
              _monthlyDate = date; // 这里表示该年的1月1日
            }
          });
        }
        break;

      case 2: // 季报 - 年份选择器
        final date = await showModalBottomSheet<DateTime>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              YearPickerSheet(initialDate: _quarterlyDate ?? now),
        );
        if (date != null) {
          setState(() {
            if (date.year == 0) {
              _quarterlyDate = null;
            } else {
              _quarterlyDate = date; // 年份 1月1日
            }
          });
        }
        break;

      case 3: // 年鉴 - 无筛选
        // 什么都不做，或者显示 Toast “年鉴默认显示全部”
        // 用户说“年鉴不需要筛选”。
        break;
    }
  }

  // ...

  String _getFilterText(int index) {
    switch (index) {
      case 0: // 周记
        if (_weeklyStartDate == null) return t.summary.filter_month;
        return '${_weeklyStartDate!.year}${t.common.year_suffix} ${_weeklyStartDate!.month}${t.common.month_suffix}';
      case 1: // 月报
        if (_monthlyDate == null) return t.summary.filter_year;
        return '${_monthlyDate!.year}${t.common.year_suffix}';
      case 2: // 季报
        if (_quarterlyDate == null) return t.summary.filter_year;
        return '${_quarterlyDate!.year}${t.common.year_suffix}';
      case 3: // 年鉴
        return t.summary.all_yearly;
    }
    return '';
  }

  bool _hasFilter(int index) {
    switch (index) {
      case 0:
        return _weeklyStartDate != null;
      case 1:
        return _monthlyDate != null;
      case 2:
        return _quarterlyDate != null;
      case 3:
        return false; // 年鉴无筛选
    }
    return false;
  }

  void _clearFilter(int index) {
    setState(() {
      switch (index) {
        case 0:
          _weeklyStartDate = null;
          _weeklyEndDate = null;
          break;
        case 1:
          _monthlyDate = null;
          break;
        case 2:
          _quarterlyDate = null;
          break;
      }
    });
  }

  void _showAddSummaryDialog(BuildContext context) {
    // 将索引映射到类型
    final types = [
      SummaryType.weekly,
      SummaryType.monthly,
      SummaryType.quarterly,
      SummaryType.yearly,
    ];
    final type = types[_tabController.index];

    showDialog(
      context: context,
      builder: (context) => _AddSummaryDialog(fixedType: type),
    );
  }
}

class _AddSummaryDialog extends ConsumerStatefulWidget {
  final SummaryType fixedType;

  const _AddSummaryDialog({required this.fixedType});

  @override
  ConsumerState<_AddSummaryDialog> createState() => __AddSummaryDialogState();
}

class __AddSummaryDialogState extends ConsumerState<_AddSummaryDialog> {
  late DateTimeRange _dateRange;
  final _contentController = TextEditingController();
  bool _isLoading = false;

  // 选择状态
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _selectedQuarter = 1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    // 计算初始季度
    _selectedQuarter = (now.month / 3).ceil();

    // 默认范围取决于类型
    if (widget.fixedType == SummaryType.weekly) {
      // 默认为上周（周一至周日）
      // 或者仅过去7天。标准周通常是周一至周日。
      // 为了与原始数据默认值一致，或者对齐到周边界，我们使用简单的过去7天？
      // 用户说“周记是特定日期范围”。
      _dateRange = DateTimeRange(
        start: now.subtract(const Duration(days: 6)),
        end: now,
      );
    } else {
      _updateDateRangeFromSelection();
    }
  }

  void _updateDateRangeFromSelection() {
    DateTime start;
    DateTime end;

    switch (widget.fixedType) {
      case SummaryType.monthly:
        start = DateTime(_selectedYear, _selectedMonth, 1);
        final nextMonth = _selectedMonth == 12
            ? DateTime(_selectedYear + 1, 1, 1)
            : DateTime(_selectedYear, _selectedMonth + 1, 1);
        end = nextMonth.subtract(const Duration(days: 1));
        break;
      case SummaryType.quarterly:
        final startMonth = (_selectedQuarter - 1) * 3 + 1;
        start = DateTime(_selectedYear, startMonth, 1);
        final endMonth = startMonth + 2;
        final nextQuarterStart = endMonth == 12
            ? DateTime(_selectedYear + 1, 1, 1)
            : DateTime(_selectedYear, endMonth + 1, 1);
        end = nextQuarterStart.subtract(const Duration(days: 1));
        break;
      case SummaryType.yearly:
        start = DateTime(_selectedYear, 1, 1);
        end = DateTime(_selectedYear, 12, 31);
        break;
      case SummaryType.weekly:
        // 由日期选择器处理
        return;
    }
    setState(() {
      _dateRange = DateTimeRange(start: start, end: end);
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
      initialDateRange: _dateRange,
    );
    if (result != null) {
      setState(() => _dateRange = result);
    }
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      AppToast.showSuccess(context, t.summary.input_content);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(summaryRepositoryProvider)
          .addSummary(
            type: widget.fixedType,
            startDate: _dateRange.start,
            endDate: _dateRange.end,
            content: content,
          );
      if (mounted) {
        Navigator.pop(context);
        AppToast.showSuccess(context, t.summary.added_success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, '${t.summary.add_failed}: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTypeLabel(SummaryType type) {
    switch (type) {
      case SummaryType.weekly:
        return t.summary.stats_weekly;
      case SummaryType.monthly:
        return t.summary.stats_monthly;
      case SummaryType.quarterly:
        return t.summary.stats_quarterly;
      case SummaryType.yearly:
        return t.summary.stats_yearly;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        t.summary.add_summary_title(type: _getTypeLabel(widget.fixedType)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期选择器
            _buildDateSelector(),

            const SizedBox(height: 16),

            // 内容
            TextField(
              controller: _contentController,
              maxLines: 10,
              minLines: 5,
              decoration: InputDecoration(
                labelText: t.summary.content_label,
                hintText: t.summary.paste_hint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.common.save),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    if (widget.fixedType == SummaryType.weekly) {
      return InkWell(
        onTap: _pickDateRange,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: t.summary.time_range_label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_dateRange.start.year}.${_dateRange.start.month}.${_dateRange.start.day} - ${_dateRange.end.year}.${_dateRange.end.month}.${_dateRange.end.day}',
              ),
              const Icon(Icons.calendar_today, size: 18),
            ],
          ),
        ),
      );
    }

    final years = List.generate(50, (index) => 2020 + index);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.summary.tap_to_select_range,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // 年份选择器（始终显示）
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                  ),
                  items: years
                      .map(
                        (y) => DropdownMenuItem(
                          value: y,
                          child: Text('$y${t.common.year_suffix}'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = val;
                        _updateDateRangeFromSelection();
                      });
                    }
                  },
                ),
              ),

              // 月份选择器
              if (widget.fixedType == SummaryType.monthly) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 8,
                      ),
                      border: InputBorder.none,
                    ),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text('$m${t.common.month_suffix}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMonth = val;
                          _updateDateRangeFromSelection();
                        });
                      }
                    },
                  ),
                ),
              ],

              // 季度选择器
              if (widget.fixedType == SummaryType.quarterly) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedQuarter,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 8,
                      ),
                      border: InputBorder.none,
                    ),
                    items: [1, 2, 3, 4]
                        .map(
                          (q) => DropdownMenuItem(
                            value: q,
                            child: Text('${t.common.quarter_prefix}$q'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedQuarter = val;
                          _updateDateRangeFromSelection();
                        });
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
