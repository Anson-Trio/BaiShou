import 'dart:io';

import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperOptionsView extends ConsumerStatefulWidget {
  const DeveloperOptionsView({super.key});

  @override
  ConsumerState<DeveloperOptionsView> createState() =>
      _DeveloperOptionsViewState();
}

class _DeveloperOptionsViewState extends ConsumerState<DeveloperOptionsView> {
  bool _isClearing = false;
  bool _isLoadingDemo = false;

  Future<void> _loadDemoData() async {
    setState(() => _isLoadingDemo = true);
    try {
      final repo = ref.read(diaryRepositoryProvider);
      if (repo is DiaryRepositoryImpl) {
        await repo.ensureInitialData(force: true);
        if (mounted) {
          AppToast.showSuccess(
            context,
            '✅ 演示数据已加载',
            duration: const Duration(seconds: 3));
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, '❌ 加载失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingDemo = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('警告：一键清除数据', style: TextStyle(color: Colors.red)),
        content: const Text(
          '此操作将极其危险的清除所有的保存配置、所有日记、所有总结、图片及数据库，并将软件恢复至出厂状态。\n\n操作不可逆，强烈建议确认数据安全！\n\n确认继续码？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);

    try {
      // 1. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Clear Database & Files
      final appDir = await getApplicationDocumentsDirectory();

      final dbFile = File('${appDir.path}/baishou.sqlite');
      if (dbFile.existsSync()) {
        dbFile.deleteSync();
      }

      final snapshotDir = Directory('${appDir.path}/snapshots');
      if (snapshotDir.existsSync()) {
        snapshotDir.deleteSync(recursive: true);
      }

      final imagesDir = Directory('${appDir.path}/images');
      if (imagesDir.existsSync()) {
        imagesDir.deleteSync(recursive: true);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            title: Text('清除成功'),
            content: Text('所有数据已全部清空。为使软件重新生效，请手动彻底重启应用。'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, '清除数据失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('开发者选项'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '开发者选项',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade300),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const Text(
                      '加载演示数据',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('写入一批示例日记（不会清空现有数据）'),
                    trailing: _isLoadingDemo
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isLoadingDemo ? null : _loadDemoData,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: Colors.red.shade700,
                    ),
                    title: Text(
                      '一键清除数据 (危险)',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text('清空本地存储、数据库和文件。'),
                    trailing: _isClearing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isClearing ? null : _clearAllData,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
