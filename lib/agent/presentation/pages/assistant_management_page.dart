/// 伙伴管理页面
///
/// 展示所有伙伴的列表，支持创建、编辑、删除、拖动排序

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/assistant_edit_page.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssistantManagementPage extends ConsumerWidget {
  const AssistantManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final apiConfig = ref.watch(apiConfigServiceProvider);
    final assistantsAsync = ref.watch(assistantListStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.agent.assistant.management_title),
        elevation: 0,
        centerTitle: false,
      ),
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

          return ListenableBuilder(
            listenable: apiConfig,
            builder: (context, _) {
              return _ReorderableAssistantList(
                assistants: assistants,
                pinnedIds: apiConfig.pinnedAssistantIds.toSet(),
                onTap: (a) => _openEditPage(context, a),
                onTogglePin: (a) {
                  apiConfig.togglePinnedAssistant(a.id);
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
                onDelete: (a) => _confirmDelete(context, a, ref),
              );
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

  void _confirmDelete(BuildContext context, AgentAssistant assistant, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.assistant.delete_confirm_title),
        content: Text(t.agent.assistant.delete_confirm_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(sessionManagerProvider).deleteSessionsByAssistant(assistant.id);
                
                final service = ref.read(assistantServiceProvider);
                await service.deleteAssistant(assistant.id);
                
                ref.invalidate(assistantListStreamProvider);
                ref.invalidate(assistantListProvider);
              } catch (e) {
                if (context.mounted) {
                  AppToast.showError(context, '$e');
                }
              }
            },
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }
}

class _ReorderableAssistantList extends StatelessWidget {
  final List<AgentAssistant> assistants;
  final Set<String> pinnedIds;
  final ValueChanged<AgentAssistant> onTap;
  final ValueChanged<AgentAssistant> onTogglePin;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<AgentAssistant> onDelete;

  const _ReorderableAssistantList({
    required this.assistants,
    required this.pinnedIds,
    required this.onTap,
    required this.onTogglePin,
    required this.onReorder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: assistants.length,
      buildDefaultDragHandles: false,
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
          isPinned: pinnedIds.contains(assistant.id),
          onTap: () => onTap(assistant),
          onTogglePin: () => onTogglePin(assistant),
          onDelete: () => onDelete(assistant),
        );
      },
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final AgentAssistant assistant;
  final int index;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _AssistantCard({
    super.key,
    required this.assistant,
    required this.index,
    required this.isPinned,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
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
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 20,
                  color: isPinned ? colorScheme.primary : colorScheme.outline,
                ),
                tooltip: isPinned
                    ? t.agent.assistant.unpin_from_sidebar
                    : t.agent.assistant.pin_to_sidebar,
                onPressed: onTogglePin,
              ),

              PopupMenuButton<String>(
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      t.common.delete,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') onDelete();
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
