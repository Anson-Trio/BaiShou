import 'dart:io';

import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 桌面端侧边栏组件
/// 实现多级导航、用户信息展示以及与应用核心理念（数据主权）一致的视觉风格。
class DesktopSidebar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell; // 关联的 Shell 导航引用
  /// 切换分支的回调，由 MainScaffold 提供（含淡入淡出动画）
  final void Function(int index) onBranchChange;

  const DesktopSidebar({
    super.key,
    required this.navigationShell,
    required this.onBranchChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(userProfileProvider);

    final isSystemSettings = navigationShell.currentIndex == 2;

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
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
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '白守',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '留下你的珍贵回忆',
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

          // 导航列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              children: [
                _NavMenuItem(
                  icon: Icons.timeline,
                  label: '时间轴',
                  isSelected: navigationShell.currentIndex == 0,
                  onTap: () => onBranchChange(0),
                ),
                _NavMenuItem(
                  icon: Icons.auto_stories_rounded,
                  label: '多维总结',
                  isSelected: navigationShell.currentIndex == 1,
                  onTap: () => onBranchChange(1),
                ),
                _NavMenuItem(
                  icon: Icons.sync_rounded,
                  label: '数据同步',
                  isSelected: navigationShell.currentIndex == 2,
                  onTap: () => onBranchChange(2),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(),
                ),
                const SizedBox(height: 16),
                _NavMenuItem(
                  icon: Icons.settings_outlined,
                  label: '全局设置',
                  isSelected: false,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),

          // 底部用户信息与存储进度
          _buildBottomSection(context, userProfile),
        ],
      ),
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
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 用户信息
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
                          : '未设置昵称',
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

/// 侧边栏导航菜单项组件
/// 采用与系统设置页面一致的左侧边框指示器风格，消除点击闪烁。
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
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withOpacity(0.4)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
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
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
