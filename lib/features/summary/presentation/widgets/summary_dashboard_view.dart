import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:baishou/features/summary/domain/services/context_builder.dart';
import 'package:baishou/features/summary/presentation/widgets/missing_summary_list.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:baishou/features/summary/presentation/providers/summary_filter_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SummaryDashboardView extends ConsumerStatefulWidget {
  const SummaryDashboardView({super.key});

  @override
  ConsumerState<SummaryDashboardView> createState() =>
      _SummaryDashboardViewState();
}

class _SummaryDashboardViewState extends ConsumerState<SummaryDashboardView> {
  bool _isLoading = false;
  ContextResult? _result;
  int _maxMonths = 60; // 动态计算的最大月数（至少60）

  late final TextEditingController _monthsController;
  int _lastRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    // 使用 Provider 的初始值
    final initialMonths = ref.read(summaryFilterProvider).lookbackMonths;
    _monthsController = TextEditingController(text: initialMonths.toString());
    _initRange();
  }

  @override
  void dispose() {
    _monthsController.dispose();
    super.dispose();
  }

  /// 初始化范围：获取最早数据日期，计算最大可选月数
  Future<void> _initRange() async {
    final oldestDate = await ref
        .read(diaryRepositoryProvider)
        .getOldestDiaryDate();
    if (oldestDate != null) {
      final now = DateTime.now();
      final int diffMonths =
          (now.year - oldestDate.year) * 12 + now.month - oldestDate.month + 1;
      if (mounted) {
        setState(() {
          _maxMonths = diffMonths > 60 ? diffMonths : 60;
        });
      }
    }
    _loadContext();
  }

  /// 加载/重载白守上下文数据
  Future<void> _loadContext() async {
    setState(() => _isLoading = true);
    try {
      final months = ref.read(summaryFilterProvider).lookbackMonths;
      final result = await ref
          .read(contextBuilderProvider)
          .buildLifeBookContext(months: months);
      if (mounted) {
        setState(() {
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

  /// 复制共同回忆到剪贴板
  Future<void> _copyContext() async {
    if (_result == null) return;
    await Clipboard.setData(ClipboardData(text: _result!.text));
    if (mounted) {
      AppToast.showSuccess(context, t.summary.toast_copied);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听全局数据刷新信号
    final refreshVersion = ref.watch(dataRefreshProvider);
    // 同时监听月份变化
    ref.listen(summaryFilterProvider.select((s) => s.lookbackMonths), (
      prev,
      next,
    ) {
      if (prev != next) {
        _monthsController.text = next.toString();
        _loadContext();
      }
    });

    if (refreshVersion != _lastRefreshVersion) {
      _lastRefreshVersion = refreshVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadContext();
      });
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 统计范围选择器
          _buildRangeSelector(theme),
          const SizedBox(height: 16),

          if (_isLoading && _result == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_result == null)
            Center(
              child: FilledButton.icon(
                onPressed: _loadContext,
                icon: const Icon(Icons.refresh),
                label: Text(t.summary.load_data),
              ),
            )
          else
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 统计数据概览卡片
                    _buildStatCard(context, theme),
                    const SizedBox(height: 24),

                    // 白守·共同回忆区域
                    Text(
                      t.summary.collective_memories_title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.summary.algorithm_desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _copyContext,
                      icon: const Icon(Icons.copy),
                      label: Text(t.summary.copy_memories),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 智能补全列表
                    const MissingSummaryList(),
                  ],
                ),
                if (_isLoading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// 构建统计范围选择器（Slider + 文本显示 + 自由输入）
  Widget _buildRangeSelector(ThemeData theme) {
    final filterState = ref.watch(summaryFilterProvider);
    final currentMonths = filterState.lookbackMonths;

    // 确定 slider 的 max 值
    final sliderMax = currentMonths > _maxMonths
        ? currentMonths.toDouble()
        : _maxMonths.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.summary.range_selector,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 40,
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
                  ' M',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: currentMonths.toDouble().clamp(1.0, sliderMax),
          min: 1,
          max: sliderMax,
          divisions: sliderMax.round() > 1 ? sliderMax.round() - 1 : 1,
          activeColor: AppTheme.primary,
          onChanged: (v) {
            final val = v.round();
            _monthsController.text = val.toString();
            ref.read(summaryFilterProvider.notifier).updateLookbackMonths(val);
          },
        ),
      ],
    );
  }

  /// 构建统计数据概览卡片
  Widget _buildStatCard(BuildContext context, ThemeData theme) {
    final stats = _result!;
    final currentMonths = ref.watch(summaryFilterProvider).lookbackMonths;
    final lookback = t.summary.lookback_period(months: currentMonths);
    final title = '${t.summary.dashboard_title} ($lookback)';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  t.summary.stats_yearly,
                  stats.yearCount,
                  Colors.orange,
                ),
                _buildStatItem(
                  context,
                  t.summary.stats_quarterly,
                  stats.quarterCount,
                  Colors.amber,
                ),
                _buildStatItem(
                  context,
                  t.summary.stats_monthly,
                  stats.monthCount,
                  Colors.blue,
                ),
                _buildStatItem(
                  context,
                  t.summary.stats_weekly,
                  stats.weekCount,
                  Colors.cyan,
                ),
                _buildStatItem(
                  context,
                  t.summary.stats_daily,
                  stats.diaryCount,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
