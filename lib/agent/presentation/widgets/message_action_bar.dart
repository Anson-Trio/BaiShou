/// 消息操作按钮行
///
/// 28px 圆角方块：复制、编辑、重发、重新生成

import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class MessageActionBar extends StatelessWidget {
  final bool isUser;
  final MainAxisAlignment alignment;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onResend;
  final VoidCallback? onCopy;

  const MessageActionBar({
    super.key,
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
          if (isUser && onResend != null)
            _ActionButton(
              icon: Icons.refresh_rounded,
              tooltip: t.agent.chat.retry,
              onTap: onResend!,
              theme: theme,
            ),
          if (isUser && onEdit != null)
            _ActionButton(
              icon: Icons.edit_outlined,
              tooltip: t.common.edit,
              onTap: onEdit!,
              theme: theme,
            ),
          if (!isUser && onRegenerate != null) ...[
            _ActionButton(
              icon: Icons.refresh_rounded,
              tooltip: t.agent.chat.regenerate,
              onTap: onRegenerate!,
              theme: theme,
            ),
          ],
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
