import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// 日记列表页面
/// 使用 MasonryGridView 实现类似草稿纸变体3的瀑布流。
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withOpacity(0.8),
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
              : _buildHeader(context, isDesktop),
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
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
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
                      final filteredDiaries = _getFilteredDiaries(diaries);

                      // 降序排序，最新在最前
                      filteredDiaries.sort((a, b) => b.date.compareTo(a.date));

                      if (filteredDiaries.isEmpty)
                        return _buildEmptyState(context);

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: () {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        child: MasonryGridView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 32 : 16,
                            vertical: 24,
                          ),
                          gridDelegate:
                              SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _getCrossAxisCount(context),
                              ),
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          itemCount: filteredDiaries.length,
                          itemBuilder: (context, index) {
                            return DiaryCard(
                              diary: filteredDiaries[index],
                              onDelete: () => _confirmDelete(
                                context,
                                ref,
                                filteredDiaries[index],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Floating Action Buttons (Bottom Right for Desktop)
            if (isDesktop)
              Positioned(
                bottom: 32,
                right: 32,
                child: _buildDesktopFABs(context, diaryStream),
              ),
          ],
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

  int _getCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    // 考虑左侧导航栏大约占 256px
    if (width > 1200) return 3; // 变体3的三栏
    if (width > 700) return 2; // 变体3的双栏
    return 1;
  }

  Widget _buildDesktopFABs(
    BuildContext context,
    Stream<List<Diary>> diaryStream,
  ) {
    return StreamBuilder<List<Diary>>(
      stream: diaryStream,
      builder: (context, snapshot) {
        final diaries = snapshot.data ?? [];
        final todayDiary = diaries.firstWhereOrNull(
          (d) => DateUtils.isSameDay(d.date, DateTime.now()),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Edit Today button (直接打开今天)
            Material(
              color: Theme.of(context).colorScheme.surface,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.15),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (todayDiary != null) {
                    context.push('/diary/edit?id=${todayDiary.id}');
                  } else {
                    context.push(
                      '/diary/edit?date=${DateTime.now().toIso8601String()}',
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.edit_note,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Add Entry button (始终触发新增逻辑块，利用 Editor 内容追加机制)
            Material(
              color: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: AppTheme.primary.withOpacity(0.4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  context.push(
                    '/diary/edit?date=${DateTime.now().toIso8601String()}',
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);
    final isEn = LocaleSettings.instance.currentLocale == AppLocale.en;

    // Header content: 年份/月份 selection
    final now = DateTime.now();
    final dateToDisplay = _selectedMonth ?? now;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Date filter
          GestureDetector(
            onTap: () => _showMonthPicker(context),
            child: Row(
              children: [
                Text(
                  _selectedMonth == null
                      ? t.diary.all_diaries
                      : '${dateToDisplay.year}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_selectedMonth != null) ...[
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    ' / ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.5,
                      ),
                    ),
                  ),
                  Text(
                    isEn
                        ? DateFormat('MMM').format(dateToDisplay)
                        : '${dateToDisplay.month}${t.common.month_suffix}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
                Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurface),
              ],
            ),
          ),

          // Right: Search and Filter (Desktop only)
          if (isDesktop)
            Row(
              children: [
                Container(
                  width: 200,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: t.common.search_hint,
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: theme.dividerColor),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.filter_list,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Filter',
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Diary diary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.diary.delete_confirm_title),
        content: Text(t.diary.delete_confirm_content),
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
}
