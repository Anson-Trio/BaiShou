/// Agent 聊天页面
///
/// 全屏覆盖路由，包含消息列表和输入框

import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/features/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/features/agent/presentation/widgets/chat_input_bar.dart';
import 'package:baishou/features/agent/presentation/widgets/chat_message_bubble.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentChatPage extends ConsumerStatefulWidget {
  final String? sessionId;

  const AgentChatPage({super.key, this.sessionId});

  @override
  ConsumerState<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends ConsumerState<AgentChatPage> {
  final _scrollController = ScrollController();
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      // 延迟加载，等 widget 树构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(agentChatProvider.notifier)
            .loadSession(widget.sessionId!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(agentChatProvider);
    final theme = Theme.of(context);

    // 监听消息变化，自动滚动到底部
    ref.listen(agentChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.streamingText != next.streamingText) {
        _scrollToBottom();
      }
    });

    final isCompanion = ref.watch(apiConfigServiceProvider).agentCompanionMode;
    // 模式对应的暖色/冷色
    final modeColor = isCompanion
        ? const Color(0xFFD97706) // amber-600
        : theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompanion ? Icons.favorite_rounded : Icons.smart_toy_outlined,
              size: 20,
              color: modeColor,
            ),
            const SizedBox(width: 8),
            Text(
              isCompanion ? t.agent.chat.companion_mode : t.agent.chat.session_mode,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 滑块切换：深度陪伴 / 会话模式
          GestureDetector(
            onTap: () async {
              final apiConfig = ref.read(apiConfigServiceProvider);
              await apiConfig.setAgentCompanionMode(!isCompanion);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              width: 140,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: isCompanion ? 0 : 70,
                    top: 0,
                    bottom: 0,
                    width: 70,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCompanion
                            ? const Color(0xFFFEF3C7) // amber-100
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 14,
                                color: isCompanion
                                    ? const Color(0xFF92400E) // amber-800
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t.agent.sessions.companion_tab,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCompanion ? FontWeight.bold : FontWeight.normal,
                                  color: isCompanion
                                      ? const Color(0xFF92400E) // amber-800
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_rounded,
                                size: 14,
                                color: !isCompanion
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t.agent.sessions.session_tab,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: !isCompanion ? FontWeight.bold : FontWeight.normal,
                                  color: !isCompanion
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (chatState.sessionId != null && !isCompanion)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: t.agent.chat.session_settings,
              onPressed: () {
                _showSettingsDialog(context, chatState.sessionId!);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: chatState.messages.isEmpty && !chatState.isLoading
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: _buildDisplayItems(chatState).length +
                        (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      final displayItems = _buildDisplayItems(chatState);
                      // 流式输出气泡在末尾
                      if (index == displayItems.length &&
                          chatState.isLoading) {
                        return StreamingBubble(
                          text: chatState.streamingText,
                          activeToolName: chatState.activeToolName,
                          completedTools: chatState.completedTools,
                        );
                      }

                      final item = displayItems[index];
                      if (item is _ToolGroup) {
                        return ToolResultGroup(messages: item.messages);
                      }
                      final message = item as ChatMessage;
                      if (message.role.name == 'system') {
                        return const SizedBox.shrink();
                      }
                      // 如果是 AI 的消息，但只包含工具调用且内容为空，则不渲染空的文本气泡
                      if (message.role == MessageRole.assistant &&
                          (message.content == null || message.content!.trim().isEmpty)) {
                        return const SizedBox.shrink();
                      }
                      return ChatMessageBubble(message: message);
                    },
                  ),
          ),

          // 错误提示 + 重试按钮
          if (chatState.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _friendlyError(chatState.error!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: chatState.isLoading
                          ? null
                          : () {
                              ref.read(agentChatProvider.notifier).retryLast();
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(t.agent.chat.retry),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ChatInputBar(
            isLoading: chatState.isLoading,
            onSend: (text) async {
              // Now we fetch system prompt directly from db instead of the textfield
              String? guidelines;
              if (chatState.sessionId != null) {
                final session = await ref.read(sessionManagerProvider).getSession(chatState.sessionId!);
                guidelines = session?.systemPrompt;
              }
              ref.read(agentChatProvider.notifier).sendMessage(
                    text: text,
                    guidelines: guidelines,
                    vaultName: 'default',
                    vaultPath: '', // TODO: 从 StoragePathService 获取
                  );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context, String sessionId) async {
    final sessionManager = ref.read(sessionManagerProvider);
    final session = await sessionManager.getSession(sessionId);
    if (session == null) return;

    final nameController = TextEditingController(text: session.title);
    final promptController = TextEditingController(text: session.systemPrompt);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.chat.session_settings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: t.agent.chat.session_name,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: t.agent.chat.system_prompt_label,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPrompt = promptController.text.trim();
              await sessionManager.updateSessionTitle(sessionId, newName.isEmpty ? t.agent.sessions.default_title : newName);
              await sessionManager.updateSystemPrompt(sessionId, newPrompt.isEmpty ? null : newPrompt);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: Text(t.common.save),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            t.agent.chat.start_chat,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.agent.chat.empty_hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 将原始错误信息转换为用户友好的提示
  String _friendlyError(String raw) {
    if (raw.contains('400')) return t.agent.chat.err_format;
    if (raw.contains('401') || raw.contains('403')) {
      return t.agent.chat.err_unauthorized;
    }
    if (raw.contains('429')) return t.agent.chat.err_too_many_requests;
    if (raw.contains('500') || raw.contains('502') || raw.contains('503')) {
      return t.agent.chat.err_server;
    }
    if (raw.contains('timeout') || raw.contains('TimeoutException')) {
      return t.agent.chat.err_timeout;
    }
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return t.agent.chat.err_network;
    }
    // 截断过长的原始错误
    return raw.length > 150 ? '${raw.substring(0, 150)}...' : raw;
  }

  /// 将消息列表预处理为展示项（连续 tool 消息合并为 _ToolGroup）
  List<Object> _buildDisplayItems(AgentChatState chatState) {
    final items = <Object>[];
    final messages = chatState.messages;

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.role == MessageRole.tool) {
        // 收集连续的 tool 消息
        final group = <ChatMessage>[msg];
        while (i + 1 < messages.length &&
            messages[i + 1].role == MessageRole.tool) {
          i++;
          group.add(messages[i]);
        }
        items.add(_ToolGroup(group));
      } else {
        items.add(msg);
      }
    }
    return items;
  }
}

/// 连续工具消息的分组标记
class _ToolGroup {
  final List<ChatMessage> messages;
  const _ToolGroup(this.messages);
}
