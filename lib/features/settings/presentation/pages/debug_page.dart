import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugPage extends ConsumerStatefulWidget {
  const DebugPage({super.key});

  @override
  ConsumerState<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends ConsumerState<DebugPage> {
  bool _isLoading = false;

  Future<void> _loadDemoData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(diaryRepositoryProvider);
      if (repo is DiaryRepositoryImpl) {
        await repo.ensureInitialData(force: true);
        if (mounted) {
          AppToast.show(
            context,
            '✅ 演示数据已加载',
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '❌ 加载失败: $e', icon: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛠 开发者调试')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '数据管理',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '加载演示数据会向数据库写入一批示例日记，用于测试和展示。\n如果已有数据，会强制覆盖写入（不清空现有数据）。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _loadDemoData,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.science_outlined),
                      label: Text(_isLoading ? '加载中...' : '加载演示数据'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
