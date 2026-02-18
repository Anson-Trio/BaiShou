import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/year_month_picker_sheet.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/presentation/widgets/diary_card.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiaryListPage extends ConsumerStatefulWidget {
  const DiaryListPage({super.key});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final diaryStream = ref.watch(diaryRepositoryProvider).watchAllDiaries();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: GestureDetector(
          onTap: () {
            _showMonthPicker(context);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedMonth == null
                    ? '全部日记'
                    : DateFormat('yyyy年MM月').format(_selectedMonth!),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Diary>>(
          stream: diaryStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var diaries = snapshot.data!;

            // 如果已选择月份，则按月份筛选
            if (_selectedMonth != null) {
              diaries = diaries.where((d) {
                return d.date.year == _selectedMonth!.year &&
                    d.date.month == _selectedMonth!.month;
              }).toList();
            }

            if (diaries.isEmpty) return _buildEmptyState(context);

            // 按日期分组
            final grouped = groupBy(diaries, (Diary d) {
              return DateTime(d.date.year, d.date.month, d.date.day);
            });

            final sortedDates = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                ...() {
                  final List<Widget> slivers = [];
                  int? lastYear;

                  for (var date in sortedDates) {
                    // 如果年份变化，插入年份分割线
                    if (lastYear != null && date.year != lastYear) {
                      slivers.add(
                        SliverToBoxAdapter(
                          child: _buildYearDivider(context, date.year),
                        ),
                      );
                    }

                    lastYear = date.year;

                    final dayDiaries = grouped[date]!;
                    slivers.add(
                      SliverMainAxisGroup(
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _DateHeaderDelegate(date: date),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.only(
                              left: 20,
                              bottom: 32,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final diary = dayDiaries[index];
                                return _buildTimelineItem(context, ref, diary);
                              }, childCount: dayDiaries.length),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return slivers;
                }(),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ), // Fab 占位空间
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(
          '/diary/edit?date=${DateTime.now().toIso8601String()}',
        ),
        backgroundColor: AppTheme.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_note,
            size: 80,
            color: AppTheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedMonth != null ? '本月还没有日记哦' : '还没有日记哦',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          if (_selectedMonth != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _selectedMonth = null),
              child: const Text('查看全部'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, WidgetRef ref, Diary diary) {
    return Stack(
      children: [
        // 左侧连续线条
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 2,
          child: Container(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
        // 内容区域
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 24, right: 20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 时间轴节点
              Positioned(
                left: -26, // 调整以在直线上居中
                top: 20,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
              DiaryCard(
                diary: diary,
                onDelete: () {
                  _confirmDelete(context, ref, diary);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Diary diary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除日记?'),
        content: const Text('确认要删除这条日记吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(diaryRepositoryProvider).deleteDiary(diary.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildYearDivider(BuildContext context, int year) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Theme.of(context).dividerColor.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: Text(
              '$year年',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryLight,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).dividerColor.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context) async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => YearMonthPickerSheet(initialDate: _selectedMonth),
    );

    if (result != null) {
      setState(() {
        if (result.year == 0) {
          _selectedMonth = null; // 清除筛选
        } else {
          _selectedMonth = result;
        }
      });
    }
  }
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime date;

  _DateHeaderDelegate({required this.date});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final dayStr = DateFormat('dd').format(date);
    final monthStr = DateFormat('MM').format(date);

    // 手动计算星期几，避免本地化未就绪时的依赖
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekdayStr = weekdays[date.weekday];

    return Container(
      // 使用完全不透明的背景色，避免主题变更后渲染穿透
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            monthStr,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
          ),
          const Text('月', style: TextStyle(fontSize: 16, color: Colors.grey)),
          Text(
            dayStr,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
          ),
          const Text('日', style: TextStyle(fontSize: 16, color: Colors.grey)),

          const SizedBox(width: 8),
          Text(
            weekdayStr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),

          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '今天',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  double get maxExtent => 70;

  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    // 始终返回 true，确保主题变更时日期头会重新绘制（更新背景色）
    return true;
  }
}
