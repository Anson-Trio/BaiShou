import 'dart:io';

import 'package:baishou/core/database/app_database.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> _loadDemoData() async {
    setState(() => _isLoadingDemo = true);
    try {
      AppToast.showError(
        context,
        t.developer.load_demo_failed(e: 'Not supported'),
      );
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
      // 1. 关闭数据库连接（释放 Windows 文件句柄，解决「另一个程序正在访问」）
      await ref.read(appDatabaseProvider).close();

      // 2. 清除 SharedPreferences（配置、引导状态等）
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. 删除 SQLite 数据库文件及附属文件（WAL / SHM）
      final appDir = await getApplicationDocumentsDirectory();
      final dbBasePath = '${appDir.path}/baishou.sqlite';
      for (final suffix in ['', '-wal', '-shm']) {
        final file = File('$dbBasePath$suffix');
        if (file.existsSync()) {
          file.deleteSync();
        }
      }

      // 4. 删除快照目录
      final snapshotDir = Directory('${appDir.path}/snapshots');
      if (snapshotDir.existsSync()) {
        snapshotDir.deleteSync(recursive: true);
      }

      // 5. 删除图片目录
      final imagesDir = Directory('${appDir.path}/images');
      if (imagesDir.existsSync()) {
        imagesDir.deleteSync(recursive: true);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(t.developer.clear_success_title),
            content: Text(t.developer.clear_success_content),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
