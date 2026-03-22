/// Agent 主页面
///
/// 侧边栏两区布局：功能选项区 + 对话历史区

import 'dart:io';

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/agent_chat_page.dart';
import 'package:baishou/agent/presentation/pages/assistant_management_page.dart';
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
    final manager = ref.read(sessionManagerProvider);
    final allAssistants = await ref.read(assistantRepositoryProvider).getAll();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 550),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('选择伙伴', style: Theme.of(ctx).textTheme.titleLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AssistantManagementPage(),
                            ),
                          ).then((_) => _refreshCurrentAssistant());
                        },
                        child: const Text('管理'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _AssistantSwitcherList(
                      assistants: allAssistants,
                      currentAssistantId: _currentAssistant?.id ?? '',
                      sessionManager: manager,
                      onSelect: (assistant) {
                        Navigator.pop(ctx);
                        _switchAssistant(assistant);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshCurrentAssistant() async {
    // 管理页返回后，刷新当前伙伴（可能被编辑/删除）
    final repo = ref.read(assistantRepositoryProvider);
    if (_currentAssistant != null) {
      final updated = await repo.get(_currentAssistant!.id);
      if (updated != null) {
        setState(() => _currentAssistant = updated);
      } else {
        // 当前伙伴被删除，切换到默认
        final service = ref.read(assistantServiceProvider);
        final def = await service.ensureDefaultAssistant();
        setState(() => _currentAssistant = def);
      }
    }
    _loadSessions();
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
            _SidebarMenuItem(
              icon: Icons.settings_rounded,
              label: t.settings.title,
              isSelected: false,
              theme: theme,
              onTap: () => context.push('/settings'),
            ),

            const SizedBox(height: 8),

            // ─── 对话历史区标题 ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '最近对话',
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
                                  // 多选 checkbox
                                  if (_isMultiSelect)
                                    Checkbox(
                                      value: _selectedIds.contains(session.id),
                                      onChanged: (v) => setState(() {
                                        if (v == true) {
                                          _selectedIds.add(session.id);
                                        } else {
                                          _selectedIds.remove(session.id);
                                        }
                                      }),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
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
                                          _deleteSession(
                                            session.id,
                                            session.title,
                                          );
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
                            ? '取消全选'
                            : '全选',
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
                                  content: Text('确定删除 $count 个对话？此操作不可撤销。'),
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
                                      child: Text('删除 ($count)'),
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
                      label: Text('删除 (${_selectedIds.length})'),
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

// ─── 伙伴切换列表（弹窗内） ─────────────────────────────────────

class _AssistantSwitcherList extends StatefulWidget {
  final List<AgentAssistant> assistants;
  final String currentAssistantId;
  final SessionManager sessionManager;
  final void Function(AgentAssistant) onSelect;

  const _AssistantSwitcherList({
    required this.assistants,
    required this.currentAssistantId,
    required this.sessionManager,
    required this.onSelect,
  });

  @override
  State<_AssistantSwitcherList> createState() => _AssistantSwitcherListState();
}

class _AssistantSwitcherListState extends State<_AssistantSwitcherList> {
  // 每个伙伴的会话数和最近会话
  final Map<String, int> _sessionCounts = {};
  final Map<String, List<AgentSession>> _recentSessions = {};
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    for (final a in widget.assistants) {
      final count = await widget.sessionManager.getSessionCountByAssistant(
        a.id,
      );
      if (mounted) {
        setState(() => _sessionCounts[a.id] = count);
      }
    }
  }

  Future<void> _loadRecentSessions(String assistantId) async {
    if (_recentSessions.containsKey(assistantId)) return;
    final sessions = await widget.sessionManager.getRecentSessionsByAssistant(
      assistantId,
      limit: 5,
    );
    if (mounted) {
      setState(() => _recentSessions[assistantId] = sessions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      itemCount: widget.assistants.length,
      itemBuilder: (ctx, i) {
        final assistant = widget.assistants[i];
        final isCurrent = assistant.id == widget.currentAssistantId;
        final isExpanded = _expandedId == assistant.id;
        final count = _sessionCounts[assistant.id] ?? 0;

        return Column(
          children: [
            InkWell(
              onTap: () => widget.onSelect(assistant),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // emoji
                    Text(
                      assistant.emoji ?? '⭐',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    // 名称 + 会话数
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assistant.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            '$count 个对话${assistant.description.isNotEmpty ? ' · ${assistant.description}' : ''}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 当前标识
                    if (isCurrent)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    // 展开按钮
                    if (count > 0)
                      IconButton(
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedId = null;
                            } else {
                              _expandedId = assistant.id;
                              _loadRecentSessions(assistant.id);
                            }
                          });
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
            // 展开的最近会话
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 8),
                child: _recentSessions[assistant.id] == null
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Column(
                        children: _recentSessions[assistant.id]!.map((session) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 12,
                                  color: colorScheme.outline,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    session.title.isEmpty
                                        ? '新对话'
                                        : session.title,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
          ],
        );
      },
    );
  }
}
