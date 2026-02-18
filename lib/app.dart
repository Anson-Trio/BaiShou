import 'package:baishou/core/router/app_router.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/theme/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BaiShouApp extends ConsumerWidget {
  const BaiShouApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: '白守',
      debugShowCheckedModeBanner: false,

      // 主题配置
      theme: AppTheme.lightTheme(themeState.seedColor),
      darkTheme: AppTheme.darkTheme(themeState.seedColor),
      themeMode: themeState.mode, // 跟随系统
      // 路由配置
      routerConfig: router,

      // 国际化配置
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文
        Locale('en', 'US'), // 英文
      ],
    );
  }
}
