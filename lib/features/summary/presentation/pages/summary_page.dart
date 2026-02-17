import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';

import 'package:baishou/features/summary/presentation/widgets/summary_dashboard_view.dart';
import 'package:baishou/features/summary/presentation/widgets/summary_list_view.dart';
import 'package:baishou/features/summary/presentation/widgets/summary_raw_data_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI 总结'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '仪表盘'),
              Tab(text: '原始数据'),
              Tab(text: '历史归档'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                AppToast.show(context, '设置功能开发中');
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            SummaryDashboardView(),
            SummaryRawDataView(),
            _SummaryArchiveView(),
          ],
        ),
      ),
    );
  }
}

class _SummaryArchiveView extends StatefulWidget {
  const _SummaryArchiveView();

  @override
  State<_SummaryArchiveView> createState() => _SummaryArchiveViewState();
}

class _SummaryArchiveViewState extends State<_SummaryArchiveView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
                tabs: const [
                  Tab(text: '周记'),
                  Tab(text: '月报'),
                  Tab(text: '季报'),
                  Tab(text: '年鉴'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  SummaryListView(type: SummaryType.weekly),
                  SummaryListView(type: SummaryType.monthly),
                  SummaryListView(type: SummaryType.quarterly),
                  SummaryListView(type: SummaryType.yearly),
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
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  void _showAddSummaryDialog(BuildContext context) {
    // Map index to type
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

  // Selection states
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _selectedQuarter = 1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    // Calculate initial quarter
    _selectedQuarter = (now.month / 3).ceil();

    // Default range depends on type
    if (widget.fixedType == SummaryType.weekly) {
      // Default to last week (Mon-Sun)
      // Or just past 7 days. Standard week usually Mon-Sun.
      // Let's use simple past 7 days for consistency with Raw Data default, or align to week boundaries?
      // User said "Week is specific date range".
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
        // Handled by date picker
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
      AppToast.show(context, '请输入内容');
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
        AppToast.show(context, '已添加');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '添加失败: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTypeLabel(SummaryType type) {
    switch (type) {
      case SummaryType.weekly:
        return '周记';
      case SummaryType.monthly:
        return '月报';
      case SummaryType.quarterly:
        return '季报';
      case SummaryType.yearly:
        return '年鉴';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('添加${_getTypeLabel(widget.fixedType)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Selector
            _buildDateSelector(),

            const SizedBox(height: 16),

            // Content
            TextField(
              controller: _contentController,
              maxLines: 10,
              minLines: 5,
              decoration: const InputDecoration(
                labelText: '总结内容',
                hintText: '在此粘贴 AI 生成的总结...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
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
          decoration: const InputDecoration(
            labelText: '时间范围',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
            '选择时间',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Year Selector (Always present)
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
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
                        (y) => DropdownMenuItem(value: y, child: Text('$y年')),
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

              // Month Selector
              if (widget.fixedType == SummaryType.monthly) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
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
                          (m) => DropdownMenuItem(value: m, child: Text('$m月')),
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

              // Quarter Selector
              if (widget.fixedType == SummaryType.quarterly) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedQuarter,
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
                          (q) => DropdownMenuItem(value: q, child: Text('Q$q')),
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
