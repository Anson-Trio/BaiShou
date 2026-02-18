import 'package:baishou/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildAboutSection()],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias, // 确保 InkWell涟漪不溢出
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于白守'),
            subtitle: const Text('v0.3.1 (Pre-Launch)'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 跳转隐私政策
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
