/// Agent 聊天页面
///
/// 全屏覆盖路由，包含消息列表和输入框

import 'package:baishou/features/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/features/agent/presentation/widgets/chat_input_bar.dart';
import 'package:baishou/features/agent/presentation/widgets/chat_message_bubble.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent 对话'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (chatState.sessionId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '新对话',
              onPressed: () {
                ref.read(agentChatProvider.notifier).clearChat();
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
                    itemCount: chatState.messages.length +
                        (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 流式输出气泡在末尾
                      if (index == chatState.messages.length &&
                          chatState.isLoading) {
                        return StreamingBubble(
                          text: chatState.streamingText,
                          activeToolName: chatState.activeToolName,
                          completedTools: chatState.completedTools,
                        );
                      }

                      final message = chatState.messages[index];
                      // 不显示 system 消息
                      if (message.role.name == 'system') {
                        return const SizedBox.shrink();
                      }
                      return ChatMessageBubble(message: message);
                    },
                  ),
          ),

          // 错误提示
          if (chatState.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 输入框
          ChatInputBar(
            isLoading: chatState.isLoading,
            onSend: (text) {
              ref.read(agentChatProvider.notifier).sendMessage(
                    text: text,
                    vaultName: 'default',
                    vaultPath: '', // TODO: 从 StoragePathService 获取
                  );
            },
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
            '开始和 Agent 对话',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '试试问：「我这周写了什么日记？」',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
