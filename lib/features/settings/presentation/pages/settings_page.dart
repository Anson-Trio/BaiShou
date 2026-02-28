import 'dart:io';
import 'package:baishou/features/settings/presentation/pages/views/ai_global_models_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/ai_model_services_view.dart';
import 'package:baishou/features/settings/presentation/pages/data_sync_page.dart';
import 'package:baishou/features/settings/presentation/pages/views/general_settings_view.dart';
import 'package:baishou/i18n/strings.g.dart';
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
            Expanded(
              child: Text(
                title,
                softWrap: true,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
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
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: Text(t.settings.title), centerTitle: true),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(t.settings.general),
            trailing: const Icon(Icons.chevron_right),
            // 使用 context.push 让子页走根 Navigator，脱离 settingsNavKey 内部栈，
            // 防止切换到其它 Tab 后，隐藏中的子页被侧滑手势静默消耗
            onTap: () => context.push('/settings/general'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_queue_outlined),
            title: Text(t.settings.ai_services),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ai-services'),
          ),
          ListTile(
            leading: const Icon(Icons.star_border_rounded),
            title: Text(t.settings.ai_global_models),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/ai-models'),
          ),
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: Text(t.data_sync.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/data-sync'),
          ),
        ],
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
                        tooltip: t.common.cancel,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.settings.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSidebarTab(
                  t.settings.general,
                  Icons.settings_outlined,
                  0,
                ),
                _buildSidebarTab(
                  t.settings.ai_services,
                  Icons.cloud_queue_outlined,
                  1,
                ),
                _buildSidebarTab(
                  t.settings.ai_global_models,
                  Icons.star_border_rounded,
                  2,
                ),
                _buildSidebarTab(t.data_sync.title, Icons.sync_rounded, 3),
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
