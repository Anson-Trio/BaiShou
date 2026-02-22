import 'dart:io';

import 'package:baishou/core/theme/theme_service.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/features/settings/presentation/pages/about_page.dart';
import 'package:baishou/features/settings/presentation/pages/lan_transfer_page.dart'
    as baishou_lan;
import 'package:baishou/features/settings/domain/services/export_service.dart'
    as baishou_export;
import 'package:baishou/features/settings/domain/services/import_service.dart'
    as baishou_import;
import 'package:baishou/core/services/data_refresh_notifier.dart'
    as baishou_refresh;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/presentation/pages/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// 常规设置视图
/// 整合了个人资料编辑、外观主题切换以及关于信息入口。
class GeneralSettingsView extends ConsumerStatefulWidget {
  const GeneralSettingsView({super.key});

  @override
  ConsumerState<GeneralSettingsView> createState() =>
      _GeneralSettingsViewState();
}

class _GeneralSettingsViewState extends ConsumerState<GeneralSettingsView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildProfileSection(),
        _buildAppearanceSection(),
        _buildDataManagementSection(),
        _buildAboutSection(),
      ],
    );
  }

  Widget _buildProfileSection() {
    final userProfile = ref.watch(userProfileProvider);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: _pickAndCropImage,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: userProfile.avatarPath != null
                    ? FileImage(File(userProfile.avatarPath!))
                    : null,
                child: userProfile.avatarPath == null
                    ? Text(
                        userProfile.nickname.isNotEmpty
                            ? userProfile.nickname[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(fontSize: 24),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        userProfile.nickname,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: () =>
                            _showEditNicknameDialog(userProfile.nickname),
                      ),
                    ],
                  ),
                  Text(
                    '点击头像更换图片',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropImage() async {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    if (isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        await ref
            .read(userProfileProvider.notifier)
            .updateAvatar(File(result.files.single.path!));
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: '裁剪头像',
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile != null) {
        await ref
            .read(userProfileProvider.notifier)
            .updateAvatar(File(croppedFile.path));
      }
    }
  }

  Future<void> _showEditNicknameDialog(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '昵称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (newNickname != null && newNickname.isNotEmpty) {
      ref.read(userProfileProvider.notifier).updateNickname(newNickname);
    }
  }

  Widget _buildAppearanceSection() {
    final themeState = ref.watch(themeProvider);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ExpansionTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('外观设置'),
            subtitle: Text(_getThemeModeText(themeState.mode)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('主题模式'),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('跟随系统'),
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('亮色'),
                          icon: Icon(Icons.wb_sunny_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('深色'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {themeState.mode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(newSelection.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('主题色'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildColorOption(const Color(0xFF137FEC)), // Blue
                        _buildColorOption(Colors.purple),
                        _buildColorOption(Colors.teal),
                        _buildColorOption(Colors.orange),
                        _buildColorOption(Colors.pink),
                        _buildColorOption(Colors.cyan),
                        _buildColorOption(Colors.brown),
                        _buildColorOption(Colors.blueGrey),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    final themeState = ref.watch(themeProvider);
    final isSelected = themeState.seedColor.value == color.value;

    return GestureDetector(
      onTap: () {
        ref.read(themeProvider.notifier).setSeedColor(color);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '亮色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  Widget _buildDataManagementSection() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ExpansionTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('数据管理'),
            subtitle: const Text('导出、导入数据或局域网快传'),
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('导出数据至本地'),
                subtitle: const Text('生成一份包含所有内容的 ZIP 备份文件'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('从外部 ZIP 导入'),
                subtitle: const Text('选择本地 ZIP 文件覆盖恢复数据'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _importData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('从快照恢复'),
                subtitle: const Text('从本地历史快照中选择一个进行恢复'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _restoreFromSnapshot,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.wifi_protected_setup_outlined),
                title: const Text('局域网传输'),
                subtitle: const Text('在同一 Wi-Fi 下快速互传整个数据库'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const baishou_lan.LanTransferPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在导出数据...'),
          ],
        ),
      ),
    );

    try {
      final exportService = ref.read(baishou_export.exportServiceProvider);
      final exportFile = await exportService.exportToZip(share: false);

      if (mounted) {
        Navigator.pop(context); // 关掉 loading
        if (exportFile != null) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('导出成功'),
              content: Text('备份 ZIP 文件已保存在:\n${exportFile.path}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('好的'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关掉 loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('恢复快照将覆盖当前所有数据。\n\n确认继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在恢复数据...'),
          ],
        ),
      ),
    );

    try {
      final importResult = await ref
          .read(baishou_import.importServiceProvider)
          .importFromZip(file);

      if (!mounted) return;
      Navigator.pop(context); // 关掉 loading

      if (importResult.success) {
        if (importResult.configData != null) {
          await ref
              .read(baishou_import.importServiceProvider)
              .restoreConfig(importResult.configData!);
        }

        if (!mounted) return;
        ref.read(baishou_refresh.dataRefreshProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '快照恢复成功：${importResult.diariesImported} 条日记，'
              '${importResult.summariesImported} 条总结',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(importResult.error ?? '恢复失败')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关掉 loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('恢复失败: $e')));
      }
    }
  }

  /// 从本地 snapshots/ 目录列出历史快照，让用户选择后恢复
  Future<void> _restoreFromSnapshot() async {
    final appDir = await getApplicationDocumentsDirectory();
    final snapshotDir = Directory('${appDir.path}/snapshots');

    if (!snapshotDir.existsSync()) {
      if (mounted) AppToast.show(context, '暂无可用快照');
      return;
    }

    final allFiles =
        snapshotDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.zip'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));

    // 保留最新 10 个，清理旧的
    if (allFiles.length > 10) {
      for (var i = 10; i < allFiles.length; i++) {
        try {
          allFiles[i].deleteSync();
        } catch (_) {}
      }
    }

    final snapshots = allFiles.take(10).toList();

    if (snapshots.isEmpty) {
      if (mounted) AppToast.show(context, '暂无可用快照');
      return;
    }

    if (!mounted) return;

    final selected = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择要恢复的快照'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: snapshots.length,
            itemBuilder: (context, index) {
              final f = snapshots[index];
              final name = f.path.split(Platform.pathSeparator).last;
              final timeMatch = RegExp(r'(\d{8})_(\d{6})').firstMatch(name);
              String displayTime = name;
              if (timeMatch != null) {
                final d = timeMatch.group(1)!;
                final t = timeMatch.group(2)!;
                displayTime =
                    '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)} '
                    '${t.substring(0, 2)}:${t.substring(2, 4)}:${t.substring(4, 6)}';
              }
              final fileSize = f.lengthSync();
              final sizeStr = fileSize > 1024 * 1024
                  ? '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'
                  : '${(fileSize / 1024).toStringAsFixed(0)} KB';
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(displayTime),
                subtitle: Text(sizeStr),
                onTap: () => Navigator.pop(ctx, f),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selected == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('恢复快照将覆盖当前所有数据。\n\n确认继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在恢复数据...'),
          ],
        ),
      ),
    );

    try {
      final importResult = await ref
          .read(baishou_import.importServiceProvider)
          .importFromZip(selected);

      if (!mounted) return;
      Navigator.pop(context); // 关掉 loading

      if (importResult.success) {
        if (importResult.configData != null) {
          await ref
              .read(baishou_import.importServiceProvider)
              .restoreConfig(importResult.configData!);
        }
        if (!mounted) return;
        ref.read(baishou_refresh.dataRefreshProvider.notifier).refresh();
        AppToast.showSuccess(
          context,
          '快照恢复成功：${importResult.diariesImported} 条日记，'
          '${importResult.summariesImported} 条总结',
          duration: const Duration(seconds: 4),
        );
      } else {
        AppToast.showError(context, importResult.error ?? '恢复失败');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppToast.showError(context, '恢复失败: $e');
      }
    }
  }

  Widget _buildAboutSection() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于白守'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('开发理念'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('反馈问题'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              launchUrl(
                Uri.parse('https://github.com/Anson-Trio/BaiShou/issues'),
              );
            },
          ),
        ],
      ),
    );
  }
}
