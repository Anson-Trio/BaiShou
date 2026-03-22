import 'dart:io';
import 'package:baishou/features/settings/presentation/pages/views/ai_global_models_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/ai_model_services_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/agent_tools_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/rag_memory_view.dart';
import 'package:baishou/features/settings/presentation/pages/data_sync_page.dart';
import 'package:baishou/features/settings/presentation/pages/lan_transfer_page.dart';
import 'package:baishou/features/settings/presentation/pages/views/general_settings_view.dart';
import 'package:baishou/features/settings/presentation/pages/views/summary_settings_view.dart';
import 'package:baishou/agent/presentation/pages/assistant_management_page.dart';
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
        return const AssistantManagementPage(key: ValueKey('tab_assistants'));
      case 4:
        return const RagMemoryView(key: ValueKey('tab_rag'));
      case 5:
        return const AgentToolsView(key: ValueKey('tab_tools'));
      case 6:
        return const SummarySettingsView(key: ValueKey('tab_summary'));
      case 7:
        return const LanTransferPage(key: ValueKey('tab_lan'));
      case 8:
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
          // ─── 通用 ───
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(t.settings.general),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/general'),
          ),
          const Divider(height: 1),
          // ─── AI 配置 ───
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
            leading: const Icon(Icons.school),
            title: Text(t.agent.assistant.settings_entry),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/assistants'),
          ),
          const Divider(height: 1),
          // ─── 功能 ───
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text(t.agent.rag.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/rag'),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: Text(t.settings.agent_tools_title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/agent-tools'),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(t.settings.summary_settings_title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/summary'),
          ),
          const Divider(height: 1),
          // ─── 数据 ───
          ListTile(
            leading: const Icon(Icons.wifi_protected_setup_outlined),
            title: Text(t.settings.lan_transfer),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/lan-transfer'),
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ─── 通用 ───
                        _buildSidebarTab(
                          t.settings.general,
                          Icons.settings_outlined,
                          0,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        // ─── AI 配置 ───
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
                        _buildSidebarTab(
                          t.agent.assistant.settings_entry,
                          Icons.school,
                          3,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        // ─── 功能 ───
                        _buildSidebarTab(
                          t.agent.rag.title,
                          Icons.psychology_outlined,
                          4,
                        ),
                        _buildSidebarTab(
                          t.settings.agent_tools_title,
                          Icons.extension_outlined,
                          5,
                        ),
                        _buildSidebarTab(
                          t.settings.summary_settings_title,
                          Icons.auto_awesome_outlined,
                          6,
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        // ─── 数据 ───
                        _buildSidebarTab(
                          t.settings.lan_transfer,
                          Icons.wifi_protected_setup_outlined,
                          7,
                        ),
                        _buildSidebarTab(
                          t.data_sync.title,
                          Icons.sync_rounded,
                          8,
                        ),
                      ],
                    ),
                  ),
                ),
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
