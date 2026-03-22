/// Agent 主页面
///
/// 侧边栏两区布局：功能选项区 + 对话历史区

import 'dart:io';

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/agent_chat_page.dart';
import 'package:baishou/agent/presentation/widgets/assistant_picker_sheet.dart';
import 'package:baishou/agent/presentation/widgets/session_list_tile.dart';
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

  // 当前伙伴
  AgentAssistant? _currentAssistant;

  // 批量删除
  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _initAssistantAndSessions();
  }

  Future<void> _initAssistantAndSessions() async {
    final service = ref.read(assistantServiceProvider);
    final assistant = await service.ensureDefaultAssistant();
    if (mounted) {
      setState(() => _currentAssistant = assistant);
      await _loadSessions();
    }
  }

  Future<void> _loadSessions() async {
    if (_currentAssistant == null) return;
    setState(() => _isLoading = true);
    try {
      final manager = ref.read(sessionManagerProvider);
      final sessions = await manager.getSessionsByAssistant(
        _currentAssistant!.id,
      );

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
    if (_currentAssistant == null) return;
    try {
      final manager = ref.read(sessionManagerProvider);
      final sessions = await manager.getSessionsByAssistant(
        _currentAssistant!.id,
      );
      if (mounted) {
        setState(() => _sessions = sessions);
      }
    } catch (_) {}
  }

  Future<void> _deleteSession(String id, String title) async {
    final displayTitle = title.isEmpty ? t.agent.sessions.new_chat : title;
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.sessions.delete_title),
        content: Text(
          t.agent.sessions.delete_confirm.replaceAll('{title}', displayTitle),
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
    // 绑定当前伙伴
    if (_currentAssistant != null) {
      // 会话创建时 agentChatProvider 会自动绑定 assistantId
      // 我们在 clearChat 后设定当前 assistantId
      notifier.setCurrentAssistantId(_currentAssistant!.id);
    }
    setState(() {
      _selectedSessionId = null;
    });
  }

  Future<void> _switchAssistant(AgentAssistant assistant) async {
    setState(() {
      _currentAssistant = assistant;
      _selectedSessionId = null;
      _sessions = null;
      _isMultiSelect = false;
      _selectedIds.clear();
    });
    // 清空当前聊天并加载新伙伴的会话
    ref.read(agentChatProvider.notifier).clearChat();
    ref.read(agentChatProvider.notifier).setCurrentAssistantId(assistant.id);
    await _loadSessions();
  }

  Future<void> _showAssistantSwitcher() async {
    if (!mounted) return;

    final (didSelect, selected) = await AssistantPickerSheet.show(
      context,
      currentAssistantId: _currentAssistant?.id.toString(),
    );

    if (!didSelect || selected == null) return;
    _switchAssistant(selected);
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

            // ─── 当前伙伴区域 ───
            if (_currentAssistant != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: InkWell(
                  onTap: _showAssistantSwitcher,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _currentAssistant!.emoji ?? '🍵',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentAssistant!.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_currentAssistant!.description.isNotEmpty)
                                Text(
                                  _currentAssistant!.description,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.unfold_more,
                          size: 18,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 4),

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
            SidebarMenuItem(
              icon: Icons.settings_rounded,
              label: t.settings.title,
              isSelected: false,
              onTap: () => context.push('/settings'),
            ),

            const SizedBox(height: 8),

            // ─── 对话历史区标题 ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    t.agent.chat.recent_chats,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_sessions != null && _sessions!.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _isMultiSelect = !_isMultiSelect;
                        _selectedIds.clear();
                      }),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _isMultiSelect
                              ? Icons.close
                              : Icons.checklist_rounded,
                          size: 16,
                          color: _isMultiSelect
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ),
                ],
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

                        return SessionListTile(
                          key: ValueKey(session.id),
                          session: session,
                          isSelected: isSelected,
                          isMultiSelect: _isMultiSelect,
                          isChecked: _selectedIds.contains(session.id),
                          onTap: () {
                            setState(() => _selectedSessionId = session.id);
                            ref
                                .read(agentChatProvider.notifier)
                                .loadSession(session.id);
                          },
                          onCheckChanged: (v) => setState(() {
                            if (v == true) {
                              _selectedIds.add(session.id);
                            } else {
                              _selectedIds.remove(session.id);
                            }
                          }),
                          onPin: () async {
                            await ref
                                .read(sessionManagerProvider)
                                .togglePinSession(
                                  session.id,
                                  !session.isPinned,
                                );
                            _loadSessions();
                          },
                          onRename: () => _renameSession(
                            session.id,
                            session.title,
                          ),
                          onDelete: () => _deleteSession(
                            session.id,
                            session.title,
                          ),
                        );
                      },
                    ),
            ),

            // ─── 批量删除操作栏 ───
            if (_isMultiSelect && _sessions != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        if (_selectedIds.length == _sessions!.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(_sessions!.map((s) => s.id));
                        }
                      }),
                      child: Text(
                        _selectedIds.length == _sessions!.length
                            ? t.agent.chat.deselect_all
                            : t.agent.chat.select_all,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () async {
                              final count = _selectedIds.length;
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(t.agent.sessions.delete_title),
                                  content: Text(t.agent.chat.delete_confirm_multi(count: count)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(t.common.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.error,
                                      ),
                                      child: Text(t.agent.chat.delete_count(count: count)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref
                                    .read(sessionManagerProvider)
                                    .deleteSessions(_selectedIds.toList());
                                if (_selectedIds.contains(_selectedSessionId)) {
                                  _selectedSessionId = null;
                                  ref
                                      .read(agentChatProvider.notifier)
                                      .clearChat();
                                }
                                _selectedIds.clear();
                                _isMultiSelect = false;
                                _loadSessions();
                              }
                            },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(t.agent.chat.delete_count(count: _selectedIds.length)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _selectedIds.isEmpty
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.error,
                        foregroundColor: _selectedIds.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onError,
                      ),
                    ),
                  ],
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
