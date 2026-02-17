import 'package:baishou/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// 标签输入组件
class TagInputWidget extends StatelessWidget {
  final List<String> tags;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;

  const TagInputWidget({
    super.key,
    required this.tags,
    required this.controller,
    required this.focusNode,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 现有标签
        ...tags.map(
          (tag) => Chip(
            label: Text(
              '#$tag',
              style: const TextStyle(fontSize: 12, color: AppTheme.primary),
            ),
            deleteIcon: const Icon(Icons.close, size: 14),
            deleteIconColor: AppTheme.primary.withOpacity(0.6),
            onDeleted: () => onRemoveTag(tag),
            backgroundColor: AppTheme.primary.withOpacity(0.08),
            side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
        // 新标签输入
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 13, color: AppTheme.primary),
            decoration: InputDecoration(
              hintText: '添加标签...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onSubmitted: (value) {
              // 支持逗号分隔的多标签
              final parts = value.split(RegExp(r'[,，]'));
              for (final part in parts) {
                onAddTag(part);
              }
              focusNode.requestFocus();
            },
          ),
        ),
      ],
    );
  }
}
