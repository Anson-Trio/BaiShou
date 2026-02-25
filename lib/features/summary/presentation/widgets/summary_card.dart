import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

class SummaryCard extends StatelessWidget {
  final Summary summary;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const SummaryCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 标题逻辑
    String title;
    switch (summary.type) {
      case SummaryType.weekly:
        title = t.summary.title_weekly(
          range:
              '${DateFormat('MM.dd').format(summary.startDate)} - ${DateFormat('MM.dd').format(summary.endDate)}',
        );
        break;
      case SummaryType.monthly:
        title = t.summary.title_monthly(
          year: summary.startDate.year.toString(),
          month: summary.startDate.month.toString(),
        );
        break;
      case SummaryType.quarterly:
        final month = summary.startDate.month;
        final q = (month / 3).ceil();
        title = t.summary.title_quarterly(
          year: summary.startDate.year.toString(),
          q: q.toString(),
        );
        break;
      case SummaryType.yearly:
        title = t.summary.title_yearly(year: summary.startDate.year.toString());
        break;
    }

    return Card(
      elevation: 2,
      shadowColor: isDark ? Colors.black26 : Colors.black12,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTypeLabel(summary.type),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(summary.generatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 标题
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),

              // 内容预览
              SizedBox(
                height: 150, // 固定高度
                width: double.infinity,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.7, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), // 禁止滚动
                    child: MarkdownBody(
                      data: summary.content.length > 1000
                          ? '${summary.content.substring(0, 1000)}...'
                          : summary.content, // 截断过长内容以优化性能
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 操作
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: theme.disabledColor,
                      onPressed: onDelete,
                      tooltip: t.common.delete,
                    ),
                ],
              ),
            ],
          ),
        ),
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
