/// Agent 会话列表页面
///
/// 显示历史对话列表，支持点击继续对话、滑动删除

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AgentSessionsPage extends ConsumerStatefulWidget {
  const AgentSessionsPage({super.key});

  @override
  ConsumerState<AgentSessionsPage> createState() => _AgentSessionsPageState();
}

class _AgentSessionsPageState extends ConsumerState<AgentSessionsPage> {
  List<AgentSession>? _sessions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final manager = ref.read(sessionManagerProvider);
      final sessions = await manager.getSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSession(String id) async {
    final manager = ref.read(sessionManagerProvider);
    await manager.deleteSession(id);
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('对话历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新对话',
            onPressed: () => context.push('/agent/chat'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions == null || _sessions!.isEmpty
              ? _buildEmptyState(theme)
              : _buildSessionList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有对话记录',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/agent/chat'),
            icon: const Icon(Icons.add),
            label: const Text('开始新对话'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(ThemeData theme) {
    final dateFormat = DateFormat('MM/dd HH:mm');

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sessions!.length,
        itemBuilder: (context, index) {
          final session = _sessions![index];

          return Dismissible(
            key: Key(session.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除对话'),
                      content: Text('确定删除"${session.title}"？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  ) ??
                  false;
            },
            onDismissed: (_) => _deleteSession(session.id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: theme.colorScheme.error,
              child: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.onError,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              title: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${session.modelId} · ${dateFormat.format(session.updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
              onTap: () {
                context.push('/agent/chat?sessionId=${session.id}');
              },
            ),
          );
        },
      ),
    );
  }
}
