import 'package:baishou/features/diary/presentation/pages/diary_editor_page.dart';
import 'package:baishou/features/diary/presentation/pages/diary_list_page.dart';
import 'package:baishou/features/home/presentation/pages/main_scaffold.dart';
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
      appBar: AppBar(title: const Text('白守 BaiShou')),
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

@riverpod
GoRouter goRouter(Ref ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
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
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      // Fullscreen routes (outside shell)
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
