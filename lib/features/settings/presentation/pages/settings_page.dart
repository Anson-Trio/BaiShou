import 'dart:io';
import 'package:baishou/features/settings/presentation/pages/views/ai_global_models_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/ai_model_services_view.dart';
import 'package:baishou/features/settings/presentation/pages/data_sync_page.dart';
import 'package:baishou/features/settings/presentation/pages/views/general_settings_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 系统设置页面
/// 采用双栏布局（桌面端）或列表导航（移动端）展示各项设置。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _activeTab = 0;

  Widget _buildSidebarTab(String title, IconData icon, int index) {
    final isSelected = _activeTab == index;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withOpacity(0.4)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getActiveView() {
    switch (_activeTab) {
      case 0:
        return const GeneralSettingsView(key: ValueKey('tab_general'));
      case 1:
        return const AiModelServicesView(key: ValueKey('tab_models'));
      case 2:
        return const AiGlobalModelsView(key: ValueKey('tab_global'));
      case 3:
        return const DataSyncPage(key: ValueKey('tab_sync'));
      default:
        return const SizedBox();
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(title: const Text('系统设置'), centerTitle: true),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('常规设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('常规设置')),
                      body: const GeneralSettingsView(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_queue_outlined),
              title: const Text('模型服务'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('模型服务')),
                      body: const AiModelServicesView(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border_rounded),
              title: const Text('全局模型'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('全局模型')),
                      body: const AiGlobalModelsView(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('数据同步'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('数据同步')),
                      body: const DataSyncPage(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar for Tabs
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                        tooltip: '返回',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '系统设置',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSidebarTab('常规设置', Icons.settings_outlined, 0),
                _buildSidebarTab('模型服务', Icons.cloud_queue_outlined, 1),
                _buildSidebarTab('全局模型', Icons.star_border_rounded, 2),
                _buildSidebarTab('数据同步', Icons.sync_rounded, 3),
              ],
            ),
          ),

          Expanded(child: _getActiveView()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isMobile = true;
      }
    } catch (e) {}

    if (isMobile) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }
}
