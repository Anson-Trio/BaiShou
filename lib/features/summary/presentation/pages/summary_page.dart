import 'dart:io';
import 'package:baishou/features/summary/presentation/widgets/summary_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 总结主页面 — 直接渲染仪表盘（不再有双 Tab）
class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isMobile = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isMobile = true;
      }
    } catch (_) {}

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: SafeArea(
        top: isMobile,
        bottom: false,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: SummaryDashboardView(),
        ),
      ),
    );
  }
}
