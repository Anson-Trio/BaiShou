import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/presentation/widgets/summary_card.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SummaryListView extends ConsumerWidget {
  final SummaryType type;
  final DateTime? startDate;
  final DateTime? endDate;

  const SummaryListView({
    super.key,
    required this.type,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听仓库数据流
    final summaryStream = ref
        .watch(summaryRepositoryProvider)
        .watchSummaries(type, start: startDate, end: endDate);

    return StreamBuilder<List<Summary>>(
      stream: summaryStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${t.common.error}: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final summaries = snapshot.data!;

        if (summaries.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 80),
          itemCount: summaries.length,
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return SummaryCard(
              summary: summary,
              onTap: () {
                // 导航到编辑页面（使用日记编辑器的总结模式）
                context.push('/diary/edit?summaryId=${summary.id}');
              },
              onDelete: () {
                _confirmDelete(context, ref, summary);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: AppTheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            t.summary.no_summary_type(type: _getTypeLabel(type)),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            t.summary.click_to_generate,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Summary summary) {
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
              ref.read(summaryRepositoryProvider).deleteSummary(summary.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
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
}
