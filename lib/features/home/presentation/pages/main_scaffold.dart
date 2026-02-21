import 'dart:io';

import 'package:baishou/features/home/presentation/widgets/desktop_insights_sidebar.dart';
import 'package:baishou/features/home/presentation/widgets/desktop_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 主级架构视图
/// 负责分发移动端（底部导航）与桌面端（侧边栏）布局，切换不同的功能分支。
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

  /// 将 Shell Branch 索引映射为移动端底栏索引
  /// Branch 0 → Nav 0 (时间轴), Branch 1 → Nav 1 (总结), Branch 3 → Nav 2 (设置)
  int _getMobileNavIndex() {
    final branchIndex = widget.navigationShell.currentIndex;
    if (branchIndex == 3) return 2; // 设置
    if (branchIndex <= 1) return branchIndex;
    return 0; // 默认回到时间轴（branch 2 是桌面端专用的同步页）
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式与设备类型判断
        // 逻辑：Windows/Linux/macOS 始终显示桌面版；
        // Android/iOS 根据屏幕宽度判断（手机 vs Pad）。
        final bool isDesktopOS =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;
        final bool isLargeScreen = constraints.maxWidth >= 700;
        final bool isDesktop = isDesktopOS || isLargeScreen;

        final bool showInsights =
            isDesktop &&
            constraints.maxWidth >= 1100 &&
            widget.navigationShell.currentIndex == 0;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: Row(
              children: [
                // 左侧导航栏 (桌面端)
                DesktopSidebar(navigationShell: widget.navigationShell),

                // 主内容区域
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      // 在桌面端给主区域一个微妙的阴影或分界
                      boxShadow: [
                        if (Theme.of(context).brightness == Brightness.light)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(-5, 0),
                          ),
                      ],
                    ),
                    child: widget.navigationShell,
                  ),
                ),

                // 右侧洞察栏 (宽屏桌面端)
                if (showInsights) const DesktopInsightsSidebar(),
              ],
            ),
          );
        }

        // 移动端布局
        return Scaffold(
          body: Container(
            color: Theme.of(context).colorScheme.surface,
            child: widget.navigationShell,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _getMobileNavIndex(),
            onDestinationSelected: (index) {
              // 移动端映射：0=时间轴, 1=总结, 2=设置(branch 3)
              if (index == 2) {
                _goBranch(3); // 设置页面位于 branch 3
              } else {
                _goBranch(index);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.timeline_outlined),
                selectedIcon: Icon(Icons.timeline),
                label: '时间轴',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories),
                label: '总结',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        );
      },
    );
  }
}
