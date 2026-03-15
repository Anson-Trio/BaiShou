/// 聊天消息气泡组件

import 'package:baishou/agent/models/chat_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final isTool = message.role == MessageRole.tool;

    // 工具结果消息 — 紧凑展示
    if (isTool) {
      return _buildToolResultBubble(context, theme);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isUser
                  ? Text(
                      message.content ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : MarkdownBody(
                      data: message.content ?? '',
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyMedium,
                        code: theme.textTheme.bodySmall?.copyWith(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerLow,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildToolResultBubble(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message.content?.length != null &&
                        message.content!.length > 100
                    ? '${message.content!.substring(0, 100)}...'
                    : message.content ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 流式文本气泡（打字机效果）
class StreamingBubble extends StatelessWidget {
  final String text;
  final String? activeToolName;

  const StreamingBubble({
    super.key,
    required this.text,
    this.activeToolName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeToolName != null)
                  _buildToolCallIndicator(context, theme),
                if (text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: MarkdownBody(
                      data: text,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                if (text.isEmpty && activeToolName == null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCallIndicator(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '调用 $activeToolName ...',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
