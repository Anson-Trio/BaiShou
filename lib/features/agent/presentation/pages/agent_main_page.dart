/// Agent 主页面
///
/// 负责根据模式（陪伴/会话）展示不同布局：
/// - 深度陪伴模式：全屏聊天界面
/// - 会话模式：左侧边栏（会话列表 + 设置入口） + 右侧聊天界面

import 'dart:io';

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/features/agent/presentation/pages/agent_chat_page.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
      final sessions = (await manager.getSessions())
          .where((s) => s.id != SessionManager.companionSessionId)
          .toList();
      
      setState(() {
        _sessions = sessions;
        if ((_selectedSessionId == null || !sessions.any((s) => s.id == _selectedSessionId)) && sessions.isNotEmpty) {
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
      final sessions = (await manager.getSessions())
          .where((s) => s.id != SessionManager.companionSessionId)
          .toList();
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
        content: Text(t.agent.sessions.delete_confirm.replaceAll('{title}', '')),
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
          decoration: InputDecoration(
            hintText: t.agent.sessions.rename_hint,
          ),
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
      _selectedSessionId = null; // 新对话尚未创建，等用户发第一条消息后懒创建
    });
  }


  @override
  Widget build(BuildContext context) {
    final isCompanion = ref.watch(agentCompanionModeProvider);

    // 当从陪伴模式切换到会话模式时，自动重新加载会话列表
    ref.listen<bool>(agentCompanionModeProvider, (prev, next) {
      if (prev == true && next == false) {
        _loadSessions();
      }
    });

    // 监听 sessionId 变化，当新会话被懒创建时自动刷新侧边栏
    // 注意：只更新 UI 侧边栏，不能调用 loadSession，否则会中断正在进行的 sendMessage
    ref.listen<AgentChatState>(agentChatProvider, (prev, next) {
      if (prev?.sessionId != next.sessionId && next.sessionId != null) {
        if (_selectedSessionId == null) {
          setState(() => _selectedSessionId = next.sessionId);
          // 异步刷新会话列表（不触发 loadSession）
          _refreshSessionList();
        }
      }
    });

    if (isCompanion) {
       // 全屏陪伴模式
       return Scaffold(
         body: const AgentChatPage(),
       );
    }

    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700 || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    if (!isDesktop) {
       // 手机端直接用普通页
       return Scaffold(
         body: const AgentChatPage(),
         drawer: Drawer(
           child: _buildSidebar(theme),
         ),
       );
    }

    // 桌面端双栏布局
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
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部返回按钮与标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/'),
                  tooltip: t.common.back,
                ),
                const SizedBox(width: 8),
                Text(
                  t.agent.sessions.history,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 新建对话按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                _createNewSession();
              },
              icon: const Icon(Icons.add),
              label: Text(t.agent.sessions.new_chat),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 会话列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_sessions == null || _sessions!.isEmpty)
                    ? Center(child: Text(t.agent.sessions.no_history))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _sessions!.length,
                        itemBuilder: (context, index) {
                          final session = _sessions![index];
                          final isSelected = session.id == _selectedSessionId;
                          final dateFormat = DateFormat('MM/dd');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                setState(() => _selectedSessionId = session.id);
                                ref.read(agentChatProvider.notifier).loadSession(session.id);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.5) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18,
                                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          if (session.isPinned)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4),
                                              child: Icon(Icons.push_pin, size: 14, color: theme.colorScheme.primary),
                                            ),
                                          Expanded(
                                            child: Text(
                                              session.title.isEmpty ? t.agent.sessions.new_chat : session.title,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isSelected) 
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: t.agent.sessions.actions,
                                        onSelected: (action) async {
                                          if (action == 'pin') {
                                            await ref.read(sessionManagerProvider).togglePinSession(session.id, !session.isPinned);
                                            _loadSessions();
                                          } else if (action == 'rename') {
                                            _renameSession(session.id, session.title);
                                          } else if (action == 'delete') {
                                            _deleteSession(session.id);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'pin',
                                            child: Row(
                                              children: [
                                                Icon(session.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 18),
                                                const SizedBox(width: 8),
                                                Text(session.isPinned ? t.agent.sessions.unpin : t.agent.sessions.pin),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'rename',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18),
                                                SizedBox(width: 8),
                                                Text(t.agent.sessions.rename),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                                                const SizedBox(width: 8),
                                                Text(t.agent.sessions.delete_session, style: TextStyle(color: theme.colorScheme.error)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        dateFormat.format(session.createdAt),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 底部设置入口
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: InkWell(
              onTap: () => context.push('/settings'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      t.settings.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
