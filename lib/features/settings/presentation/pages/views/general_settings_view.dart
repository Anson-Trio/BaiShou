import 'dart:io';

import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:baishou/core/theme/theme_service.dart';
import 'package:baishou/features/settings/domain/services/export_service.dart';
import 'package:baishou/features/settings/domain/services/import_service.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/features/settings/presentation/pages/about_page.dart';
import 'package:baishou/features/settings/presentation/pages/lan_transfer_page.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:baishou/features/settings/presentation/pages/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 常规设置视图
/// 整合了个人资料编辑、外观主题切换、数据备份/恢复管理以及关于信息入口。
class GeneralSettingsView extends ConsumerStatefulWidget {
  const GeneralSettingsView({super.key});

  @override
  ConsumerState<GeneralSettingsView> createState() =>
      _GeneralSettingsViewState();
}

class _GeneralSettingsViewState extends ConsumerState<GeneralSettingsView> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(32),
          children: [
            _buildProfileSection(),
            _buildAppearanceSection(),
            _buildDataSection(),
            _buildAboutSection(),
          ],
        ),
        // 导入时的全屏遮罩
        if (_isImporting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('正在导入...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

  Widget _buildDataSection() {
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
            leading: const Icon(Icons.download_outlined),
            title: const Text('导出数据'),
            subtitle: const Text('导出完整备份（含日记、总结、配置）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final file = await ref
                    .read(exportServiceProvider)
                    .exportToZip(share: false);
                if (!mounted) return;
                if (file != null) {
                  AppToast.showSuccess(context, '导出成功');
                }
              } catch (e) {
                if (mounted) {
                  AppToast.showError(context, '导出失败: $e');
                }
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('导入数据'),
            subtitle: const Text('从备份 ZIP 恢复日记、总结和配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _importBackup(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.wifi_tethering_outlined),
            title: const Text('局域网传输'),
            subtitle: const Text('在同一网络下的设备间同步'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LanTransferPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('恢复快照'),
            subtitle: const Text('恢复到导入前的数据状态'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _restoreFromSnapshot(),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: '选择备份文件',
    );

    if (result == null || result.files.single.path == null) return;
    final zipFile = File(result.files.single.path!);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入备份'),
        content: const Text(
          '导入将覆盖当前所有数据并恢复配置（含 API Key、主题、头像）。\n\n导入前会自动创建快照，可用于恢复。\n\n确认继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);

    try {
      final importResult = await ref
          .read(importServiceProvider)
          .importFromZip(zipFile);

      if (!mounted) return;

      if (importResult.success && importResult.configData != null) {
        await ref
            .read(importServiceProvider)
            .restoreConfig(importResult.configData!);
      }

      if (!mounted) return;
      setState(() => _isImporting = false);

      if (importResult.success) {
        ref.read(dataRefreshProvider.notifier).refresh();
        AppToast.showSuccess(
          context,
          '导入成功：${importResult.diariesImported} 条日记，'
          '${importResult.summariesImported} 条总结'
          '${importResult.profileRestored ? "，配置已恢复" : ""}'
          '${importResult.snapshotPath != null ? "\n已创建恢复快照" : ""}',
          duration: const Duration(seconds: 4),
        );
      } else {
        AppToast.showError(context, importResult.error ?? '导入失败');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        AppToast.showError(context, '导入失败: $e');
      }
    }
  }

  Future<void> _restoreFromSnapshot() async {
    final appDir = await getApplicationDocumentsDirectory();
    final snapshotDir = Directory('${appDir.path}/snapshots');

    if (!snapshotDir.existsSync()) {
      if (mounted) {
        AppToast.showSuccess(context, '暂无可用快照');
      }
      return;
    }

    final allFiles = snapshotDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.zip'))
        .toList();

    allFiles.sort((a, b) => b.path.compareTo(a.path));

    if (allFiles.length > 10) {
      for (var i = 10; i < allFiles.length; i++) {
        try {
          if (allFiles[i].existsSync()) {
            allFiles[i].deleteSync();
            debugPrint('Deleted old snapshot: ${allFiles[i].path}');
          }
        } catch (e) {
          debugPrint('Failed to delete old snapshot: $e');
        }
      }
    }

    final snapshots = allFiles.take(10).toList();

    if (snapshots.isEmpty) {
      if (mounted) {
        AppToast.showSuccess(context, '暂无可用快照');
      }
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
              final file = snapshots[index];
              final name = file.path.split('/').last;
              final timeMatch = RegExp(r'(\d{8})_(\d{6})').firstMatch(name);
              String displayTime = name;
              if (timeMatch != null) {
                final d = timeMatch.group(1)!;
                final t = timeMatch.group(2)!;
                displayTime =
                    '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)} '
                    '${t.substring(0, 2)}:${t.substring(2, 4)}:${t.substring(4, 6)}';
              }
              final fileSize = file.lengthSync();
              final sizeStr = fileSize > 1024 * 1024
                  ? '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'
                  : '${(fileSize / 1024).toStringAsFixed(0)} KB';
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(displayTime),
                subtitle: Text(sizeStr),
                onTap: () => Navigator.pop(ctx, file),
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

    setState(() => _isImporting = true);

    try {
      final importResult = await ref
          .read(importServiceProvider)
          .importFromZip(selected);

      if (!mounted) return;

      if (importResult.success && importResult.configData != null) {
        await ref
            .read(importServiceProvider)
            .restoreConfig(importResult.configData!);
      }

      if (!mounted) return;
      setState(() => _isImporting = false);

      if (importResult.success) {
        ref.read(dataRefreshProvider.notifier).refresh();
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
        setState(() => _isImporting = false);
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
