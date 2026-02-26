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
import 'package:baishou/core/localization/locale_service.dart';
import 'package:baishou/i18n/strings.g.dart';
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
                    t.settings.tap_avatar_to_change,
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
            toolbarTitle: t.settings.crop_avatar,
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: t.settings.crop_avatar,
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
        title: Text(t.settings.edit_nickname),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: t.common.nickname),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(t.common.save),
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
    final currentLocale = ref.watch(localeProvider);

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
            title: Text(t.settings.appearance),
            subtitle: Text(
              '${_getThemeModeText(themeState.mode)} · ${_getLanguageText(currentLocale)}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.settings.theme_mode),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(t.settings.theme_system),
                          icon: const Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(t.settings.theme_light),
                          icon: const Icon(Icons.wb_sunny_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(t.settings.theme_dark),
                          icon: const Icon(Icons.dark_mode_outlined),
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
                    Text(t.settings.theme_color),
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
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(t.settings.language),
                    const SizedBox(height: 8),
                    _buildLanguageSelector(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildLanguageChip(null),
        _buildLanguageChip(AppLocale.zh),
        _buildLanguageChip(AppLocale.zhTw),
        _buildLanguageChip(AppLocale.en),
        _buildLanguageChip(AppLocale.ja),
      ],
    );
  }

  Widget _buildLanguageChip(AppLocale? locale) {
    final currentLocale = ref.watch(localeProvider);
    final isSelected = currentLocale == locale;

    return ChoiceChip(
      label: Text(_getLanguageText(locale)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(localeProvider.notifier).setLocale(locale);
        }
      },
    );
  }

  String _getLanguageText(AppLocale? locale) {
    if (locale == null) return t.settings.language_system;
    switch (locale) {
      case AppLocale.zh:
        return t.settings.language_zh;
      case AppLocale.en:
        return t.settings.language_en;
      case AppLocale.ja:
        return t.settings.language_ja;
      case AppLocale.zhTw:
        return t.settings.language_zh_tw;
    }
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
        return t.settings.theme_system;
      case ThemeMode.light:
        return t.settings.theme_light;
      case ThemeMode.dark:
        return t.settings.theme_dark;
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
            title: Text(t.settings.data_management),
            subtitle: Text(t.settings.data_management_desc),
            children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(t.settings.export_data),
                subtitle: Text(t.settings.export_desc),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(t.settings.import_data),
                subtitle: Text(t.settings.import_desc),
                trailing: const Icon(Icons.chevron_right),
                onTap: _importData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(t.settings.restore_snapshot),
                subtitle: Text(t.settings.restore_desc),
                trailing: const Icon(Icons.chevron_right),
                onTap: _restoreFromSnapshot,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.wifi_protected_setup_outlined),
                title: Text(t.settings.lan_transfer),
                subtitle: Text(t.settings.lan_transfer_desc),
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
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(t.settings.exporting_data),
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
              title: Text(t.settings.export_success),
              content: Text(
                t.settings.export_success_desc(path: exportFile.path),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.common.ok),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关掉 loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.settings.export_failed(error: e.toString())),
          ),
        );
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
        title: Text(t.settings.confirm_restore),
        content: Text(t.settings.confirm_restore_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.restore),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(t.settings.restoring_data),
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
              t.settings.restore_success(
                diaries: importResult.diariesImported,
                summaries: importResult.summariesImported,
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              importResult.error ?? t.settings.restore_failed_generic,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关掉 loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.settings.restore_failed(error: e.toString())),
          ),
        );
      }
    }
  }

  /// 从本地 snapshots/ 目录列出历史快照，让用户选择后恢复
  Future<void> _restoreFromSnapshot() async {
    final appDir = await getApplicationDocumentsDirectory();
    final snapshotDir = Directory('${appDir.path}/snapshots');

    if (!snapshotDir.existsSync()) {
      if (mounted) AppToast.show(context, t.settings.no_snapshots_available);
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
      if (mounted) AppToast.show(context, t.settings.no_snapshots_available);
      return;
    }

    if (!mounted) return;

    final selected = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.settings.select_snapshot_to_restore),
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
            child: Text(t.common.cancel),
          ),
        ],
      ),
    );

    if (selected == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.settings.confirm_restore),
        content: Text(t.settings.confirm_restore_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.restore),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(t.settings.restoring_data),
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
          t.settings.restore_success(
            diaries: importResult.diariesImported,
            summaries: importResult.summariesImported,
          ),
          duration: const Duration(seconds: 4),
        );
      } else {
        AppToast.showError(
          context,
          importResult.error ?? t.settings.restore_failed_generic,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppToast.showError(
          context,
          t.settings.restore_failed(error: e.toString()),
        );
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
            title: Text(t.settings.about_baishou),
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
            title: Text(t.settings.development_philosophy),
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
            title: Text(t.settings.feedback),
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
