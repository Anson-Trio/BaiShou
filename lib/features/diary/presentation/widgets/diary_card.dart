import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// 日记卡片组件
/// 在列表中展示单篇日记的摘要信息，包括日期、时间、内容预览以及标签。
class DiaryCard extends StatelessWidget {
  final Diary diary; // 日记实体数据
  final VoidCallback? onDelete; // 删除操作的回调

  const DiaryCard({super.key, required this.diary, this.onDelete});

  @override
  Widget build(BuildContext context) {
    // 提取标题（第一行）和内容（其余部分）
    final lines = diary.content.split('\n');
    final String title = (lines.isNotEmpty && lines.first.trim().isNotEmpty)
        ? lines.first
        : '无标题';
    final String body = lines.length > 1
        ? lines
              .sublist(1)
              .take(3)
              .join('\n')
              .trim() // 最多预览 3 行
        : '';

    final timeStr = DateFormat('jm').format(diary.date); // e.g. 5:08 PM

    return Card(
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          // 传递 ID，以便编辑器获取特定条目
          context.push('/diary/edit?id=${diary.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20), // p-5 in Tailwind ~ 20px
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：时间 + 菜单
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      fontFamily: 'Monospace',
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('删除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 标题
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500, // Medium
                  height: 1.4,
                  // Color handled by theme
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // 内容预览
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                  ),
                ),
              ],

              // 标签 - 仅在有非空标签时显示
              if (diary.tags.where((t) => t.trim().isNotEmpty).isNotEmpty) ...[
                const SizedBox(height: 16), // mt-4
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: diary.tags.where((t) => t.trim().isNotEmpty).map((
                    tag,
                  ) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? AppTheme.backgroundLight
                            : Colors.grey[800], // slate-100 or slate-800
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).brightness == Brightness.light
                              ? AppTheme.textSecondaryLight
                              : AppTheme.textSecondaryDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
