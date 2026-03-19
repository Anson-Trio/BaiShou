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

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.navigationShell.currentIndex == 4 ? 1 : 0,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同步外部路由变化到 TabController
    final newIndex = widget.navigationShell.currentIndex == 4 ? 1 : 0;
    if (_tabController.index != newIndex) {
      _tabController.animateTo(newIndex);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    // Tab 0 = 记忆(Branch 0), Tab 1 = Agent(Branch 4)
    _goBranch(_tabController.index == 0 ? 0 : 4);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
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

          // 标签栏（带滑动动画指示器）
          SizedBox(
            width: 240,
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 2.5,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: theme.textTheme.bodySmall,
              dividerHeight: 0,
              splashBorderRadius: BorderRadius.circular(8),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_stories_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(t.diary.title),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Agent'),
                    ],
                  ),
                ),
              ],
            ),
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
