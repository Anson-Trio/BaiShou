/// Token / 费用标签 + 上下文调用链弹窗
///
/// 在 AI 消息操作栏右侧显示 token 用量和费用，
/// 点击树图标可查看上下文消息列表

import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class TokenBadge extends StatelessWidget {
  final ChatMessage message;
  final ThemeData theme;

  const TokenBadge({super.key, required this.message, required this.theme});

  String _formatTokens(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final input = message.inputTokens ?? 0;
    final output = message.outputTokens ?? 0;
    final cost = message.cost;

    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '↑${_formatTokens(input)}  ↓${_formatTokens(output)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          if (cost != null && cost > 0) ...[
            const SizedBox(width: 6),
            Text(
              '\$${cost.toStringAsFixed(4)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.6),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 上下文调用链弹窗 ─────────────────────────────────────────

/// 展示实际发给 AI 的上下文消息列表弹窗
void showContextDialog(BuildContext context, ChatMessage message) {
  showDialog(
    context: context,
    builder: (ctx) => ContextChainDialog(
      message: message,
      contextMessages: message.contextMessages!,
    ),
  );
}

class ContextChainDialog extends StatelessWidget {
  final ChatMessage message;
  final List<ChatMessage> contextMessages;

  const ContextChainDialog({
    super.key,
    required this.message,
    required this.contextMessages,
  });

  String _roleLabel(Translations t, MessageRole role) {
    switch (role) {
      case MessageRole.system:
        return t.agent.chat.role_system;
      case MessageRole.user:
        return t.agent.chat.role_user;
      case MessageRole.assistant:
        return t.agent.chat.role_assistant;
      case MessageRole.tool:
        return t.agent.chat.role_tool;
    }
  }

  Color _roleColor(ThemeData theme, MessageRole role) {
    switch (role) {
      case MessageRole.system:
        return theme.colorScheme.tertiary;
      case MessageRole.user:
        return theme.colorScheme.primary;
      case MessageRole.assistant:
        return theme.colorScheme.secondary;
      case MessageRole.tool:
        return theme.colorScheme.outline;
    }
  }

  String _preview(Translations t, ChatMessage msg) {
    final content = msg.content ?? '';
    if (content.isEmpty) {
      if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
        return '→ ${msg.toolCalls!.map((tc) => tc.name).join(', ')}';
      }
      return t.agent.chat.empty_content;
    }
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 80) return cleaned;
    return '${cleaned.substring(0, 80)}…';
  }

  String _formatTokens(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = Translations.of(context);
    final input = message.inputTokens ?? 0;
    final output = message.outputTokens ?? 0;
    final cost = message.cost;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.agent.chat.context_chain,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${contextMessages.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Token/费用信息
            if (input > 0 || output > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    _InfoChip(
                      icon: Icons.arrow_upward_rounded,
                      label: '${t.agent.chat.round_input} ${_formatTokens(input)}',
                      theme: theme,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.arrow_downward_rounded,
                      label: '${t.agent.chat.round_output} ${_formatTokens(output)}',
                      theme: theme,
                    ),
                    if (cost != null && cost > 0) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.attach_money_rounded,
                        label: '${t.agent.chat.round_cost} ${cost.toStringAsFixed(6)}',
                        theme: theme,
                      ),
                    ],
                  ],
                ),
              ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            // 消息列表
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: contextMessages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final msg = contextMessages[index];
                  final roleColor = _roleColor(theme, msg.role);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showMessageDetail(context, msg, index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                '${index + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _roleLabel(t, msg.role),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: roleColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _preview(t, msg),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageDetail(
    BuildContext context,
    ChatMessage msg,
    int index,
  ) {
    final theme = Theme.of(context);
    final roleColor = _roleColor(theme, msg.role);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _roleLabel(t, msg.role),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: roleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    msg.content ?? t.agent.chat.no_content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
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

/// 信息小标签（用于 Token/费用显示）
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
