/// Emoji 选择器弹窗
///
/// 封装 emoji_picker_flutter，提供统一的 emoji 选择体验

import 'package:baishou/i18n/strings.g.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// 显示 emoji 选择器弹窗，返回选中的 emoji 字符串
Future<String?> showEmojiPickerDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.45,
        child: Column(
          children: [
            // 顶部把手
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Emoji 选择器
            Expanded(
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  Navigator.pop(ctx, emoji.emoji);
                },
                config: Config(
                  height: double.infinity,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                    columns: 8,
                    backgroundColor: Theme.of(ctx).colorScheme.surface,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Theme.of(ctx).colorScheme.surface,
                    indicatorColor: Theme.of(ctx).colorScheme.primary,
                    iconColorSelected: Theme.of(ctx).colorScheme.primary,
                    iconColor: Theme.of(ctx).colorScheme.outline,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: Theme.of(ctx).colorScheme.surface,
                    hintText: Translations.of(ctx).agent.chat.search_emoji,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
