/// RAG 记忆管理页面的可复用组件
///
/// StatChip — 统计指标标签
/// ActionChip — 操作按钮标签
/// MemoryEntryCard — 记忆条目卡片

import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── 统计指标 chip ──────────────────────────────────────────

class RagStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const RagStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮 Chip
class RagActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const RagActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor:
            onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 记忆条目卡片
class MemoryEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const MemoryEntryCard({
    super.key,
    required this.entry,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat('MM/dd HH:mm');

    final text = entry['chunk_text'] as String? ?? '';
    final model = entry['model_id'] as String? ?? '';
    final createdAt = entry['created_at'] as int?;
    final timeStr = createdAt != null
        ? dateFormat.format(DateTime.fromMillisecondsSinceEpoch(createdAt))
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(
          Icons.data_object_rounded,
          size: 18,
          color: colorScheme.primary.withValues(alpha: 0.6),
        ),
        title: Text(
          text.length > 200 ? '${text.substring(0, 200)}...' : text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            height: 1.4,
          ),
        ),
        subtitle: Text(
          '$model · $timeStr',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.outline,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
          onPressed: onDelete,
          tooltip: t.agent.rag.delete_tooltip,
        ),
        onTap: onTap,
      ),
    );
  }
}
