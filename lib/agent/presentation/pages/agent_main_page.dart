/// Agent 主页面
///
/// 侧边栏两区布局：功能选项区 + 对话历史区

import 'dart:async';
import 'dart:io';

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/agent_chat_page.dart';
import 'package:baishou/agent/presentation/widgets/agent_sidebar.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentMainPage extends ConsumerStatefulWidget {
  const AgentMainPage({super.key});

  @override
  ConsumerState<AgentMainPage> createState() => _AgentMainPageState();
}

class _AgentMainPageState extends ConsumerState<AgentMainPage> {
  List<AgentSession>? _sessions;
  bool _isLoading = true;
  String? _selectedSessionId;
  AgentAssistant? _currentAssistant;
  bool _isSidebarCollapsed = false;
  
  int _sessionLimit = 8;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initAssistantAndSessions();
  }

  Future<void> _initAssistantAndSessions() async {
    try {
      final service = ref.read(assistantServiceProvider);
      final assistant = await service.ensureAtLeastOneAssistant();
      
      // 强制刷新相关 Provider 以通知整个应用状态已更新（解决首次创建或旧版升级空状态下，即使有了助手但列表由于之前的 Future 数据缓存还是为空的问题）
      ref.invalidate(assistantListProvider);
      ref.invalidate(assistantListStreamProvider);

      if (mounted) {
        setState(() => _currentAssistant = assistant);
        ref.read(agentChatProvider.notifier).setCurrentAssistantId(assistant.id);
        await _loadSessions();
      }
    } catch (e) {
      debugPrint('[AgentMainPage] _initAssistantAndSessions failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(context, '伙伴初始化失败: $e');
      }
    }
  }

  StreamSubscription<List<AgentSession>>? _sessionsSubscription;

  Future<void> _loadSessions() async {
    if (_currentAssistant == null) return;
    
    if (_sessions == null) {
      setState(() => _isLoading = true);
    }
    try {
      final manager = ref.read(sessionManagerProvider);
      final vaultInfo = await ref.read(vaultServiceProvider.future);
      final vaultName = vaultInfo?.name ?? 'Personal';

      await _sessionsSubscription?.cancel();
      _sessionsSubscription = manager
          .watchSessionsByAssistant(
            _currentAssistant!.id, 
            vaultName,
            limit: _searchQuery.isNotEmpty ? null : _sessionLimit,
            searchQuery: _searchQuery,
          )
          .listen((sessions) {
            if (!mounted) return;

            final previousSelectedId = _selectedSessionId;
            setState(() {
              _sessions = sessions;
              if ((_selectedSessionId == null ||
                      !sessions.any((s) => s.id == _selectedSessionId)) &&
                  sessions.isNotEmpty) {
                _selectedSessionId = sessions.first.id;
              }
              _isLoading = false;
            });

            if (_selectedSessionId != previousSelectedId &&
                _selectedSessionId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final notifier = ref.read(agentChatProvider.notifier);
                notifier.loadSession(_selectedSessionId!);
              });
            }
          });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _createNewSession() {
    final notifier = ref.read(agentChatProvider.notifier);
    notifier.clearChat();
    if (_currentAssistant != null) {
      notifier.setCurrentAssistantId(_currentAssistant!.id);
    }
    setState(() {
      _selectedSessionId = null;
    });
    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  void _switchAssistant(AgentAssistant assistant) {
    setState(() {
      _currentAssistant = assistant;
      _selectedSessionId = null;
      _sessions = null;
      _sessionLimit = 8;
      _searchQuery = '';
    });
    ref.read(agentChatProvider.notifier).clearChat();
    ref.read(agentChatProvider.notifier).setCurrentAssistantId(assistant.id);
    _loadSessions();
  }

  void _onSearchQueryChanged(String query) {
    if (_searchQuery != query) {
      setState(() {
        _searchQuery = query;
        _sessionLimit = 8; // 搜索时重置分页
      });
      _loadSessions();
    }
  }

  void _onLoadMore() {
    setState(() {
      _sessionLimit += 8;
    });
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 Vault 变化 (当切换工作空间时，重置所有状态并重新加载)
    ref.listen(vaultServiceProvider, (prev, next) {
      if (prev?.value?.name != next.value?.name) {
        ref.read(agentChatProvider.notifier).clearChat();
        setState(() {
          _selectedSessionId = null;
          _currentAssistant = null;
        });
        _initAssistantAndSessions();
      }
    });

    // 监听 sessionId 变化
    ref.listen<AgentChatState>(agentChatProvider, (prev, next) {
      if (prev?.sessionId != next.sessionId) {
        if (next.sessionId == null) {
          if (_selectedSessionId != null) {
            setState(() => _selectedSessionId = null);
          }
        } else if (_selectedSessionId == null) {
          setState(() {
            _selectedSessionId = next.sessionId;
            _sessionLimit = 8;
          });
          _loadSessions();
        }
      }
    });

    final theme = Theme.of(context);
    final isDesktop =
        MediaQuery.of(context).size.width >= 700 ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux;

    final sidebar = AgentSidebar(
      currentAssistant: _currentAssistant,
      sessions: _sessions,
      isLoading: _isLoading,
      selectedSessionId: _selectedSessionId,
      searchQuery: _searchQuery,
      hasMore: _searchQuery.isEmpty && (_sessions?.length ?? 0) >= _sessionLimit,
      onSearchQueryChanged: _onSearchQueryChanged,
      onLoadMore: _onLoadMore,
      onSessionSelected: (id) {
        setState(() => _selectedSessionId = id);
        ref.read(agentChatProvider.notifier).loadSession(id);
      },
      onNewSession: _createNewSession,
      onAssistantSwitched: _switchAssistant,
      onSessionsChanged: _loadSessions,
      onCollapse: () => setState(() => _isSidebarCollapsed = true),
    );

    if (!isDesktop) {
      return Scaffold(
        body: const AgentChatPage(),
        drawerEdgeDragWidth: 120,
        drawer: Drawer(
          width: 280,
          child: sidebar,
        ),
        onDrawerChanged: (isOpened) {
          if (!isOpened) {
            // 侧边栏关闭时彻底取消焦点树，防止传递给文本框
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          if (!_isSidebarCollapsed)
            SizedBox(width: 280, child: sidebar)
          else
            _buildCollapsedSidebar(theme),
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

  Widget _buildCollapsedSidebar(ThemeData theme) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 20),
            tooltip: '展开侧边栏',
            onPressed: () => setState(() => _isSidebarCollapsed = false),
          ),
        ],
      ),
    );
  }
}
