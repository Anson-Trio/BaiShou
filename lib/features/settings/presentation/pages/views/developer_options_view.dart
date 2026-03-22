import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/diary/data/initial_data.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/core/database/app_database.dart' hide Diary;
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:baishou/i18n/strings.g.dart';
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
  bool _isClearingAgent = false;

  Future<void> _loadDemoData() async {
    setState(() => _isLoadingDemo = true);
    try {
      final repo = ref.read(diaryRepositoryProvider);
      final now = DateTime.now();

      // 将 initial_data.dart 中的 Map 列表转换为实体列表
      final demoEntries = initialDiaries.asMap().entries.map((entry) {
        final idx = entry.key;
        final map = entry.value;
        final date = DateTime.parse(map['date'] as String);

        return Diary(
          id: now.millisecondsSinceEpoch - (idx * 1000),
          date: date,
          content: map['content'] as String,
          tags: List<String>.from(map['tags'] as List? ?? []),
          createdAt: date,
          updatedAt: date,
          mood: map['mood'] as String?,
          weather: map['weather'] as String?,
        );
      }).toList();

      await repo.batchSaveDiaries(demoEntries);

      // 触发全局刷新信号，确保回忆页等组件更新统计量
      ref.read(dataRefreshProvider.notifier).refresh();

      if (mounted) {
        AppToast.showSuccess(context, t.developer.load_demo_success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          t.developer.load_demo_failed(e: e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDemo = false);
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t.developer.clear_warning_title,
          style: const TextStyle(color: Colors.red),
        ),
        content: Text(t.developer.clear_warning_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.developer.confirm_clear),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      // 1. 释放数据库句柄（Windows 需要释放文件锁）
      await ref.read(appDatabaseProvider).close();
      ref.read(shadowIndexDatabaseProvider.notifier).close();

      // 给操作系统一点时间释放文件句柄，尤其是在 Windows 上
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. 获取当前活跃的存储服务及根目录
      final storageService = ref.read(storagePathServiceProvider);
      final rootDir = await storageService.getRootDirectory();
      final appDir = await getApplicationDocumentsDirectory();

      // 3. 执行“地毯式”物理清理：遍历根目录下的所有子项并递归删除
      // 这样可以确保所有 Vault (不论名称) 和 .baishou 文件夹都被彻底清除
      if (rootDir.existsSync()) {
        final entities = rootDir.listSync();
        for (final entity in entities) {
          try {
            if (entity is Directory) {
              entity.deleteSync(recursive: true);
              debugPrint('ClearData: Deleted directory ${entity.path}');
            } else if (entity is File) {
              entity.deleteSync();
              debugPrint('ClearData: Deleted file ${entity.path}');
            }
          } catch (e) {
            debugPrint('ClearData: Failed to delete ${entity.path}: $e');
          }
        }
      }

      // 4. 清理 App 内部专属元数据（快照、缓存、数据库残余）
      final internalTargets = [
        'snapshots',
        'avatars',
        'images',
        'baishou.sqlite',
        'baishou.sqlite-wal',
        'baishou.sqlite-shm',
      ];
      for (final targetName in internalTargets) {
        final targetPath = p.join(appDir.path, targetName);
        try {
          if (FileSystemEntity.isDirectorySync(targetPath)) {
            Directory(targetPath).deleteSync(recursive: true);
          } else if (FileSystemEntity.isFileSync(targetPath)) {
            File(targetPath).deleteSync();
          }
        } catch (e) {
          debugPrint(
            'ClearData: Failed to delete internal target $targetPath: $e',
          );
        }
      }

      // 5. 最后清空所有内存配置并退出
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(t.developer.clear_success_title),
            content: Text(t.developer.clear_success_content),
            actions: [
              FilledButton(
                onPressed: () {
                  exit(0);
                },
                child: Text(t.settings.exit_app),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, t.developer.clear_failed(e: e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  Future<void> _clearAgentDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理 Agent 数据库'),
        content: const Text('将删除所有 Agent 会话、伙伴和消息数据。\n重启后数据库会自动重建。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearingAgent = true);
    try {
      final agentDb = ref.read(agentDatabaseProvider);
      await agentDb.close();
      await Future.delayed(const Duration(milliseconds: 300));

      final appDir = await getApplicationDocumentsDirectory();
      for (final name in ['agent_database.db', 'agent_database.db-wal', 'agent_database.db-shm']) {
        final file = File(p.join(appDir.path, name));
        if (file.existsSync()) {
          file.deleteSync();
          debugPrint('ClearAgentDB: Deleted $name');
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('清理完成'),
            content: const Text('Agent 数据库已清理，请重启应用。'),
            actions: [
              FilledButton(
                onPressed: () => exit(0),
                child: Text(t.settings.exit_app),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, '清理失败: $e');
    } finally {
      if (mounted) setState(() => _isClearingAgent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(t.developer.title), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.developer.title,
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
                    title: Text(
                      t.developer.load_demo_data,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(t.developer.load_demo_desc),
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
                      t.developer.clear_all_data,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(t.developer.clear_all_desc),
                    trailing: _isClearing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isClearing ? null : _clearAllData,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.storage_rounded,
                      color: Colors.orange.shade700,
                    ),
                    title: Text(
                      '清理 Agent 数据库',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text('删除 Agent 会话、伙伴、消息数据（重启后自动重建）'),
                    trailing: _isClearingAgent
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isClearingAgent ? null : _clearAgentDatabase,
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
