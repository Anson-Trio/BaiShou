// 聊天消息气泡组件
//
// 包含：用户消息、AI 回复（Markdown）、工具结果（可折叠卡片）、
//       流式输出气泡（打字机效果 + 工具执行状态）

import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/features/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/features/agent/presentation/widgets/tool_result_group_card.dart';
import 'package:baishou/i18n/strings.g.dart';
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

    // 工具结果消息 — 可折叠卡片
    if (isTool) {
      return _ToolResultCard(message: message);
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
}

// ─── 工具结果卡片（可折叠） ────────────────────────────────────

class _ToolResultCard extends StatelessWidget {
  final ChatMessage message;

  const _ToolResultCard({required this.message});

  /// 从 callId 中提取工具名
  String _extractToolName() {
    final callId = message.toolCallId;
    if (callId == null) return 'tool';
    final parts = callId.split('_');
    // gemini_{name}_{timestamp}
    if (parts.length >= 3 && parts.first == 'gemini') {
      return parts.sublist(1, parts.length - 1).join('_');
    }
    // OpenAI: chatcmpl-xxx 格式，无工具名
    return 'tool';
  }

  bool get _isError {
    final content = message.content ?? '';
    return content.startsWith('Tool execution failed:') ||
        content.startsWith('Unknown tool') ||
        content.startsWith('Error');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = _extractToolName();
    final content = message.content ?? '';
    final isError = _isError;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? theme.colorScheme.error.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            childrenPadding:
                const EdgeInsets.fromLTRB(12, 0, 12, 10),
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              size: 16,
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            title: Text(
              toolName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 工具结果分组容器 ──────────────────────────────────────────

/// 将多个连续的工具结果合并到一个分组容器中展示
class ToolResultGroup extends StatelessWidget {
  final List<ChatMessage> messages;

  const ToolResultGroup({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
            dense: true,
            visualDensity: VisualDensity.compact,
            initiallyExpanded: false,
            leading: Icon(
              Icons.build_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              t.agent.tools.tool_call_results(count: messages.length),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            children: [
              for (final msg in messages)
                _ToolResultItem(message: msg),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分组内的单个工具结果项
class _ToolResultItem extends StatelessWidget {
  final ChatMessage message;

  const _ToolResultItem({required this.message});

  String _extractToolName() {
    final callId = message.toolCallId;
    if (callId == null) return 'tool';
    final parts = callId.split('_');
    if (parts.length >= 3 && parts.first == 'gemini') {
      return parts.sublist(1, parts.length - 1).join('_');
    }
    return 'tool';
  }

  bool get _isError {
    final content = message.content ?? '';
    return content.startsWith('Tool execution failed:') ||
        content.startsWith('Unknown tool') ||
        content.startsWith('Error');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = _extractToolName();
    final content = message.content ?? '';
    final isError = _isError;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 14,
            color: isError
                ? theme.colorScheme.error
                : theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          title: Text(
            toolName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 流式输出气泡 ─────────────────────────────────────────────

/// 流式文本气泡（打字机效果 + 工具执行状态）
class StreamingBubble extends StatelessWidget {
  final String text;
  final String? activeToolName;
  final List<ToolExecution> completedTools;

  const StreamingBubble({
    super.key,
    required this.text,
    this.activeToolName,
    this.completedTools = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTools = completedTools.isNotEmpty || activeToolName != null;

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
                // 工具执行分组容器
                if (hasTools)
                  _ToolExecutionGroup(
                    completedTools: completedTools,
                    activeToolName: activeToolName,
                  ),

                // 流式文本
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

                // 等待中（无工具、无文本）
                if (text.isEmpty && !hasTools)
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
}

// ─── 工具执行状态分组 ─────────────────────────────────────────

class _ToolExecutionGroup extends StatelessWidget {
  final List<ToolExecution> completedTools;
  final String? activeToolName;

  const _ToolExecutionGroup({
    required this.completedTools,
    this.activeToolName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                Icons.build_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                t.agent.tools.tool_call,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              if (completedTools.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${completedTools.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // 已完成的工具列表
          for (final tool in completedTools)
            _CompletedToolItem(tool: tool),

          // 正在执行的工具
          if (activeToolName != null)
            _ActiveToolItem(name: activeToolName!),
        ],
      ),
    );
  }
}

// ─── 已完成工具项 ──────────────────────────────────────────────

class _CompletedToolItem extends StatelessWidget {
  final ToolExecution tool;

  const _CompletedToolItem({required this.tool});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationText = tool.durationMs < 1000
        ? '${tool.durationMs}ms'
        : '${(tool.durationMs / 1000).toStringAsFixed(1)}s';

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 13,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            tool.name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 正在执行工具项（脉冲动画） ─────────────────────────────────

class _ActiveToolItem extends StatefulWidget {
  final String name;

  const _ActiveToolItem({required this.name});

  @override
  State<_ActiveToolItem> createState() => _ActiveToolItemState();
}

class _ActiveToolItemState extends State<_ActiveToolItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _opacityAnim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.name} ...',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
