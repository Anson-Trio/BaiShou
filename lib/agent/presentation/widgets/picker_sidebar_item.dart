/// 伙伴选择器 - 侧边栏伙伴项
///
/// 包含头像、名称、描述、拖拽手柄、选中/当前状态

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/widgets/picker_shared_widgets.dart';
import 'package:flutter/material.dart';

class PickerSidebarItem extends StatefulWidget {
  final AgentAssistant assistant;
  final bool isSelected;
  final bool isCurrent;
  final int? dragIndex;
  final VoidCallback onTap;

  const PickerSidebarItem({
    super.key,
    required this.assistant,
    required this.isSelected,
    required this.isCurrent,
    this.dragIndex,
    required this.onTap,
  });

  @override
  State<PickerSidebarItem> createState() => _PickerSidebarItemState();
}

class _PickerSidebarItemState extends State<PickerSidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final a = widget.assistant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : _isHovered
                      ? colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: widget.isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // 拖拽手柄
                if (widget.dragIndex != null)
                  ReorderableDragStartListener(
                    index: widget.dragIndex!,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 14,
                          color: colorScheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                // 头像
                buildAssistantAvatar(a, colorScheme, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: widget.isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: widget.isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (widget.isCurrent) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.circle,
                                size: 6, color: colorScheme.primary),
                          ],
                        ],
                      ),
                      if (a.description.isNotEmpty)
                        Text(
                          a.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
