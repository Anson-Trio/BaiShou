import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

/// 日记 card 组件
/// 在列表中展示单篇日记的摘要信息，使用 Markdown 直接渲染。
class DiaryCard extends StatelessWidget {
  final Diary diary; // 日记实体数据
  final VoidCallback? onDelete; // 删除操作的回调

  const DiaryCard({super.key, required this.diary, this.onDelete});

  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 内容直接渲染 Markdown
                  MarkdownBody(
                    data: diary.content,
                    selectable: false, // 列表页建议关闭选择以保持滚动手感
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      h5: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary.withOpacity(0.8),
                        height: 1.6,
                      ),
                      h6: TextStyle(
                        // 兼容旧的 6 级标题
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 255, 173, 218),
                        height: 1.6,
                      ),
                      listBullet: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      blockSpacing: 8, // 压缩段落间距
                    ),
                  ),

                  // 标签 - 仅在有非空标签时显示
                  if (diary.tags
                      .where((t) => t.trim().isNotEmpty)
                      .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: diary.tags
                          .where((t) => t.trim().isNotEmpty)
                          .map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? AppTheme.backgroundLight
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
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
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.light
                                      ? AppTheme.textSecondaryLight
                                      : AppTheme.textSecondaryDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // 头部：菜单（右上角绝对定位）
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.more_horiz, size: 18, color: Colors.grey[400]),
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.common.delete,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
