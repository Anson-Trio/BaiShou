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

    final isCompanion = ref.watch(agentCompanionModeProvider);
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
              final notifier = ref.read(agentCompanionModeProvider.notifier);
              await notifier.toggle();
              // 切换模式后重新加载对应的 session
              final chatNotifier = ref.read(agentChatProvider.notifier);
              if (!isCompanion) {
                // 从会话模式切到陪伴模式：加载伴侣会话
                chatNotifier.loadSession(SessionManager.companionSessionId);
              } else {
                // 从陪伴模式切到会话模式：清空当前聊天，让 AgentMainPage 加载会话列表
                chatNotifier.clearChat();
              }
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
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.agent.chat.start_chat,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.agent.chat.empty_hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 将原始错误信息转换为用户友好的提示
  String _friendlyError(String raw) {
    // 使用正则匹配 HTTP 状态码（避免误匹配端口号/时间戳等）
    final statusMatch = RegExp(r'(?:status\s*(?:code)?|HTTP)\s*:?\s*(\d{3})').firstMatch(raw);
    final statusCode = statusMatch != null ? int.tryParse(statusMatch.group(1)!) : null;

    String? friendly;
    if (statusCode != null) {
      if (statusCode == 400) friendly = t.agent.chat.err_format;
      if (statusCode == 401 || statusCode == 403) friendly = t.agent.chat.err_unauthorized;
      if (statusCode == 429) friendly = t.agent.chat.err_too_many_requests;
      if (statusCode >= 500 && statusCode <= 503) friendly = t.agent.chat.err_server;
    }
    if (raw.contains('timeout') || raw.contains('TimeoutException')) {
      friendly = t.agent.chat.err_timeout;
    }
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      friendly = t.agent.chat.err_network;
    }

    // 拼接友好提示 + 原始错误（方便排查）
    final truncated = raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;
    return friendly != null ? '$friendly\n$truncated' : truncated;
  }

  /// 将消息列表预处理为展示项
  /// 
  /// 核心逻辑：把 「空内容 assistant(toolCalls) + tool 结果」 这种连续序列
  /// 合并为一个 _ToolGroup，这样多次工具调用不会拆分成多个独立卡片。
  ///
  /// 同时从 assistant 的 toolCalls 中提取工具名，回填到 tool 结果消息上
  /// （兼容旧数据）。
  List<Object> _buildDisplayItems(AgentChatState chatState) {
    final items = <Object>[];
    final messages = chatState.messages;

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];

      // 检测到空内容 assistant（仅包含 toolCalls）或 tool 消息
      // → 开始收集一组工具调用
      if (_isToolRelated(msg)) {
        final toolGroup = <ChatMessage>[];

        while (i < messages.length && _isToolRelated(messages[i])) {
          final current = messages[i];

          if (current.role == MessageRole.assistant &&
              current.toolCalls != null &&
              current.toolCalls!.isNotEmpty) {
            // 这是一个空内容 assistant 消息，包含 toolCalls 信息
            // 向后查找对应的 tool 结果并回填工具名
            final callMap = {
              for (final call in current.toolCalls!) call.id: call.name
            };

            // 向后扫描紧邻的 tool 消息
            i++;
            while (i < messages.length &&
                messages[i].role == MessageRole.tool) {
              final toolMsg = messages[i];
              // 如果 toolName 为空，从 callMap 中回填
              if (toolMsg.toolName == null || toolMsg.toolName!.isEmpty) {
                final resolvedName =
                    callMap[toolMsg.toolCallId] ?? toolMsg.toolName;
                // 创建带工具名的副本（避免修改原对象）
                toolGroup.add(ChatMessage(
                  id: toolMsg.id,
                  role: toolMsg.role,
                  content: toolMsg.content,
                  toolCallId: toolMsg.toolCallId,
                  toolName: resolvedName,
                  timestamp: toolMsg.timestamp,
                ));
              } else {
                toolGroup.add(toolMsg);
              }
              i++;
            }
            // 不 i++，因为 while 已经移动了
          } else if (current.role == MessageRole.tool) {
            // 单独的 tool 消息（没有前置 assistant）
            toolGroup.add(current);
            i++;
          } else {
            break;
          }
        }

        if (toolGroup.isNotEmpty) {
          items.add(_ToolGroup(toolGroup));
        }
        // i 现在指向下一个非工具消息，但 for 的 i++ 还会执行，所以回退一步
        i--;
      } else {
        items.add(msg);
      }
    }
    return items;
  }

  /// 判断消息是否属于工具调用序列的一部分
  bool _isToolRelated(ChatMessage msg) {
    if (msg.role == MessageRole.tool) return true;
    if (msg.role == MessageRole.assistant &&
        (msg.content == null || msg.content!.trim().isEmpty) &&
        msg.toolCalls != null &&
        msg.toolCalls!.isNotEmpty) {
      return true;
    }
    return false;
  }
}

/// 连续工具消息的分组标记
class _ToolGroup {
  final List<ChatMessage> messages;
  const _ToolGroup(this.messages);
}

