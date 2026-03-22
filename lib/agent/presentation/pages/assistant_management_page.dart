/// 伙伴管理页面
///
/// 展示所有伙伴的列表，支持创建、编辑、删除、拖动排序

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/assistant_edit_page.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssistantManagementPage extends ConsumerWidget {
  const AssistantManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final assistantsAsync = ref.watch(assistantListStreamProvider);

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isDesktop
          ? null
          : AppBar(title: Text(t.agent.assistant.management_title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditPage(context, null),
        child: const Icon(Icons.add),
      ),
      body: assistantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (assistants) {
          if (assistants.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.agent.assistant.empty_hint,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => _openEditPage(context, null),
                    child: Text(t.agent.assistant.create_first),
                  ),
                ],
              ),
            );
          }

          return _ReorderableAssistantList(
            assistants: assistants,
            onTap: (a) => _openEditPage(context, a),
            onSetDefault: (a) {
              ref.read(assistantServiceProvider).setDefault(a.id);
              ref.invalidate(assistantListStreamProvider);
              ref.invalidate(defaultAssistantProvider);
            },
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final reordered = List<AgentAssistant>.from(assistants);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);

              // 批量更新排序
              final orders = <(String, int)>[];
              for (int i = 0; i < reordered.length; i++) {
                orders.add((reordered[i].id, i));
              }
              ref.read(assistantRepositoryProvider).updateSortOrders(orders);
              ref.invalidate(assistantListStreamProvider);
            },
          );
        },
      ),
    );
  }

  void _openEditPage(BuildContext context, AgentAssistant? assistant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssistantEditPage(assistant: assistant),
      ),
    );
  }
}

class _ReorderableAssistantList extends StatelessWidget {
  final List<AgentAssistant> assistants;
  final ValueChanged<AgentAssistant> onTap;
  final ValueChanged<AgentAssistant> onSetDefault;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _ReorderableAssistantList({
    required this.assistants,
    required this.onTap,
    required this.onSetDefault,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assistants.length,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: child,
        );
      },
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final assistant = assistants[index];
        return _AssistantCard(
          key: ValueKey(assistant.id),
          assistant: assistant,
          index: index,
          onTap: () => onTap(assistant),
          onSetDefault: () => onSetDefault(assistant),
        );
      },
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final AgentAssistant assistant;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;

  const _AssistantCard({
    super.key,
    required this.assistant,
    required this.index,
    required this.onTap,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 拖拽手柄
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 20,
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 头像
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: _getAvatar(),
                child: _getAvatar() == null
                    ? Text(
                        assistant.emoji ?? '🍵',
                        style: const TextStyle(fontSize: 20),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // 名称 + 描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            assistant.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (assistant.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.agent.assistant.default_label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assistant.description.isNotEmpty
                          ? assistant.description
                          : (assistant.systemPrompt.isEmpty
                                ? t.agent.assistant.no_prompt
                                : assistant.systemPrompt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${t.agent.assistant.context_window_label}: ${assistant.contextWindow}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                        if (assistant.modelId != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 12,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              assistant.modelId!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 操作按钮
              if (!assistant.isDefault)
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'default',
                      child: Text(t.agent.assistant.set_default),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'default') onSetDefault();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _getAvatar() {
    if (assistant.avatarPath != null) {
      final file = File(assistant.avatarPath!);
      if (file.existsSync()) return FileImage(file);
    }
    return null;
  }
}
