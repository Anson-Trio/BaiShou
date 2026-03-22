/// 侧边栏会话列表项
///
/// 单条会话记录 UI：标题、置顶标记、操作菜单、多选框

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

/// 侧边栏单个会话行
class SessionListTile extends StatelessWidget {
  final AgentSession session;
  final bool isSelected;
  final bool isMultiSelect;
  final bool isChecked;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onCheckChanged;

  const SessionListTile({
    super.key,
    required this.session,
    required this.isSelected,
    required this.isMultiSelect,
    required this.isChecked,
    required this.onTap,
    this.onPin,
    this.onRename,
    this.onDelete,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (isMultiSelect)
                Checkbox(
                  value: isChecked,
                  onChanged: onCheckChanged,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (session.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.push_pin,
                    size: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Expanded(
                child: Text(
                  session.title.isEmpty
                      ? t.agent.sessions.new_chat
                      : session.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: t.agent.sessions.actions,
                  onSelected: (action) {
                    if (action == 'pin') onPin?.call();
                    if (action == 'rename') onRename?.call();
                    if (action == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            session.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            session.isPinned
                                ? t.agent.sessions.unpin
                                : t.agent.sessions.pin,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 18),
                          const SizedBox(width: 8),
                          Text(t.agent.sessions.rename),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.agent.sessions.delete_session,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 侧边栏导航菜单项（设置等入口）
class SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SidebarMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
