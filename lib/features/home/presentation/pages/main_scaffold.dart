import 'dart:io';

import 'package:baishou/core/router/app_router.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/home/presentation/widgets/desktop_sidebar.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 主级架构视图
///
/// 桌面端：顶部标签栏（记忆 / Agent）+ 各标签独立布局
/// 移动端：底部导航栏（日记 / 总结 / Agent / 设置）
class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  /// 当前顶部标签索引：0=记忆（Branch 0,1,2），1=Agent（Branch 4）
  int get _topTabIndex {
    return widget.navigationShell.currentIndex == 4 ? 1 : 0;
  }

  /// 移动端底栏索引映射
  /// Branch 0→0(日记), 1→1(总结), 4→2(Agent), 3→3(设置)
  int _getMobileNavIndex() {
    final branchIndex = widget.navigationShell.currentIndex;
    if (branchIndex == 4) return 2; // Agent
    if (branchIndex == 3) return 3; // 设置
    if (branchIndex <= 1) return branchIndex;
    return 0;
  }

  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktopOS =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;
        final bool isLargeScreen = constraints.maxWidth >= 700;
        final bool isDesktop = isDesktopOS || isLargeScreen;

        if (isDesktop) {
          return _buildDesktopLayout(context);
        }

        return _buildMobileLayout(context);
      },
    );
  }

  // ─── 桌面端布局 ──────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isAgent = widget.navigationShell.currentIndex == 4;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // ─── 顶部标签栏 ───
          _buildTopTabBar(theme),

          // ─── 内容区 ───
          Expanded(
            child: isAgent
                // Agent 标签：AgentMainPage 自带侧边栏，直接渲染
                ? widget.navigationShell
                // 记忆标签：全局侧边栏 + 内容
                : Row(
                    children: [
                      DesktopSidebar(
                        navigationShell: widget.navigationShell,
                        onBranchChange: _goBranch,
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            boxShadow: [
                              if (theme.brightness == Brightness.light)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(-5, 0),
                                ),
                            ],
                          ),
                          child: widget.navigationShell,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabBar(ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // App icon
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/icon/icon.png',
              width: 24,
              height: 24,
            ),
          ),
          const SizedBox(width: 16),

          // 标签按钮
          _TopTab(
            icon: Icons.auto_stories_rounded,
            label: t.diary.title,
            isSelected: _topTabIndex == 0,
            onTap: () => _goBranch(0), // 切到 日记(Branch 0)
          ),
          _TopTab(
            icon: Icons.auto_awesome_rounded,
            label: 'Agent',
            isSelected: _topTabIndex == 1,
            onTap: () => _goBranch(4), // 切到 Agent(Branch 4)
          ),

          const Spacer(),

          // 设置按钮
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => context.push('/settings'),
            tooltip: t.settings.title,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── 移动端布局 ──────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    final GlobalKey<NavigatorState>? activeKey = switch (currentIndex) {
      0 => diaryNavKey,
      1 => summaryNavKey,
      2 => syncNavKey,
      3 => settingsNavKey,
      4 => agentNavKey,
      _ => null,
    };

    final navState = activeKey?.currentState;
    final bool canPopNested = navState?.canPop() ?? false;
    final bool shouldPopRoute = canPopNested;

    Widget content = PopScope(
      canPop: shouldPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (currentIndex != 0) {
          Future.microtask(() => _goBranch(0));
          return;
        }

        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          setState(() {
            _lastBackPress = now;
          });
          AppToast.show(context, t.common.exit_hint);
          return;
        }

        SystemNavigator.pop();
      },
      child: widget.navigationShell,
    );

    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: content,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getMobileNavIndex(),
        onDestinationSelected: (index) {
          // 映射: 0=日记, 1=总结, 2=Agent(branch 4), 3=设置(branch 3)
          switch (index) {
            case 0:
              _goBranch(0);
            case 1:
              _goBranch(1);
            case 2:
              _goBranch(4); // Agent
            case 3:
              _goBranch(3); // 设置
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.timeline_outlined),
            selectedIcon: const Icon(Icons.timeline),
            label: t.diary.title,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories),
            label: t.summary.dashboard_title,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome_rounded),
            label: 'Agent',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: t.settings.title,
          ),
        ],
      ),
    );
  }
}

// ─── 顶部标签按钮 ──────────────────────────────────────────────

class _TopTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.surface
                : Colors.transparent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: isSelected
                ? Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
