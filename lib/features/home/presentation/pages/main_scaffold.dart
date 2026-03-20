import 'dart:io';

import 'package:baishou/core/router/app_router.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/home/presentation/widgets/desktop_sidebar.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主级架构视图
///
/// 桌面端：侧边栏 + 内容区（标题栏已提升到 app.dart builder 层）
/// 移动端：底部导航栏（日记 / 总结 / Agent / 设置）
class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _overlayController;

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  /// 移动端底栏索引映射
  int _getMobileNavIndex() {
    final branchIndex = widget.navigationShell.currentIndex;
    if (branchIndex == 4) return 2;
    if (branchIndex == 3) return 3;
    if (branchIndex <= 1) return branchIndex;
    return 0;
  }

  /// 读取侧边栏排序首位 branchIndex（移动端回退用）
  Future<int> _getDefaultBranch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('desktop_sidebar_nav_order');
      if (saved != null && saved.isNotEmpty) {
        return int.tryParse(saved.first) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0, // 初始透明（不遮挡）
    );
  }

  @override
  void didUpdateWidget(covariant MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      final oldIndex = oldWidget.navigationShell.currentIndex;
      final newIndex = widget.navigationShell.currentIndex;
      // 仅在进出 Agent（大 Tab 切换）时触发渐变，侧边栏切换不需要
      if (oldIndex == 4 || newIndex == 4) {
        _overlayController.value = 1.0;
        _overlayController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

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

  // ─── 桌面端布局（标题栏已在上层） ─────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isAgent = widget.navigationShell.currentIndex == 4;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // 底层：实际内容（始终满透明度）
          Row(
            children: [
              if (!isAgent)
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
          // 顶层：背景色覆盖层，切换时瞬间出现 → 淡出揭示新内容
          IgnorePointer(
            child: FadeTransition(
              opacity: _overlayController,
              child: Container(color: theme.colorScheme.surface),
            ),
          ),
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
          Future.microtask(() async {
            final defaultBranch = await _getDefaultBranch();
            _goBranch(defaultBranch);
          });
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
          switch (index) {
            case 0:
              _goBranch(0);
            case 1:
              _goBranch(1);
            case 2:
              _goBranch(4);
            case 3:
              _goBranch(3);
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
