/// 聊天输入框组件

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
  final _focusNode = FocusNode();

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
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                // 桌面端：Enter 发送，Shift+Enter 换行
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _handleSend();
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.isLoading ? null : _handleSend,
            icon: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: theme.colorScheme.primary,
                  ),
            style: IconButton.styleFrom(
              backgroundColor: widget.isLoading
                  ? Colors.transparent
                  : theme.colorScheme.primaryContainer.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
