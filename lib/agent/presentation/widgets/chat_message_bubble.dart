// 聊天消息气泡组件
//
// 包含：用户消息、AI 回复（Markdown）、工具结果（可折叠卡片）、
//       流式输出气泡

import 'dart:io';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
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

    // 工具结果消息不在这里渲染（由 ToolResultGroup 处理）
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

  /// 格式化时间戳
  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  /// 用户消息 — 右对齐，primary 底色，右上角方角，配用户头像
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
              // 用户名称 + 时间戳
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
              // 消息气泡
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
              // 操作按钮行
              _MessageActionBar(
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
        // 用户头像
        _buildUserAvatar(theme, userProfile),
      ],
    );
  }

  /// 构建用户头像
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

  /// AI 消息 — 左对齐，轻阴影（无边框），左上角方角，配头像
  Widget _buildAiBubble(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI 头像
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.smart_toy_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        // 消息内容
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 角色标签 + 时间戳
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
              // 消息气泡 — 轻阴影替代边框
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
                  ),
                ),
              ),
              // 操作按钮行
              _MessageActionBar(
                isUser: false,
                alignment: MainAxisAlignment.start,
                onRegenerate: onRegenerate,
                onCopy: onCopy ?? () => _copyToClipboard(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 复制消息内容到剪贴板
  void _copyToClipboard(BuildContext context) {
    final content = message.content ?? '';
    if (content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: content));
    AppToast.showSuccess(context, t.common.copied);
  }
}

// ─── 消息操作按钮行 ─────────────────────────────────────────────

/// 28px 圆角方块，半透明背景
class _MessageActionBar extends StatelessWidget {
  final bool isUser;
  final MainAxisAlignment alignment;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onResend;
  final VoidCallback? onCopy;

  const _MessageActionBar({
    required this.isUser,
    required this.alignment,
    this.onEdit,
    this.onRegenerate,
    this.onResend,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 重发（仅用户消息）
          if (isUser && onResend != null)
            _ActionButton(
              icon: Icons.refresh_rounded,
              tooltip: t.agent.chat.retry,
              onTap: onResend!,
              theme: theme,
            ),
          // 编辑（仅用户消息）
          if (isUser && onEdit != null)
            _ActionButton(
              icon: Icons.edit_outlined,
              tooltip: t.common.edit,
              onTap: onEdit!,
              theme: theme,
            ),
          // 重新生成（仅 AI 消息）
          if (!isUser && onRegenerate != null) ...[
            _ActionButton(
              icon: Icons.refresh_rounded,
              tooltip: t.agent.chat.regenerate,
              onTap: onRegenerate!,
              theme: theme,
            ),
          ],
          // 复制（所有消息）
          if (onCopy != null)
            _ActionButton(
              icon: Icons.copy_outlined,
              tooltip: t.common.copy,
              onTap: onCopy!,
              theme: theme,
            ),
        ],
      ),
    );
  }
}

/// 单个操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: theme.colorScheme.outline),
          ),
        ),
      ),
    );
  }
}

// ─── 工具结果分组容器 ──────────────────────────────────────────

/// 将多个连续的工具结果合并到一个通知式分组容器中展示
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
          // 占位，与 AI 头像对齐
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
                      // 计数 badge
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

/// 分组内的单个工具结果项
class _ToolResultItem extends StatelessWidget {
  final ChatMessage message;

  const _ToolResultItem({required this.message});

  /// 获取工具名：优先使用 toolName 字段，其次从 callId 解析
  String _getToolName() {
    // 优先使用新字段
    if (message.toolName != null && message.toolName!.isNotEmpty) {
      return message.toolName!;
    }
    // 兼容旧数据：从 callId 解析
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 头像（与 ChatMessageBubble 一致）
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 角色标签
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    t.agent.chat.ai_label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

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
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                  ),

                // 等待中（无工具、无文本） — 跳动三点动画
                if (text.isEmpty && !hasTools)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: _BouncingDotsIndicator(),
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
    final totalTools = completedTools.length + (activeToolName != null ? 1 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.build_rounded,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t.agent.tools.tool_call,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              // 进度计数 badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${completedTools.length}/$totalTools',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 已完成的工具列表
          for (final tool in completedTools) _CompletedToolItem(tool: tool),

          // 正在执行的工具
          if (activeToolName != null) _ActiveToolItem(name: activeToolName!),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            tool.name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
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
    _opacityAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.name} ...',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 三点跳动加载指示器 ─────────────────────────────────────────

class _BouncingDotsIndicator extends StatefulWidget {
  const _BouncingDotsIndicator();

  @override
  State<_BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<_BouncingDotsIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0,
        end: -6,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // 错开启动每个点的动画
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
