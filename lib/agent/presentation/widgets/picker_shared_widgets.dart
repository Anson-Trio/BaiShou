/// 伙伴选择器 - 共享 UI 组件
///
/// 头像构建、标签、Section 标题、信息卡片等可复用组件

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:flutter/material.dart';

/// 构建伙伴头像：avatarPath → emoji → 默认 icon
Widget buildAssistantAvatar(
  AgentAssistant assistant,
  ColorScheme colorScheme, {
  double size = 40,
}) {
  final avatarImage = _getAvatarImage(assistant.avatarPath);

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.28),
      color: colorScheme.surfaceContainerHighest,
      image: avatarImage != null
          ? DecorationImage(image: avatarImage, fit: BoxFit.cover)
          : null,
    ),
    child: avatarImage == null
        ? Center(
            child: assistant.emoji != null && assistant.emoji!.isNotEmpty
                ? Text(
                    assistant.emoji!,
                    style: TextStyle(fontSize: size * 0.5),
                  )
                : Icon(
                    Icons.auto_awesome_rounded,
                    size: size * 0.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
          )
        : null,
  );
}

ImageProvider? _getAvatarImage(String? path) {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (file.existsSync()) return FileImage(file);
  return null;
}

class PickerTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  const PickerTag(
      {super.key,
      required this.text,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class PickerSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const PickerSectionHeader(
      {super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class PickerInfoCard extends StatelessWidget {
  final List<Widget> children;
  const PickerInfoCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
