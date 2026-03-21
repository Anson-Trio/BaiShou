/// 助手选择底部弹窗
///
/// 展示助手列表（头像 + 名称 + 提示词预览），支持选择或清除

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssistantPickerSheet extends ConsumerWidget {
  final String? currentAssistantId;
  final ValueChanged<AgentAssistant?> onSelect;

  const AssistantPickerSheet({
    super.key,
    this.currentAssistantId,
    required this.onSelect,
  });

  /// 静态方法：弹出选择器
  /// 返回 (是否做出了选择, 选中的助手)
  /// didSelect=false 表示用户关闭弹窗未操作
  static Future<(bool, AgentAssistant?)> show(
    BuildContext context, {
    String? currentAssistantId,
  }) async {
    bool didSelect = false;
    AgentAssistant? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => _SheetContent(
          scrollController: scrollController,
          currentAssistantId: currentAssistantId,
          onSelect: (assistant) {
            didSelect = true;
            result = assistant;
            Navigator.pop(ctx);
          },
        ),
      ),
    );
    return (didSelect, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

class _SheetContent extends ConsumerWidget {
  final ScrollController scrollController;
  final String? currentAssistantId;
  final ValueChanged<AgentAssistant?> onSelect;

  const _SheetContent({
    required this.scrollController,
    this.currentAssistantId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final assistantsAsync = ref.watch(assistantListProvider);

    return Column(
      children: [
        // 拖拽手柄
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // 标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                t.agent.assistant.select_title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 清除按钮
              if (currentAssistantId != null)
                TextButton.icon(
                  onPressed: () => onSelect(null),
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: Text(t.agent.assistant.clear_selection),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.outline,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 列表
        Expanded(
          child: assistantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assistants) {
              if (assistants.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        t.agent.assistant.empty_hint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: assistants.length,
                itemBuilder: (context, index) {
                  final a = assistants[index];
                  final isSelected =
                      currentAssistantId == a.id.toString();

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      backgroundImage: _getAvatar(a.avatarPath),
                      child: _getAvatar(a.avatarPath) == null
                          ? Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.primary,
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (a.isDefault)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.agent.assistant.default_tag,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: a.systemPrompt.isNotEmpty
                        ? Text(
                            a.systemPrompt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded,
                            color: colorScheme.primary, size: 22)
                        : null,
                    selected: isSelected,
                    selectedTileColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    onTap: () => onSelect(a),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  ImageProvider? _getAvatar(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }
}
