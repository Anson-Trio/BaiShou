/// 聊天输入框组件
///
/// 现代风格：圆角边框 + focus高亮 + primary发送按钮

import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInputBar extends StatefulWidget {
  final bool isLoading;
  final ValueChanged<String> onSend;

  const ChatInputBar({
    super.key,
    required this.isLoading,
    required this.onSend,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: _handleKeyEvent,
    );
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  /// 拦截键盘事件：仅 Enter 发送，Shift/Ctrl+Enter 换行
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      if (!isShift && !isCtrl) {
        // 纯 Enter → 发送消息，拦截事件阻止换行
        _handleSend();
        return KeyEventResult.handled;
      }
      // Shift+Enter 或 Ctrl+Enter → 放行给 TextField 插入换行
    }
    return KeyEventResult.ignored;
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _hasFocus
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4),
                width: _hasFocus ? 1.5 : 1.0,
              ),
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.08),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 输入框
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: t.agent.chat.input_hint,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          isDense: true,
                          hintStyle:
                              theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    // 发送按钮
                    Padding(
                      padding: const EdgeInsets.only(
                          right: 6, bottom: 6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: widget.isLoading
                            ? Container(
                                key: const ValueKey('loading'),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerLow,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              )
                            : Material(
                                key: const ValueKey('send'),
                                color: theme.colorScheme.primary,
                                borderRadius:
                                    BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: _handleSend,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      Icons.send_rounded,
                                      size: 20,
                                      color: theme
                                          .colorScheme.onPrimary,
                                    ),
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
        ),
      ),
    );
  }
}
