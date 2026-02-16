import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiaryCard extends StatelessWidget {
  final Diary diary;
  final VoidCallback? onDelete;

  const DiaryCard({super.key, required this.diary, this.onDelete});

  @override
  Widget build(BuildContext context) {
    // Extract title (first line) and content (rest)
    final lines = diary.content.split('\n');
    final String title = lines.isNotEmpty ? lines.first : '无标题';
    final String body = lines.length > 1
        ? lines
              .sublist(1)
              .take(3)
              .join('\n')
              .trim() // Take max 3 lines for preview
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
          // Pass ID so editor fetches specific entry
          context.push('/diary/edit?id=${diary.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20), // p-5 in Tailwind ~ 20px
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Time + Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme
                          .textSecondaryLight, // Use explicit colors or theme logic
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

              // Title
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

              // Body Preview
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.6, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 120,
                    ), // Max height ~4-5 lines
                    child: MarkdownBody(
                      data: body,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          // text-slate-600 dark:text-slate-400
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        ),
                        // Adjust other markdown styles if needed for preview
                        h1: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Tags
              // Tags - only display if there are non-empty tags
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
