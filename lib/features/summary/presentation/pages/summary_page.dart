import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/summary/presentation/widgets/summary_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3, // 周、月、年（季度在MVP阶段隐藏或合并？） -> 目前保持这三种：周、月、年
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI 总结'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '周记'),
              Tab(text: '月报'),
              Tab(text: '年鉴'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: () {
                // TODO: 触发生成对话框
                AppToast.show(
                  context,
                  'AI 生成功能将在下一阶段实现',
                  icon: Icons.auto_awesome,
                );
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            SummaryListView(type: SummaryType.weekly),
            SummaryListView(type: SummaryType.monthly),
            SummaryListView(type: SummaryType.yearly),
          ],
        ),
      ),
    );
  }
}
