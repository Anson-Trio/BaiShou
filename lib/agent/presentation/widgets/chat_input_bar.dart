/// 聊天输入框组件
import 'dart:io';

import 'package:baishou/features/settings/presentation/pages/views/agent_tools_view.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInputBar extends StatefulWidget {
  final bool isLoading;
  final ValueChanged<String> onSend;
  /// 当前\u4f19\u4f34名称（显示在 chip 上）
  final String? assistantName;
  /// 点击\u4f19\u4f34 chip 的回调
  final VoidCallback? onAssistantTap;

  const ChatInputBar({
    super.key,
    required this.isLoading,
    required this.onSend,
    this.assistantName,
    this.onAssistantTap,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    widget.onSend(text);
    _controller.clear();
  }

  /// 打开工具管理页面
  /// 桌面端：弹出对话框
  /// 移动端：跳转到新页面
  void _openToolManager() {
    final isDesktop = MediaQuery.of(context).size.width >= 700 ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 600,
              maxHeight: 700,
            ),
            child: const AgentToolsView(),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(t.settings.agent_tools_title),
            ),
            body: const AgentToolsView(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        // 渐变遮罩，让消息列表滚动到底部时有平滑过渡
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.0),
            theme.colorScheme.surface.withValues(alpha: 0.8),
            theme.colorScheme.surface,
          ],
          stops: const [0.0, 0.15, 0.3],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 工具栏 — 在输入卡片上方
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _QuickActionChip(
                      icon: Icons.extension_outlined,
                      label: t.agent.tools.tool_call,
                      onTap: _openToolManager,
                    ),
                  ],
                ),
              ),

              // 主输入卡片
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hasFocus
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                    width: _hasFocus ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _hasFocus
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : theme.colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: _hasFocus ? 20 : 12,
                      spreadRadius: _hasFocus ? 2 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 附件按钮
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: IconButton(
                        onPressed: () {
                          // TODO: 附件功能
                        },
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          color: theme.colorScheme.outline,
                          size: 24,
                        ),
                        tooltip: '+',
                        splashRadius: 20,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),

                    // 输入框
                    Expanded(
                      child: Shortcuts(
                        shortcuts: <ShortcutActivator, Intent>{
                          const SingleActivator(LogicalKeyboardKey.enter,
                                  control: false, shift: false):
                              const _SendIntent(),
                        },
                        child: Actions(
                          actions: <Type, Action<Intent>>{
                            _SendIntent: CallbackAction<_SendIntent>(
                              onInvoke: (_) {
                                _handleSend();
                                return null;
                              },
                            ),
                          },
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 5,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: t.agent.chat.input_hint,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 14,
                              ),
                              isDense: true,
                              hintStyle:
                                  theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),

                    // 发送按钮
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: widget.isLoading
                            ? Container(
                                key: const ValueKey('loading'),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme
                                      .surfaceContainerLow,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                            : _SendButton(
                                key: const ValueKey('send'),
                                onTap: _handleSend,
                                theme: theme,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 发送按钮 — 带按下缩放动效
class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final ThemeData theme;

  const _SendButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.theme.colorScheme.primary
                    .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.send_rounded,
            size: 20,
            color: widget.theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// 底部快捷按钮 chip
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  /// 是否为激活状态（toggle chip 用）
  final bool isActive;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isActive
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final fgColor = isActive
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: fgColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enter 键发送 Intent
class _SendIntent extends Intent {
  const _SendIntent();
}
