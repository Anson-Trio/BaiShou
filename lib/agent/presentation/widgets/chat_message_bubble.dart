/// 聊天消息气泡组件
///
/// 包含：用户消息、AI 回复（Markdown）、工具结果（可折叠卡片）

import 'dart:io';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/presentation/widgets/message_action_bar.dart';
import 'package:baishou/agent/presentation/widgets/token_badge.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ─── 消息气泡 ─────────────────────────────────────────────────

class ChatMessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onResend;
  final VoidCallback? onCopy;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onEdit,
    this.onRegenerate,
    this.onResend,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;

    if (message.role == MessageRole.tool) {
      return const SizedBox.shrink();
    }

    if (isUser) {
      final userProfile = ref.watch(userProfileProvider);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildUserBubble(context, theme, userProfile),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _buildAiBubble(context, theme),
    );
  }

  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  Widget _buildUserBubble(
    BuildContext context,
    ThemeData theme,
    UserProfile userProfile,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userProfile.nickname,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.timestamp),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  message.content ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    height: 1.5,
                  ),
                ),
              ),
              MessageActionBar(
                isUser: true,
                alignment: MainAxisAlignment.end,
                onEdit: onEdit,
                onResend: onResend,
                onCopy: onCopy ?? () => _copyToClipboard(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _buildUserAvatar(theme, userProfile),
      ],
    );
  }

  Widget _buildUserAvatar(ThemeData theme, UserProfile userProfile) {
    if (userProfile.avatarPath != null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: FileImage(File(userProfile.avatarPath!)),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          userProfile.nickname.isNotEmpty
              ? userProfile.nickname[0].toUpperCase()
              : 'U',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAiBubble(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.agent.chat.ai_label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.timestamp),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: MarkdownBody(
                  data: message.content ?? '',
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    code: theme.textTheme.bodySmall?.copyWith(
                      backgroundColor: theme.colorScheme.surfaceContainerLow,
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    codeblockPadding: const EdgeInsets.all(14),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MessageActionBar(
                    isUser: false,
                    alignment: MainAxisAlignment.start,
                    onRegenerate: onRegenerate,
                    onCopy: onCopy ?? () => _copyToClipboard(context),
                  ),
                  const Spacer(),
                  if (message.inputTokens != null)
                    TokenBadge(message: message, theme: theme),
                  if (message.contextMessages != null &&
                      message.contextMessages!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => showContextDialog(context, message),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.account_tree_outlined,
                            size: 14,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    final content = message.content ?? '';
    if (content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: content));
    AppToast.showSuccess(context, t.common.copied);
  }
}

// ─── 工具结果分组容器 ──────────────────────────────────────────

class ToolResultGroup extends StatelessWidget {
  final List<ChatMessage> messages;

  const ToolResultGroup({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 46),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  initiallyExpanded: false,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.build_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        t.agent.tools.tool_call_results(count: messages.length),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${messages.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                  children: [
                    for (final msg in messages) _ToolResultItem(message: msg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolResultItem extends StatelessWidget {
  final ChatMessage message;

  const _ToolResultItem({required this.message});

  String _getToolName() {
    if (message.toolName != null && message.toolName!.isNotEmpty) {
      return message.toolName!;
    }
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
        content.startsWith('Tool "') ||
        content.startsWith('Error');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = _getToolName();
    final content = message.content ?? '';
    final isError = _isError;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 14,
            color: isError
                ? theme.colorScheme.error
                : theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          title: Text(
            toolName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
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
