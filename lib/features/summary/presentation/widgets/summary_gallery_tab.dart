/// 记忆画廊标签页
///
/// 按类型（周/月/季/年）展示总结列表 + 详情双栏

import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// 画廊标签页（列表 + 详情双栏）
class GalleryTab extends ConsumerWidget {
  final SummaryType type;
  final Summary? selectedSummary;
  final ValueChanged<Summary> onSelect;
  final VoidCallback? onDelete;

  const GalleryTab({
    super.key,
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
                  t.summary.no_summary_type(type: typeLabel(type)),
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
        return GalleryListItem(
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
                  typeLabel(type),
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
                  formatTitle(summary),
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
        content: Text(t.summary.delete_confirm(title: formatTitle(summary))),
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

  static String typeLabel(SummaryType type) {
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

  static String formatTitle(Summary summary) {
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

class GalleryListItem extends StatelessWidget {
  final Summary summary;
  final bool isSelected;
  final VoidCallback onTap;

  const GalleryListItem({
    super.key,
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
