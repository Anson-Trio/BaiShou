import 'package:baishou/features/diary/presentation/pages/diary_editor_page.dart';
import 'package:baishou/features/diary/presentation/pages/diary_list_page.dart';
import 'package:baishou/features/home/presentation/pages/main_scaffold.dart';
import 'package:baishou/features/onboarding/data/providers/onboarding_provider.dart';
import 'package:baishou/features/onboarding/presentation/pages/onboarding_page.dart';

import 'package:baishou/features/settings/presentation/pages/data_sync_page.dart';
import 'package:baishou/features/settings/presentation/pages/settings_page.dart';
import 'package:baishou/features/summary/presentation/pages/summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

// 临时的 Home Page，稍后会被 features/diary 里的页面替代
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('白守')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, size: 64, color: Colors.pinkAccent),
            const SizedBox(height: 16),
            Text(
              '以纯白的爱，守护你和TA的一生',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            const Text('Development in progress...'),
          ],
        ),
      ),
    );
  }
}

/// 全局路由配置
/// 使用 GoRouter 处理页面导航、重定向（如开启引导页）以及子路由嵌套。
@riverpod
GoRouter goRouter(Ref ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  // Watch onboarding state
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';

      if (!onboardingCompleted && !isGoingToOnboarding) {
        return '/onboarding';
      }

      if (onboardingCompleted && isGoingToOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DiaryListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/summary',
                builder: (context, state) => const SummaryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sync',
                builder: (context, state) => const DataSyncPage(),
              ),
            ],
          ),
          // Branch 3: 设置页（移动端用）
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings-mobile',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/diary/edit',
        builder: (context, state) {
          final dateStr = state.uri.queryParameters['date'];
          final idStr = state.uri.queryParameters['id'];
          final summaryIdStr = state.uri.queryParameters['summaryId'];

          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          final id = idStr != null ? int.tryParse(idStr) : null;
          final summaryId = summaryIdStr != null
              ? int.tryParse(summaryIdStr)
              : null;

          return DiaryEditorPage(
            diaryId: id,
            summaryId: summaryId,
            initialDate: date,
          );
        },
      ),
    ],
  );
}
