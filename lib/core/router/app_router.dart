import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/core/providers/shared_preferences_provider.dart';
import 'package:baishou/agent/presentation/pages/agent_main_page.dart';
import 'package:baishou/features/diary/presentation/pages/diary_editor_page.dart';
import 'package:baishou/features/diary/presentation/pages/diary_list_page.dart';
import 'package:baishou/features/home/presentation/pages/main_scaffold.dart';
import 'package:baishou/features/onboarding/data/providers/onboarding_provider.dart';
import 'package:baishou/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:baishou/features/settings/presentation/pages/data_sync_page.dart';
import 'package:baishou/features/settings/presentation/pages/settings_page.dart';
import 'package:baishou/features/settings/presentation/pages/views/ai_global_models_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/ai_model_services_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/general_settings_view.dart';
import 'package:baishou/features/settings/presentation/pages/lan_transfer_page.dart';
import 'package:baishou/features/summary/presentation/pages/summary_page.dart';
import 'package:baishou/features/settings/presentation/pages/views/summary_settings_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/rag_memory_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

final diaryNavKey = GlobalKey<NavigatorState>(debugLabel: 'diary');
final summaryNavKey = GlobalKey<NavigatorState>(debugLabel: 'summary');
final syncNavKey = GlobalKey<NavigatorState>(debugLabel: 'sync');
final settingsNavKey = GlobalKey<NavigatorState>(debugLabel: 'settings');
final agentNavKey = GlobalKey<NavigatorState>(debugLabel: 'agent');

/// 全局路由配置
/// 使用 GoRouter 处理页面导航、重定向（如开启引导页）以及子路由嵌套。
@riverpod
GoRouter goRouter(Ref ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  // Watch onboarding state
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);

  // Determine initial location based on saved sidebar order
  String initialLoc = '/';
  final prefs = ref.watch(sharedPreferencesProvider);
  final savedOrder = prefs.getStringList('desktop_sidebar_nav_order');
  if (savedOrder != null && savedOrder.isNotEmpty) {
    final firstBranch = int.tryParse(savedOrder.first) ?? 0;
    if (firstBranch == 1) {
      initialLoc = '/summary';
    } else if (firstBranch == 2) {
      initialLoc = '/sync';
    }
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLoc,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';

      if (!onboardingCompleted && !isGoingToOnboarding) {
        return '/onboarding';
      }

      if (onboardingCompleted && isGoingToOnboarding) {
        return initialLoc;
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
            navigatorKey: diaryNavKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DiaryListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: summaryNavKey,
            routes: [
              GoRoute(
                path: '/summary',
                builder: (context, state) => const SummaryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: syncNavKey,
            routes: [
              GoRoute(
                path: '/sync',
                builder: (context, state) => const DataSyncPage(),
              ),
            ],
          ),
          // Branch 3: 设置页（移动端用）
          StatefulShellBranch(
            navigatorKey: settingsNavKey,
            routes: [
              GoRoute(
                path: '/settings-mobile',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
          // Branch 4: Agent
          StatefulShellBranch(
            navigatorKey: agentNavKey,
            routes: [
              GoRoute(
                path: '/agent',
                builder: (context, state) => const AgentMainPage(),
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
      // 设置子页路由 —— 必须走 rootNavigatorKey，成为全屏覆盖层。
      // 这样子页不会进入 settingsNavKey 的内部栈，
      // 避免切换到其它 Tab 后，后台隐藏的子页被侧滑手势静默 pop。
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/general',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(t.settings.general)),
          body: const GeneralSettingsView(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/ai-services',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(t.settings.ai_services)),
          body: const AiModelServicesView(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/ai-models',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(t.settings.ai_global_models)),
          body: const AiGlobalModelsView(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/summary',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(t.settings.summary_settings_title)),
          body: const SummarySettingsView(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/rag',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(t.agent.rag.title)),
          body: const RagMemoryView(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/data-sync',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(t.data_sync.title)),
          body: const DataSyncPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings/lan-transfer',
        builder: (context, state) => const LanTransferPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/diary/edit',
        builder: (context, state) {
          final dateStr = state.uri.queryParameters['date'];
          final idStr = state.uri.queryParameters['id'];
          final summaryIdStr = state.uri.queryParameters['summaryId'];
          final appendStr = state.uri.queryParameters['append'];

          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          final id = idStr != null ? int.tryParse(idStr) : null;
          final summaryId = summaryIdStr != null
              ? int.tryParse(summaryIdStr)
              : null;
          final shouldAppend = appendStr == '1';

          return DiaryEditorPage(
            diaryId: id,
            summaryId: summaryId,
            initialDate: date,
            appendOnLoad: shouldAppend,
          );
        },
      ),
    ],
  );
}
