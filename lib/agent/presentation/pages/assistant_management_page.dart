/// 助手管理页面
///
/// 展示所有助手的列表，支持创建、编辑、删除

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/assistant_edit_page.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t.agent.assistant.management_title),
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
                  Icon(Icons.auto_awesome_outlined,
                      size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assistants.length,
            itemBuilder: (context, index) {
              final assistant = assistants[index];
              return _AssistantCard(
                assistant: assistant,
                onTap: () => _openEditPage(context, assistant),
                onSetDefault: () {
                  ref.read(assistantServiceProvider).setDefault(assistant.id);
                  ref.invalidate(assistantListStreamProvider);
                  ref.invalidate(defaultAssistantProvider);
                },
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
}

class _AssistantCard extends StatelessWidget {
  final AgentAssistant assistant;
  final VoidCallback onTap;
  final VoidCallback onSetDefault;

  const _AssistantCard({
    required this.assistant,
    required this.onTap,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: _getAvatar(),
                child: _getAvatar() == null
                    ? Text(
                        assistant.emoji ?? '⭐',
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
                                horizontal: 8, vertical: 2),
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
                          Icon(Icons.smart_toy_outlined, size: 12, color: colorScheme.outline),
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
