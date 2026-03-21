/// Agent 主页面
///
/// 侧边栏两区布局：功能选项区 + 对话历史区

import 'dart:io';

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/agent/presentation/pages/agent_chat_page.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AgentMainPage extends ConsumerStatefulWidget {
  const AgentMainPage({super.key});

  @override
  ConsumerState<AgentMainPage> createState() => _AgentMainPageState();
}

class _AgentMainPageState extends ConsumerState<AgentMainPage> {
  List<AgentSession>? _sessions;
  bool _isLoading = true;
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final manager = ref.read(sessionManagerProvider);
      final sessions = (await manager.getSessions()).toList();

      setState(() {
        _sessions = sessions;
        if ((_selectedSessionId == null ||
                !sessions.any((s) => s.id == _selectedSessionId)) &&
            sessions.isNotEmpty) {
          _selectedSessionId = sessions.first.id;
        }
        _isLoading = false;
      });

      if (_selectedSessionId != null && _selectedSessionId!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final notifier = ref.read(agentChatProvider.notifier);
          notifier.loadSession(_selectedSessionId!);
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// 仅刷新会话列表（不触发 loadSession，避免中断正在进行的生成）
  Future<void> _refreshSessionList() async {
    try {
      final manager = ref.read(sessionManagerProvider);
      final sessions = (await manager.getSessions()).toList();
      if (mounted) {
        setState(() => _sessions = sessions);
      }
    } catch (_) {}
  }

  Future<void> _deleteSession(String id) async {
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.sessions.delete_title),
        content: Text(
          t.agent.sessions.delete_confirm.replaceAll('{title}', ''),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(t.agent.sessions.delete_btn),
          ),
        ],
      ),
    );
    if (act == true) {
      await ref.read(sessionManagerProvider).deleteSession(id);
      if (_selectedSessionId == id) {
        _selectedSessionId = null;
        ref.read(agentChatProvider.notifier).clearChat();
      }
      _loadSessions();
    }
  }

  Future<void> _renameSession(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.sessions.rename),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: t.agent.sessions.rename_hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(controller.text),
            child: Text(t.common.save),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await ref.read(sessionManagerProvider).renameSession(id, newName.trim());
      _loadSessions();
    }
  }

  Future<void> _createNewSession() async {
    final notifier = ref.read(agentChatProvider.notifier);
    notifier.clearChat();
    setState(() {
      _selectedSessionId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听 sessionId 变化
    ref.listen<AgentChatState>(agentChatProvider, (prev, next) {
      if (prev?.sessionId != next.sessionId && next.sessionId != null) {
        if (_selectedSessionId == null) {
          setState(() => _selectedSessionId = next.sessionId);
          _refreshSessionList();
        }
      }
    });

    final theme = Theme.of(context);
    final isDesktop =
        MediaQuery.of(context).size.width >= 700 ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux;

    if (!isDesktop) {
      return Scaffold(
        body: const AgentChatPage(),
        drawer: Drawer(child: _buildSidebar(theme)),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          _buildSidebar(theme),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(-5, 0),
                  ),
                ],
              ),
              child: const AgentChatPage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    final userProfile = ref.watch(userProfileProvider);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── 顶部品牌区 ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agent',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── 新对话按钮 ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                onPressed: _createNewSession,
                icon: const Icon(Icons.add, size: 18),
                label: Text(t.agent.sessions.new_chat),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // ─── 功能选项区 ───
            _SidebarMenuItem(
              icon: Icons.settings_rounded,
              label: t.settings.title,
              isSelected: false,
              theme: theme,
              onTap: () => context.push('/settings'),
            ),

            const SizedBox(height: 8),

            // ─── 对话历史区 ───
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                '最近对话',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_sessions == null || _sessions!.isEmpty)
                  ? Center(
                      child: Text(
                        t.agent.sessions.no_history,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _sessions!.length,
                      itemBuilder: (context, index) {
                        final session = _sessions![index];
                        final isSelected = session.id == _selectedSessionId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() => _selectedSessionId = session.id);
                            ref
                                .read(agentChatProvider.notifier)
                                .loadSession(session.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.5)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                if (session.isPinned)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 13,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    session.title.isEmpty
                                        ? t.agent.sessions.new_chat
                                        : session.title,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_horiz,
                                      size: 16,
                                      color: theme.colorScheme.outline,
                                    ),
                                    padding: EdgeInsets.zero,
                                    tooltip: t.agent.sessions.actions,
                                    onSelected: (action) async {
                                      if (action == 'pin') {
                                        await ref
                                            .read(sessionManagerProvider)
                                            .togglePinSession(
                                              session.id,
                                              !session.isPinned,
                                            );
                                        _loadSessions();
                                      } else if (action == 'rename') {
                                        _renameSession(
                                          session.id,
                                          session.title,
                                        );
                                      } else if (action == 'delete') {
                                        _deleteSession(session.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'pin',
                                        child: Row(
                                          children: [
                                            Icon(
                                              session.isPinned
                                                  ? Icons.push_pin_outlined
                                                  : Icons.push_pin,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              session.isPinned
                                                  ? t.agent.sessions.unpin
                                                  : t.agent.sessions.pin,
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit, size: 18),
                                            const SizedBox(width: 8),
                                            Text(t.agent.sessions.rename),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: theme.colorScheme.error,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              t.agent.sessions.delete_session,
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),

            // ─── 底部用户卡片 ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: userProfile.avatarPath != null
                        ? FileImage(File(userProfile.avatarPath!))
                        : null,
                    child: userProfile.avatarPath == null
                        ? Text(
                            userProfile.nickname.isNotEmpty
                                ? userProfile.nickname[0].toUpperCase()
                                : 'U',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      userProfile.nickname.isNotEmpty
                          ? userProfile.nickname
                          : t.settings.default_nickname,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

// ─── 侧边栏菜单项 ───────────────────────────────────────────

class _SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final ThemeData theme;
  final VoidCallback onTap;

  const _SidebarMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
