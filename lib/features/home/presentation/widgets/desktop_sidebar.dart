import 'dart:io';

import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── 侧边栏菜单项排序持久化 ──────────────────────────────────

const _kNavOrderKey = 'desktop_sidebar_nav_order';

/// 导航菜单项数据
class _NavItem {
  final int branchIndex; // 在 StatefulShellRoute 中的 branch 索引
  final IconData icon;
  final String Function() labelBuilder;

  const _NavItem({
    required this.branchIndex,
    required this.icon,
    required this.labelBuilder,
  });
}

/// 桌面端侧边栏组件
/// 支持拖拽排序，排序状态持久化到 SharedPreferences。
class DesktopSidebar extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final void Function(int index) onBranchChange;

  const DesktopSidebar({
    super.key,
    required this.navigationShell,
    required this.onBranchChange,
  });

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  /// 默认菜单项定义
  late List<_NavItem> _defaultItems;

  /// 当前排列顺序（branchIndex 列表）
  List<int> _order = [];

  @override
  void initState() {
    super.initState();
    _defaultItems = [
      _NavItem(
        branchIndex: 0,
        icon: Icons.timeline,
        labelBuilder: () => t.diary.title,
      ),
      _NavItem(
        branchIndex: 1,
        icon: Icons.auto_stories_rounded,
        labelBuilder: () => t.summary.dashboard_title,
      ),
      _NavItem(
        branchIndex: 2,
        icon: Icons.sync_rounded,
        labelBuilder: () => t.common.data_sync,
      ),
    ];
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kNavOrderKey);
    if (saved != null && saved.length == _defaultItems.length) {
      final parsed = saved.map(int.tryParse).toList();
      if (parsed.every((e) => e != null)) {
        setState(() => _order = parsed.cast<int>());
        return;
      }
    }
    setState(() => _order = _defaultItems.map((e) => e.branchIndex).toList());
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kNavOrderKey,
      _order.map((e) => e.toString()).toList(),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    _saveOrder();
  }

  _NavItem _getItem(int branchIndex) {
    return _defaultItems.firstWhere((e) => e.branchIndex == branchIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(userProfileProvider);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo 区域
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.common.app_title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      t.settings.tagline_short,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 可拖拽排序的导航列表
          Expanded(
            child: _order.isEmpty
                ? const SizedBox()
                : Column(
                    children: [
                      Expanded(
                        child: ReorderableListView(
                          buildDefaultDragHandles: false,
                          proxyDecorator: _proxyDecorator,
                          onReorder: _onReorder,
                          children: [
                            for (int i = 0; i < _order.length; i++)
                              _DraggableNavItem(
                                key: ValueKey(_order[i]),
                                item: _getItem(_order[i]),
                                index: i,
                                isSelected: widget.navigationShell
                                        .currentIndex ==
                                    _order[i],
                                onTap: () =>
                                    widget.onBranchChange(_order[i]),
                              ),
                          ],
                        ),
                      ),

                      // 分隔线 + 设置（不参与排序）
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(),
                      ),
                      const SizedBox(height: 4),
                      _NavMenuItem(
                        icon: Icons.settings_outlined,
                        label: t.settings.title,
                        isSelected: false,
                        onTap: () => context.push('/settings'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
          ),

          // 底部用户信息
          _buildBottomSection(context, userProfile),
        ],
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double elevation = Tween<double>(
          begin: 0,
          end: 6,
        ).evaluate(animation);
        return Material(
          elevation: elevation,
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          borderRadius: BorderRadius.circular(8),
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildBottomSection(BuildContext context, UserProfile userProfile) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: userProfile.avatarPath != null
                    ? FileImage(File(userProfile.avatarPath!))
                    : null,
                child: userProfile.avatarPath == null
                    ? Text(
                        userProfile.nickname.isNotEmpty
                            ? userProfile.nickname[0].toUpperCase()
                            : 'A',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProfile.nickname.isNotEmpty
                          ? userProfile.nickname
                          : t.settings.no_nickname,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 可拖拽导航菜单项 ────────────────────────────────────────

class _DraggableNavItem extends StatefulWidget {
  final _NavItem item;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _DraggableNavItem({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DraggableNavItem> createState() => _DraggableNavItemState();
}

class _DraggableNavItemState extends State<_DraggableNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // 拖拽手柄（hover 时显示）
                AnimatedOpacity(
                  opacity: _isHovered ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.drag_indicator, size: 16),
                    ),
                  ),
                ),
                Icon(
                  widget.item.icon,
                  size: 20,
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.item.labelBuilder(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        widget.isSelected ? FontWeight.bold : FontWeight.w500,
                    color: widget.isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
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

// ─── 固定导航菜单项（设置等，不参与拖拽） ─────────────────────

class _NavMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20), // 与拖拽项对齐
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
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
