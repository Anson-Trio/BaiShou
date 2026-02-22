import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/core/services/data_refresh_notifier.dart';

import 'package:baishou/features/summary/domain/services/context_builder.dart';
import 'package:baishou/features/summary/presentation/widgets/missing_summary_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final int _months = 12; // Default lookback

  int _lastRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(contextBuilderProvider)
          .buildLifeBookContext(months: _months);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, '加载失败: $e');
      }
    }
  }

  Future<void> _copyContext() async {
    if (_result == null) return;
    await Clipboard.setData(ClipboardData(text: _result!.text));
    if (mounted) {
      AppToast.showSuccess(context, '共同回忆已复制');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听全局数据刷新信号（导入/恢复后会递增）
    final refreshVersion = ref.watch(dataRefreshProvider);
    if (refreshVersion != _lastRefreshVersion) {
      _lastRefreshVersion = refreshVersion;
      // 延迟到帧结束后再刷新，避免在 build 中调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadContext();
      });
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_result == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _loadContext,
          icon: const Icon(Icons.refresh),
          label: const Text('加载数据'),
        ),
      );
    }

    final stats = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 仪表盘卡片
          _buildStatCard(context, '白守数据概览 (过去 $_months 个月)', [
            _StatItem('年度', stats.yearCount, Colors.orange),
            _StatItem('季度', stats.quarterCount, Colors.amber),
            _StatItem('月度', stats.monthCount, Colors.blue),
            _StatItem('周度', stats.weekCount, Colors.cyan),
            _StatItem('日记', stats.diaryCount, Colors.green),
          ]),
          const SizedBox(height: 24),

          // 操作按钮区域
          const Text(
            '白守•共同回忆',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '基于白守级联折叠算法，自动过滤冗余数据，构建我们共同的记忆脉络。',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _copyContext,
            icon: const Icon(Icons.copy),
            label: const Text('复制共同回忆'),
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
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    List<_StatItem> items,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items
                  .map((item) => _buildStatItem(context, item))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, _StatItem item) {
    return Column(
      children: [
        Text(
          item.count.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: item.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final int count;
  final Color color;
  _StatItem(this.label, this.count, this.color);
}
