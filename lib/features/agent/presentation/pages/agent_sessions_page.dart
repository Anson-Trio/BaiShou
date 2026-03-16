/// Agent 会话列表页面
///
/// 显示历史对话列表，支持点击继续对话、滑动删除
/// 显示每个会话的 token 用量和费用

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/core/services/api_config_service.dart';
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

  /// 格式化费用（micros → 美元显示）
  String _formatCost(int costMicros) {
    if (costMicros == 0) return '';
    final dollars = costMicros / 1000000;
    if (dollars < 0.01) {
      return '\$${dollars.toStringAsFixed(4)}';
    }
    return '\$${dollars.toStringAsFixed(2)}';
  }

  /// 格式化 token 数量
  String _formatTokens(int tokens) {
    if (tokens == 0) return '';
    if (tokens < 1000) return '$tokens';
    if (tokens < 1000000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return '${(tokens / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('对话历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Agent 设置',
            onPressed: () => _showSettingsSheet(context),
          ),
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
          final isCompanion =
              session.id == SessionManager.companionSessionId;
          final totalTokens =
              session.totalInputTokens + session.totalOutputTokens;
          final cost = _formatCost(session.totalCostMicros);
          final tokens = _formatTokens(totalTokens);

          return Dismissible(
            key: Key(session.id),
            direction: isCompanion
                ? DismissDirection.none // 伴侣模式不允许删除
                : DismissDirection.endToStart,
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
                backgroundColor: isCompanion
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.primaryContainer,
                child: Icon(
                  isCompanion ? Icons.favorite_rounded : Icons.smart_toy_outlined,
                  color: isCompanion
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              title: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  // 模型 + 时间
                  Expanded(
                    child: Text(
                      '${session.modelId} · ${dateFormat.format(session.updatedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Token 统计 + 费用
                  if (tokens.isNotEmpty || cost.isNotEmpty)
                    Text(
                      [tokens, cost].where((s) => s.isNotEmpty).join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                ],
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

  /// Agent 设置底部弹窗
  void _showSettingsSheet(BuildContext context) {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final companionMode = apiConfig.agentCompanionMode;
            final windowSize = apiConfig.agentContextWindowSize;
            final persona = apiConfig.agentPersona;
            final guidelines = apiConfig.agentGuidelines;

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (ctx, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 拖拽手柄
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Text(
                        'Agent 设置',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),

                      // 伴侣模式开关
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('伴侣模式'),
                        subtitle: Text(
                          companionMode
                              ? '已开启 — 单一持续对话，无会话概念'
                              : '已关闭 — 多会话模式',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        value: companionMode,
                        onChanged: (v) async {
                          await apiConfig.setAgentCompanionMode(v);
                          setSheetState(() {});
                        },
                      ),

                      const Divider(),

                      // 上下文窗口大小
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('上下文轮数'),
                        subtitle: Text(
                          '发送最近 $windowSize 条消息给模型',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: windowSize.toString(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            onFieldSubmitted: (v) async {
                              final size = int.tryParse(v);
                              if (size != null) {
                                await apiConfig
                                    .setAgentContextWindowSize(size);
                                setSheetState(() {});
                              }
                            },
                          ),
                        ),
                      ),

                      const Divider(),

                      // 角色人设
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('角色人设'),
                        subtitle: Text(
                          persona.length > 50
                              ? '${persona.substring(0, 50)}...'
                              : persona,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () async {
                          final result = await _showTextEditDialog(
                            context: context,
                            title: '角色人设',
                            hint: '描述 Agent 的身份和风格',
                            initialValue: persona,
                          );
                          if (result != null) {
                            await apiConfig.setAgentPersona(result);
                            setSheetState(() {});
                          }
                        },
                      ),

                      // 行为准则
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('行为准则'),
                        subtitle: Text(
                          guidelines.length > 50
                              ? '${guidelines.substring(0, 50)}...'
                              : guidelines,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () async {
                          final result = await _showTextEditDialog(
                            context: context,
                            title: '行为准则',
                            hint: '描述 Agent 需要遵守的规则',
                            initialValue: guidelines,
                          );
                          if (result != null) {
                            await apiConfig.setAgentGuidelines(result);
                            setSheetState(() {});
                          }
                        },
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 文本编辑对话框（全屏，用于输入角色人设 / 行为准则）
  Future<String?> _showTextEditDialog({
    required BuildContext context,
    required String title,
    required String hint,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(ctx, text.isEmpty ? null : text);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}
