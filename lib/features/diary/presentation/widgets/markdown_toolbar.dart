import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

/// Markdown 编辑工具栏
class MarkdownToolbar extends StatelessWidget {
  final bool isPreview;
  final VoidCallback onTogglePreview;
  final VoidCallback onHideKeyboard;
  final void Function(String prefix, [String suffix]) onInsertText;

  const MarkdownToolbar({
    super.key,
    required this.isPreview,
    required this.onTogglePreview,
    required this.onHideKeyboard,
    required this.onInsertText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToolButton(
                      icon: Icons.format_bold,
                      onPressed: () => onInsertText('**', '**'),
                    ),
                    _ToolButton(
                      icon: Icons.format_italic,
                      onPressed: () => onInsertText('*', '*'),
                    ),
                    _ToolButton(
                      icon: Icons.title,
                      onPressed: () => onInsertText('## '),
                    ),
                    _divider(),
                    _ToolButton(
                      icon: Icons.format_list_bulleted,
                      onPressed: () => onInsertText('- '),
                    ),
                    _ToolButton(
                      icon: Icons.check_box_outlined,
                      onPressed: () => onInsertText('- [ ] '),
                    ),
                    _divider(),
                    _ToolButton(
                      icon: Icons.link,
                      onPressed: () => onInsertText('[', '](url)'),
                    ),
                    _ToolButton(
                      icon: Icons.image,
                      onPressed: () => onInsertText('![', '](image_url)'),
                    ),
                  ],
                ),
              ),
            ),
            // 预览切换
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isPreview ? Icons.edit : Icons.menu_book_rounded,
                      color: isPreview ? AppTheme.primary : Colors.grey,
                    ),
                    onPressed: onTogglePreview,
                    tooltip: isPreview ? t.common.edit : t.common.confirm,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_hide),
                    onPressed: onHideKeyboard,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 8),
    width: 1,
    height: 20,
    color: Colors.grey[300],
  );
}

/// 工具栏按钮
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ToolButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      color: Colors.grey[600],
      iconSize: 22,
      splashRadius: 20,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
