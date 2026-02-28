import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/year_month_picker_sheet.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/presentation/widgets/diary_card.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:baishou/core/localization/locale_service.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 日记列表页面
/// 使用 CustomScrollView 实现带有年份吸顶效果的高性能滚动列表。
class DiaryListPage extends ConsumerStatefulWidget {
  const DiaryListPage({super.key});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  DateTime? _selectedMonth;
  String _searchQuery = '';
  bool _isSearching = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final diaryStream = ref.watch(diaryRepositoryProvider).watchAllDiaries();

    bool isMobile = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isMobile = true;
      }
    } catch (e) {}
    final bool isDesktop = !isMobile;

    return SafeArea(
      top: isMobile,
      bottom: false,
      child: Scaffold(
        backgroundColor: Colors.transparent, // 让底层 Scaffold 的颜色透上来
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: _isSearching && !isDesktop
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: t.common.search_hint,
                    border: InputBorder.none,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                )
              : isDesktop
              ? _buildDesktopHeader(context)
              : _buildMobileTitle(context),
          actions: isDesktop
              ? null
              : [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) _searchQuery = '';
                      });
                    },
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                  ),
                ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : double.infinity,
            ),
            child: StreamBuilder<List<Diary>>(
              stream: diaryStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('${t.common.error}: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final diaries = snapshot.data!;

                // 性能优化：使用 helper 方法进行分组与筛选
                final filteredDiaries = _getFilteredDiaries(diaries);
                if (filteredDiaries.isEmpty) return _buildEmptyState(context);

                final groupedData = _getGroupedDiaries(filteredDiaries);
                final sortedDates = groupedData.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      ..._buildSlivers(
                        context,
                        groupedData,
                        sortedDates,
                        isDesktop,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        floatingActionButton: isDesktop
            ? null
            : FloatingActionButton(
                onPressed: () => context.push(
                  '/diary/edit?date=${DateTime.now().toIso8601String()}',
                ),
                backgroundColor: AppTheme.primary,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
      ),
    );
  }

  Widget _buildMobileTitle(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showMonthPicker(context);
      },
      onDoubleTap: () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _selectedMonth == null
                ? t.diary.all_diaries
                : DateFormat(
                    t.diary.export_month_format,
                    LocaleSettings.instance.currentLocale.languageCode,
                  ).format(_selectedMonth!),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showMonthPicker(context),
                child: Row(
                  children: [
                    Text(
                      _selectedMonth == null
                          ? DateFormat(
                              t.diary.export_month_format,
                              LocaleSettings
                                  .instance
                                  .currentLocale
                                  .languageCode,
                            ).format(DateTime.now())
                          : DateFormat(
                              t.diary.export_month_format,
                              LocaleSettings
                                  .instance
                                  .currentLocale
                                  .languageCode,
                            ).format(_selectedMonth!),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                  ],
                ),
              ),
              Text(
                t.settings.tagline_short,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          // 搜索框
          Container(
            width: 240,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: t.common.search_hint,
                      hintStyle: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 添加按钮
          IconButton.filled(
            onPressed: () => context.push(
              '/diary/edit?date=${DateTime.now().toIso8601String()}',
            ),
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              fixedSize: const Size(44, 44),
            ),
          ),
        ],
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
            _selectedMonth != null
                ? t.diary.no_diaries_month
                : t.diary.no_diaries,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          if (_selectedMonth != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _selectedMonth = null),
              child: Text(t.common.view_all),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    WidgetRef ref,
    Diary diary,
    bool isDesktop,
  ) {
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
          padding: EdgeInsets.only(
            left: isDesktop ? 40 : 20,
            bottom: 24,
            right: 20,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 时间轴节点
              Positioned(
                left: isDesktop ? -46 : -26, // 调整以在直线上居中
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
        title: Text(t.summary.delete_summary_title),
        content: Text(t.summary.confirm_delete_summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(diaryRepositoryProvider).deleteDiary(diary.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }

  /// 构建年份分割线
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
              '$year${t.common.year_suffix}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  List<Diary> _getFilteredDiaries(List<Diary> allDiaries) {
    var diaries = allDiaries;
    if (_selectedMonth != null) {
      diaries = diaries.where((d) {
        return d.date.year == _selectedMonth!.year &&
            d.date.month == _selectedMonth!.month;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      diaries = diaries
          .where((d) => d.content.toLowerCase().contains(q))
          .toList();
    }
    return diaries;
  }

  Map<DateTime, List<Diary>> _getGroupedDiaries(List<Diary> diaries) {
    return groupBy(diaries, (Diary d) {
      return DateTime(d.date.year, d.date.month, d.date.day);
    });
  }

  List<Widget> _buildSlivers(
    BuildContext context,
    Map<DateTime, List<Diary>> grouped,
    List<DateTime> sortedDates,
    bool isDesktop,
  ) {
    final List<Widget> slivers = [];
    int? lastYear;

    for (var date in sortedDates) {
      if (lastYear != null && date.year != lastYear) {
        slivers.add(
          SliverToBoxAdapter(child: _buildYearDivider(context, date.year)),
        );
      }
      lastYear = date.year;

      final dayDiaries = grouped[date]!;
      slivers.add(
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DateHeaderDelegate(date: date, isDesktop: isDesktop),
            ),
            SliverPadding(
              padding: EdgeInsets.only(left: isDesktop ? 40 : 20, bottom: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTimelineItem(
                    context,
                    ref,
                    dayDiaries[index],
                    isDesktop,
                  ),
                  childCount: dayDiaries.length,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return slivers;
  }
}

/// 日期吸顶头部委托
/// 用于在 CustomScrollView 中显示吸顶的日期信息（月、日、星期）。
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DateTime date;
  final bool isDesktop;

  _DateHeaderDelegate({required this.date, this.isDesktop = false});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final bool isEn = LocaleSettings.instance.currentLocale == AppLocale.en;
    final dayStr = DateFormat('dd').format(date);

    // 手动计算星期几，避免本地化未就绪时的依赖
    final weekdayStr = t.common.weekdays[date.weekday];

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (isEn) ...[
            Text(
              DateFormat('MMM').format(date),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
            ),
            const SizedBox(width: 8),
            Text(
              dayStr,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
            ),
          ] else ...[
            Text(
              DateFormat('MM').format(date),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
            ),
            Text(
              t.common.month_suffix,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              dayStr,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
            ),
            Text(
              t.common.day_suffix,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(width: 8),
          Text(
            weekdayStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              child: Text(
                t.common.today,
                style: const TextStyle(
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
    return oldDelegate.date != date || oldDelegate.isDesktop != isDesktop;
  }
}
