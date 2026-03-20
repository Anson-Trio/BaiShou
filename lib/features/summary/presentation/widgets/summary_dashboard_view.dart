import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';

import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/services/context_builder.dart';
import 'package:baishou/features/summary/presentation/widgets/missing_summary_list.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:baishou/features/summary/presentation/providers/summary_filter_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// 记忆仪表盘 — 按参考图重构
///
/// 结构：
/// - 顶部：面板 / 记忆画廊 标签切换（Chrome 风格）
/// - 面板页：顶部横幅 + 双栏卡片（共同回忆 / 统计面板）+ AI 建议补全
/// - 画廊页：标签（周度/月度/季度/年度）+ 列表/详情双栏
class SummaryDashboardView extends ConsumerStatefulWidget {
  const SummaryDashboardView({super.key});

  @override
  ConsumerState<SummaryDashboardView> createState() =>
      _SummaryDashboardViewState();
}

class _SummaryDashboardViewState extends ConsumerState<SummaryDashboardView>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  ContextResult? _result;

  // 全量统计
  int _totalDiaryCount = 0;
  int _totalWeeklyCount = 0;
  int _totalMonthlyCount = 0;
  int _totalQuarterlyCount = 0;
  int _totalYearlyCount = 0;

  late final TabController _mainTabController; // 面板 / 画廊 切换
  late final TabController _galleryTabController; // 周/月/季/年
  int _lastRefreshVersion = 0;
  int _maxMonths = 60;

  late final TextEditingController _monthsController;

  // 记忆画廊选中的 summary
  Summary? _selectedSummary;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _galleryTabController = TabController(length: 4, vsync: this);
    _galleryTabController.addListener(() {
      if (!_galleryTabController.indexIsChanging) {
        setState(() => _selectedSummary = null);
      }
    });

    final initialMonths = ref.read(summaryFilterProvider).lookbackMonths;
    _monthsController = TextEditingController(text: initialMonths.toString());

    _loadAllData();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _galleryTabController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  /// 加载全量统计 + 共同回忆
  Future<void> _loadAllData() async {
    // 等待影子索引库初始化完成后再加载数据
    final dbState = ref.read(shadowIndexDatabaseProvider);
    if (dbState is! AsyncData) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 加载全量统计（不受月份过滤）
      final summaryRepo = ref.read(summaryRepositoryProvider);
      final allSummaries = await summaryRepo.getSummaries();

      int wc = 0, mc = 0, qc = 0, yc = 0;
      for (final s in allSummaries) {
        switch (s.type) {
          case SummaryType.weekly:
            wc++;
          case SummaryType.monthly:
            mc++;
          case SummaryType.quarterly:
            qc++;
          case SummaryType.yearly:
            yc++;
        }
      }

      // 日记总数
      final diaryRepo = ref.read(diaryRepositoryProvider);
      final allDiaries = await diaryRepo.getAllDiaries();
      final diaryTotal = allDiaries.length;

      // 共同回忆数据
      final months = ref.read(summaryFilterProvider).lookbackMonths;
      final result = await ref
          .read(contextBuilderProvider)
          .buildLifeBookContext(months: months);

      if (mounted) {
        setState(() {
          _totalWeeklyCount = wc;
          _totalMonthlyCount = mc;
          _totalQuarterlyCount = qc;
          _totalYearlyCount = yc;
          _totalDiaryCount = diaryTotal;
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, '${t.summary.load_failed}: $e');
      }
    }
  }

  Future<void> _copyContext() async {
    if (_result == null) return;
    final prefix = ref.read(summaryFilterProvider).copyContextPrefix;
    final textToCopy =
        prefix.isEmpty ? _result!.text : "$prefix\n\n${_result!.text}";
    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (mounted) {
      AppToast.showSuccess(context, t.summary.toast_copied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refreshVersion = ref.watch(dataRefreshProvider);
    // 监听影子索引库状态，初始化完成后加载数据
    ref.listen(shadowIndexDatabaseProvider, (previous, next) {
      if (next is AsyncData) {
        _loadAllData();
      }
    });
    ref.listen(summaryFilterProvider.select((s) => s.lookbackMonths), (
      prev,
      next,
    ) {
      if (prev != next) {
        _monthsController.text = next.toString();
        _loadAllData();
      }
    });
    if (refreshVersion != _lastRefreshVersion) {
      _lastRefreshVersion = refreshVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAllData();
      });
    }

    final theme = Theme.of(context);

    if (_isLoading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Chrome 风格标签栏
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _mainTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: t.summary.panel_tab),
                    Tab(text: t.summary.memory_gallery),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: t.settings.summary_settings_tooltip,
                  onPressed: () => context.push('/settings/summary'),
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 标签内容
        Expanded(
          child: TabBarView(
            controller: _mainTabController,
            children: [
              _buildPanelView(theme),
              _buildGalleryView(theme),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 面板页
  // ═══════════════════════════════════════════════════════

  Widget _buildPanelView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroBanner(theme),
          const SizedBox(height: 24),
          _buildDualCards(theme),
          const SizedBox(height: 24),
          _buildAISuggestionsSection(theme),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 1. 顶部横幅（简化版 — 无按钮无标签）
  // ═══════════════════════════════════════════════════════

  Widget _buildHeroBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F7DF9), Color(0xFF6C5CE7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F7DF9).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t.common.app_title} · ${t.summary.collective_memories_title}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.summary.algorithm_desc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 2. 双栏卡片
  // ═══════════════════════════════════════════════════════

  Widget _buildDualCards(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSharedMemoryCard(theme)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatsCard(theme)),
            ],
          );
        }
        return Column(
          children: [
            _buildSharedMemoryCard(theme),
            const SizedBox(height: 16),
            _buildStatsCard(theme),
          ],
        );
      },
    );
  }

  /// 共同回忆卡片（含滑块选择范围）
  Widget _buildSharedMemoryCard(ThemeData theme) {
    final filterState = ref.watch(summaryFilterProvider);
    final currentMonths = filterState.lookbackMonths;
    final sliderMax = currentMonths > _maxMonths
        ? currentMonths.toDouble()
        : _maxMonths.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded,
                  size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                '${t.common.app_title} · ${t.summary.shared_memory}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.summary.shared_memory_desc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_result != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniStatBadge(Icons.book_rounded, _result!.diaryCount, t.summary.stats_daily, Colors.green),
                _buildMiniStatBadge(Icons.view_week_rounded, _result!.weekCount, t.summary.stats_weekly, Colors.indigo),
                _buildMiniStatBadge(Icons.grid_view_rounded, _result!.monthCount, t.summary.stats_monthly, Colors.blue),
                _buildMiniStatBadge(Icons.date_range_rounded, _result!.quarterCount, t.summary.stats_quarterly, Colors.amber.shade700),
                _buildMiniStatBadge(Icons.calendar_today_rounded, _result!.yearCount, t.summary.stats_yearly, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // 滑块选择范围
          Row(
            children: [
              Text(
                t.summary.range_selector,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 36,
                child: TextField(
                  controller: _monthsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onSubmitted: (v) {
                    final val = int.tryParse(v);
                    if (val != null && val > 0) {
                      ref
                          .read(summaryFilterProvider.notifier)
                          .updateLookbackMonths(val);
                    } else {
                      _monthsController.text = currentMonths.toString();
                    }
                  },
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
              Text(
                t.summary.month_unit,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: currentMonths.toDouble().clamp(1.0, sliderMax),
            min: 1,
            max: sliderMax,
            activeColor: AppTheme.primary,
            onChanged: (v) {
              final val = v.round();
              if (val != currentMonths) {
                _monthsController.text = val.toString();
                ref
                    .read(summaryFilterProvider.notifier)
                    .updateLookbackMonths(val);
              }
            },
          ),
          const SizedBox(height: 8),

          // 复制按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _copyContext,
              icon: const Icon(Icons.copy, size: 16),
              label: Text(t.summary.copy_memories),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 白守统计面板（全量统计，含日记）
  Widget _buildStatsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded,
                  size: 20, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                '${t.common.app_title} · ${t.summary.stats_panel}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 统计项
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      theme,
                      icon: Icons.book_rounded,
                      count: _totalDiaryCount,
                      label: t.summary.stats_daily,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      theme,
                      icon: Icons.view_week_rounded,
                      count: _totalWeeklyCount,
                      label: t.summary.stats_weekly,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      theme,
                      icon: Icons.grid_view_rounded,
                      count: _totalMonthlyCount,
                      label: t.summary.stats_monthly,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatTile(
                      theme,
                      icon: Icons.date_range_rounded,
                      count: _totalQuarterlyCount,
                      label: t.summary.stats_quarterly,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatTile(
                theme,
                icon: Icons.calendar_today_rounded,
                count: _totalYearlyCount,
                label: t.summary.stats_yearly,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    ThemeData theme, {
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                count.toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 3. AI 建议补全
  // ═══════════════════════════════════════════════════════

  Widget _buildAISuggestionsSection(ThemeData theme) {
    return const MissingSummaryList();
  }

  // ═══════════════════════════════════════════════════════
  // 画廊页
  // ═══════════════════════════════════════════════════════

  Widget _buildGalleryView(ThemeData theme) {
    return Column(
      children: [
        // 标签栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _galleryTabController,
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 2,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  dividerHeight: 0,
                  tabAlignment: TabAlignment.start,
                  splashBorderRadius: BorderRadius.circular(8),
                  tabs: [
                    Tab(text: t.summary.tab_weekly),
                    Tab(text: t.summary.tab_monthly),
                    Tab(text: t.summary.tab_quarterly),
                    Tab(text: t.summary.tab_yearly),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 画廊内容
        Expanded(
          child: TabBarView(
            controller: _galleryTabController,
            children: [
              _GalleryTab(
                type: SummaryType.weekly,
                selectedSummary: _selectedSummary,
                onSelect: (s) => setState(() => _selectedSummary = s),
                onDelete: () => setState(() => _selectedSummary = null),
              ),
              _GalleryTab(
                type: SummaryType.monthly,
                selectedSummary: _selectedSummary,
                onSelect: (s) => setState(() => _selectedSummary = s),
                onDelete: () => setState(() => _selectedSummary = null),
              ),
              _GalleryTab(
                type: SummaryType.quarterly,
                selectedSummary: _selectedSummary,
                onSelect: (s) => setState(() => _selectedSummary = s),
                onDelete: () => setState(() => _selectedSummary = null),
              ),
              _GalleryTab(
                type: SummaryType.yearly,
                selectedSummary: _selectedSummary,
                onSelect: (s) => setState(() => _selectedSummary = s),
                onDelete: () => setState(() => _selectedSummary = null),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatBadge(IconData icon, int count, String label, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 画廊标签页（列表 + 详情双栏）
// ═══════════════════════════════════════════════════════

class _GalleryTab extends ConsumerWidget {
  final SummaryType type;
  final Summary? selectedSummary;
  final ValueChanged<Summary> onSelect;
  final VoidCallback? onDelete;

  const _GalleryTab({
    required this.type,
    required this.selectedSummary,
    required this.onSelect,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryStream =
        ref.watch(summaryRepositoryProvider).watchSummaries(type);

    return StreamBuilder<List<Summary>>(
      stream: summaryStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final summaries = snapshot.data!;
        if (summaries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_outlined,
                    size: 48, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Text(
                  t.summary.no_summary_type(type: _typeLabel(type)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final selected = selectedSummary != null &&
                    summaries.any((s) => s.id == selectedSummary!.id)
                ? selectedSummary
                : summaries.first;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 280,
                    child: _buildList(context, theme, summaries, selected),
                  ),
                  Container(
                    width: 1,
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: selected != null
                        ? _buildDetail(context, ref, theme, selected)
                        : const SizedBox(),
                  ),
                ],
              );
            }
            return _buildList(context, theme, summaries, selected);
          },
        );
      },
    );
  }

  Widget _buildList(BuildContext context, ThemeData theme,
      List<Summary> summaries, Summary? selected) {
    return ListView.builder(
      padding: const EdgeInsets.only(right: 8, top: 8),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final s = summaries[index];
        final isSelected = selected?.id == s.id;
        return _GalleryListItem(
          summary: s,
          isSelected: isSelected,
          onTap: () => onSelect(s),
        );
      },
    );
  }

  Widget _buildDetail(
      BuildContext context, WidgetRef ref, ThemeData theme, Summary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _typeLabel(type),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatTitle(summary),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded),
                tooltip: t.common.edit,
                onPressed: () {
                  context.push('/diary/edit?summaryId=${summary.id}');
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: t.common.delete,
                color: Colors.red.shade400,
                onPressed: () => _confirmDelete(context, ref, summary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          MarkdownBody(
            data: summary.content,
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
              h1: theme.textTheme.titleLarge,
              h2: theme.textTheme.titleMedium,
              h3: theme.textTheme.titleSmall,
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Summary summary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.common.delete),
        content: Text(t.summary.delete_confirm(title: _formatTitle(summary))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(summaryRepositoryProvider).deleteSummary(summary.id);
              ref.read(dataRefreshProvider.notifier).refresh();
              onDelete?.call();
            },
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }

  String _typeLabel(SummaryType type) {
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

  String _formatTitle(Summary summary) {
    switch (summary.type) {
      case SummaryType.weekly:
        return '${DateFormat('M月d日').format(summary.startDate)} - ${DateFormat('M月d日').format(summary.endDate)}';
      case SummaryType.monthly:
        return '${summary.startDate.year}年${summary.startDate.month}月';
      case SummaryType.quarterly:
        final q = (summary.startDate.month / 3).ceil();
        return '${summary.startDate.year}年 Q$q';
      case SummaryType.yearly:
        return '${summary.startDate.year}年';
    }
  }
}

// ─── 画廊列表项 ────────────────────────────────────────────────

class _GalleryListItem extends StatelessWidget {
  final Summary summary;
  final bool isSelected;
  final VoidCallback onTap;

  const _GalleryListItem({
    required this.summary,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String title;
    String dateStr;
    switch (summary.type) {
      case SummaryType.weekly:
        final weekNum = _weekNumber(summary.startDate);
        title = t.summary.card_week_title(week: weekNum.toString());
        dateStr = t.summary.card_date_range(
          start: DateFormat('M/d').format(summary.startDate),
          end: DateFormat('M/d').format(summary.endDate),
        );
      case SummaryType.monthly:
        title = t.summary.card_month_title(month: summary.startDate.month.toString());
        dateStr = t.summary.card_year_suffix(year: summary.startDate.year.toString());
      case SummaryType.quarterly:
        final q = (summary.startDate.month / 3).ceil();
        title = '${t.common.quarter_prefix}$q';
        dateStr = t.summary.card_year_suffix(year: summary.startDate.year.toString());
      case SummaryType.yearly:
        title = t.summary.card_year_suffix(year: summary.startDate.year.toString());
        dateStr = '';
    }

    // 标题化的预览（取第一行有内容的文本）
    final lines = summary.content.split('\n');
    String preview = '';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        // 移除 markdown 标记
        preview = trimmed
            .replaceAll(RegExp(r'[*_~`]'), '')
            .replaceAll(RegExp(r'^\s*[-•]\s*'), '');
        break;
      } else if (trimmed.startsWith('#')) {
        preview = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        break;
      }
    }
    if (preview.length > 60) preview = '${preview.substring(0, 60)}...';

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2, left: 8, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border(
                    left: BorderSide(
                      color: AppTheme.primary,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final diff = date.difference(firstDayOfYear).inDays;
    return (diff / 7).ceil();
  }
}
