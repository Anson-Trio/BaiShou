import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
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
        // 如果需要则计算周数，或者使用格式化的日期范围
        title =
            '周记 (${DateFormat('MM.dd').format(summary.startDate)} - ${DateFormat('MM.dd').format(summary.endDate)})';
        break;
      case SummaryType.monthly:
        title = '${DateFormat('yyyy年MM月').format(summary.startDate)} 月报';
        break;
      case SummaryType.quarterly:
        // 季度计算
        final month = summary.startDate.month;
        final q = (month / 3).ceil();
        title = '${summary.startDate.year}年 Q$q 季度总结';
        break;
      case SummaryType.yearly:
        title = '${summary.startDate.year} 年度总结';
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
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
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
                  child: MarkdownBody(
                    data: summary.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                      tooltip: '删除',
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
        return '周记';
      case SummaryType.monthly:
        return '月报';
      case SummaryType.quarterly:
        return '季报';
      case SummaryType.yearly:
        return '年鉴';
    }
  }
}
