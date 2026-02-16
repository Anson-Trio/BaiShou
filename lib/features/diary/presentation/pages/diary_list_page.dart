import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/presentation/widgets/diary_card.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiaryListPage extends ConsumerWidget {
  const DiaryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaryStream = ref.watch(diaryRepositoryProvider).watchAllDiaries();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Custom Header logic integrated into body list if possible or use Sliver
      body: SafeArea(
        child: StreamBuilder<List<Diary>>(
          stream: diaryStream,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final diaries = snapshot.data!;
            if (diaries.isEmpty) return _buildEmptyState(context);

            // Group by Date
            final grouped = groupBy(diaries, (Diary d) {
              return DateTime(d.date.year, d.date.month, d.date.day);
            });

            final sortedDates = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ...() {
                  final List<Widget> slivers = [];
                  int? lastYear;

                  for (var date in sortedDates) {
                    // Insert Year Divider if year changes
                    if (lastYear != null && date.year != lastYear) {
                      // Because list is descending (newest first),
                      // when we switch from 2024 to 2023, we want to show "2023"
                      // This divider appears BEFORE the group of 2023 dates.
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
                ), // Fab space
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
            '还没有日记哦',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, WidgetRef ref, Diary diary) {
    return Stack(
      children: [
        // Continuous Line on Left
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 2, // border-l width
          child: Container(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
        // Item Content
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 24, right: 20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Dot
              Positioned(
                left:
                    -26, // Adjust to center on line: -20 padding - (10width/2) + 1widthline = -24 approx
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

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
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
          if (isToday) ...[
            const SizedBox(width: 8),
            const Text(
              '今天',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
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
  double get minExtent => 70; // 保持固定高度

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return oldDelegate.date != date;
  }
}
