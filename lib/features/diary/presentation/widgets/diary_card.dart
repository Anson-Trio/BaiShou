import 'dart:io';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// 日记 card 组件
/// 在列表中展示单篇日记的摘要信息，适配瀑布流的圆角阴影卡片风格。
class DiaryCard extends StatefulWidget {
  final Diary diary; // 日记实体数据
  final VoidCallback? onDelete; // 删除操作的回调
  final void Function(Diary updated)? onUpdated; // 编辑成功后的回调（内存直挺）

  const DiaryCard({
    super.key,
    required this.diary,
    this.onDelete,
    this.onUpdated,
  });

  @override
  State<DiaryCard> createState() => _DiaryCardState();
}

class _DiaryCardState extends State<DiaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24), // 变体3使用了大圆角 2xl / 24px
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
          border: Border.all(
            color: isDark
                ? theme.dividerColor.withOpacity(0.2)
                : theme.dividerColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final result = await context.push<Diary?>(
                  '/diary/edit?id=${widget.diary.id}',
                );
                if (result != null) {
                  widget.onUpdated?.call(result);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== Header: Day, Weekday, Time =====
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              DateFormat('dd').format(widget.diary.date),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.common.weekdays[widget
                                          .diary
                                          .date
                                          .weekday],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.2),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        '${widget.diary.date.year} · ${t.common.months[widget.diary.date.month - 1]}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 可以预留天气图标位置
                        Icon(
                          Icons.notes_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(
                            0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ===== Markdown content =====
                    Flexible(
                      child: ClipRect(
                        child: MarkdownBody(
                          data: widget.diary.content,
                          selectable: false,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: theme.textTheme.bodyLarge?.color
                                  ?.withOpacity(0.9),
                            ),
                            h1: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                              height: 1.4,
                            ),
                            h2: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                              height: 1.4,
                            ),
                            h3: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                              height: 1.4,
                            ),
                            h4: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                              height: 1.4,
                            ),
                            h5: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary.withOpacity(0.8),
                              height: 1.6,
                            ),
                            h6: TextStyle(
                              // 旧的时间戳样式兼容
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 255, 173, 218),
                              height: 1.6,
                            ),
                            listBullet: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                            blockSpacing: 12,
                            blockquoteDecoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                              border: Border(
                                left: BorderSide(
                                  color: AppTheme.primary.withOpacity(0.5),
                                  width: 3,
                                ),
                              ),
                            ),
                            blockquotePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ===== Tags =====
                    if (widget.diary.tags
                        .where((t) => t.trim().isNotEmpty)
                        .isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.diary.tags
                            .where((t) => t.trim().isNotEmpty)
                            .map((tag) {
                              // 生成伪随机柔和标签背景色
                              final colors = isDark
                                  ? [
                                      Colors.blue[900]!.withOpacity(0.3),
                                      Colors.green[900]!.withOpacity(0.3),
                                      Colors.orange[900]!.withOpacity(0.3),
                                      Colors.purple[900]!.withOpacity(0.3),
                                    ]
                                  : [
                                      Colors.blue[50],
                                      Colors.green[50],
                                      Colors.orange[50],
                                      Colors.purple[50],
                                    ];
                              final fgColors = isDark
                                  ? [
                                      Colors.blue[300],
                                      Colors.green[300],
                                      Colors.orange[300],
                                      Colors.purple[300],
                                    ]
                                  : [
                                      Colors.blue[700],
                                      Colors.green[700],
                                      Colors.orange[700],
                                      Colors.purple[700],
                                    ];
                              final idx =
                                  tag.codeUnits.fold(0, (a, b) => a + b) %
                                  colors.length;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors[idx],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: fgColors[idx],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ],

                    // ===== Actions divider (Hover reveal on Desktop, Always on Mobile) =====
                    Builder(
                      builder: (context) {
                        bool isMobile = false;
                        try {
                          if (Platform.isAndroid || Platform.isIOS) {
                            isMobile = true;
                          }
                        } catch (e) {}

                        return AnimatedOpacity(
                          opacity: (_isHovered || isMobile) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 20),
                              Divider(
                                color: theme.dividerColor.withOpacity(0.3),
                                height: 1,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final result = await context.push<Diary?>(
                                        '/diary/edit?id=${widget.diary.id}',
                                      );
                                      if (result != null) {
                                        widget.onUpdated?.call(result);
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          theme.colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      t.common.edit,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: widget.onDelete,
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      t.common.delete,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
