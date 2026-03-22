/// Agent 聊天页面
///
/// 全屏覆盖路由，包含消息列表和输入框

import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/widgets/assistant_picker_sheet.dart';
import 'package:baishou/agent/presentation/widgets/chat_input_bar.dart';
import 'package:baishou/agent/presentation/widgets/chat_message_bubble.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentChatPage extends ConsumerStatefulWidget {
  final String? sessionId;

  const AgentChatPage({super.key, this.sessionId});

  @override
  ConsumerState<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends ConsumerState<AgentChatPage> {
  final _scrollController = ScrollController();
  final _promptController = TextEditingController();
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.sessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(agentChatProvider.notifier).loadSession(widget.sessionId!);
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 逆序排列下，pixels 接近 0 表示在列表的最底端（最新消息处）
    final atBottom = pos.pixels <= 80;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = false}) {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          if (animate) {
            _scrollController.animateTo(
              0, // target is 0 for reversed list
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(0);
          }
          if (mounted) setState(() => _isAtBottom = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(agentChatProvider);
    final theme = Theme.of(context);

    // 监听消息变化，仅在底部时自动滚动
    ref.listen(agentChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.streamingText != next.streamingText) {
        if (_isAtBottom) {
          _scrollToBottom();
        }
      }
    });

    // 获取当前模型名称
    final apiConfig = ref.watch(apiConfigServiceProvider);

    // 解析当前伙伴名称 + 绑定模型
    final currentAssistantId = chatState.currentAssistantId;
    final assistantsAsync = ref.watch(assistantListProvider);
    final assistantData = assistantsAsync.whenOrNull(
      data: (list) {
        if (currentAssistantId == null) return null;
        final match = list.where((a) => a.id.toString() == currentAssistantId);
        return match.isNotEmpty ? match.first : null;
      },
    );
    final assistantName = assistantData?.name;
    // 优先显示伙伴绑定模型，否则回退到全局模型
    final currentModel =
        assistantData?.modelId ?? apiConfig.globalDialogueModelId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 当前模型名称 + 伙伴名称
            if (currentModel.isNotEmpty || assistantName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (assistantName != null) '✨ $assistantName',
                    if (currentModel.isNotEmpty) currentModel,
                  ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        actions: [
          if (chatState.totalCostMicros > 0 || chatState.totalInputTokens > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t.agent.chat.cost_detail_title),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 累计统计 ──
                            Text(
                              t.agent.chat.cost_cumulative_title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CostRow(
                              label: t.agent.chat.cost_cumulative_total,
                              value:
                                  '\$${(chatState.totalCostMicros / 1000000).toStringAsFixed(6)}',
                            ),
                            _CostRow(
                              label: t.agent.chat.cost_cumulative_input,
                              value:
                                  '${chatState.totalInputTokens} ${t.agent.chat.tokens_unit}',
                            ),
                            _CostRow(
                              label: t.agent.chat.cost_cumulative_output,
                              value:
                                  '${chatState.totalOutputTokens} ${t.agent.chat.tokens_unit}',
                            ),
                            const Divider(height: 24),
                            // ── 当前上下文 ──
                            Text(
                              t.agent.chat.cost_context_title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CostRow(
                              label: t.agent.chat.cost_context_size,
                              value: chatState.lastInputTokens > 0
                                  ? '${chatState.lastInputTokens} ${t.agent.chat.tokens_unit}'
                                  : t.agent.chat.cost_no_data,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t.agent.chat.cost_disclaimer,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(t.common.confirm),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Text(
                      '\$${(chatState.totalCostMicros / 1000000).toStringAsFixed(4)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: chatState.messages.isEmpty && !chatState.isLoading
                ? _buildEmptyState(theme)
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true, // 核心改动：倒排列表
                        cacheExtent: 2000,
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        itemCount:
                            _buildDisplayItems(chatState).length +
                            (chatState.isLoading ? 1 : 0) +
                            (chatState.hasMore ? 1 : 0),
                        itemBuilder: (context, idx) {
                          int index = idx;
                          // 1. 如果正在加载（流式输出），最底部（index 0）放置流式气泡
                          if (chatState.isLoading) {
                            if (index == 0) {
                              return StreamingBubble(
                                key: const ValueKey('__streaming__'),
                                text: chatState.streamingText,
                                activeToolName: chatState.activeToolName,
                                completedTools: chatState.completedTools,
                              );
                            }
                            index--;
                          }

                          // 2. 正常渲染处理好的 UI 项（此时 displayItems 是随着 reverse ListView 呈倒序的）
                          final displayItems = _buildDisplayItems(chatState);
                          if (index < displayItems.length) {
                            final item = displayItems[index];
                            if (item is _ToolGroup) {
                              return ToolResultGroup(
                                key: ValueKey('tg_${item.messages.first.id}'),
                                messages: item.messages,
                              );
                            }
                            final message = item as ChatMessage;
                            if (message.role.name == 'system') {
                              return SizedBox.shrink(key: ValueKey(message.id));
                            }
                            if (message.role == MessageRole.assistant &&
                                (message.content == null ||
                                    message.content!.trim().isEmpty)) {
                              return SizedBox.shrink(key: ValueKey(message.id));
                            }
                            return ChatMessageBubble(
                              key: ValueKey(message.id),
                              message: message,
                              onEdit: message.role == MessageRole.user
                                  ? () => _showEditDialog(context, ref, message)
                                  : null,
                              onResend: message.role == MessageRole.user
                                  ? () => ref
                                        .read(agentChatProvider.notifier)
                                        .resendUserMessage(message.id)
                                  : null,
                              onRegenerate:
                                  message.role == MessageRole.assistant
                                  ? () => ref
                                        .read(agentChatProvider.notifier)
                                        .regenerateResponse(message.id)
                                  : null,
                            );
                          } else {
                            // 3. 达到最顶部（历史最前），触发并显示加载更多
                            if (!chatState.isLoadingMore) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(agentChatProvider.notifier).loadMore();
                              });
                            }
                            return Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      // 滚动到底部 FAB
                      if (!_isAtBottom && chatState.messages.isNotEmpty)
                        Positioned(
                          right: 16,
                          bottom: 12,
                          child: Material(
                            elevation: 4,
                            shape: const CircleBorder(),
                            color: theme.colorScheme.surfaceContainerHighest,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _scrollToBottom(animate: true),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 22,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          // 错误提示 + 重试按钮
          if (chatState.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _friendlyError(chatState.error!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: chatState.isLoading
                          ? null
                          : () {
                              final lastUserMsg = chatState.messages.lastWhere(
                                (m) => m.role == MessageRole.user,
                                orElse: () => ChatMessage.user(''),
                              );
                              if (lastUserMsg.id.isNotEmpty &&
                                  lastUserMsg.content?.isNotEmpty == true) {
                                ref
                                    .read(agentChatProvider.notifier)
                                    .resendUserMessage(lastUserMsg.id);
                              }
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(t.agent.chat.retry),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          ChatInputBar(
            isLoading: chatState.isLoading,
            assistantName: assistantName,
            onStop: () {
              ref.read(agentChatProvider.notifier).stopGeneration();
            },
            onAssistantTap: () async {
              final (didSelect, selected) = await AssistantPickerSheet.show(
                context,
                currentAssistantId: currentAssistantId,
              );
              if (!didSelect) return;
              final newId = selected?.id.toString();
              ref.read(agentChatProvider.notifier).setAssistant(newId);
              if (chatState.sessionId != null) {
                await ref
                    .read(sessionManagerProvider)
                    .updateSessionAssistant(chatState.sessionId!, newId);
              }
            },
            onSend: (text) async {
              // 发送消息时自动滚动到底部
              setState(() => _isAtBottom = true);
              String? guidelines;
              if (chatState.sessionId != null) {
                final session = await ref
                    .read(sessionManagerProvider)
                    .getSession(chatState.sessionId!);
                guidelines = session?.systemPrompt;
              }
              ref
                  .read(agentChatProvider.notifier)
                  .sendMessage(text: text, guidelines: guidelines);
              _scrollToBottom();
            },
          ),
        ],
      ),
    );
  }

  /// 编辑消息弹窗
  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ChatMessage message,
  ) async {
    final controller = TextEditingController(text: message.content ?? '');
    final theme = Theme.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.common.edit),
        content: TextField(
          controller: controller,
          maxLines: 6,
          autofocus: true,
          decoration: InputDecoration(
            hintText: t.agent.chat.input_hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    if (result != null &&
        result.trim().isNotEmpty &&
        result != message.content) {
      ref.read(agentChatProvider.notifier).editAndResend(message.id, result);
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 渐变背景圆形图标
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 38,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.agent.chat.start_chat,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.agent.chat.empty_hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 将原始错误信息转换为用户友好的提示
  String _friendlyError(String raw) {
    // 使用正则匹配 HTTP 状态码（避免误匹配端口号/时间戳等）
    final statusMatch = RegExp(
      r'(?:status\s*(?:code)?|HTTP)\s*:?\s*(\d{3})',
    ).firstMatch(raw);
    final statusCode = statusMatch != null
        ? int.tryParse(statusMatch.group(1)!)
        : null;

    String? friendly;
    if (statusCode != null) {
      if (statusCode == 400) friendly = t.agent.chat.err_format;
      if (statusCode == 401 || statusCode == 403)
        friendly = t.agent.chat.err_unauthorized;
      if (statusCode == 429) friendly = t.agent.chat.err_too_many_requests;
      if (statusCode >= 500 && statusCode <= 503)
        friendly = t.agent.chat.err_server;
    }
    if (raw.contains('timeout') || raw.contains('TimeoutException')) {
      friendly = t.agent.chat.err_timeout;
    }
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      friendly = t.agent.chat.err_network;
    }

    // 拼接友好提示 + 原始错误（方便排查）
    final truncated = raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;
    return friendly != null ? '$friendly\n$truncated' : truncated;
  }

  /// 将消息列表预处理为展示项
  ///
  /// 核心逻辑：把 「空内容 assistant(toolCalls) + tool 结果」 这种连续序列
  /// 合并为一个 _ToolGroup，这样多次工具调用不会拆分成多个独立卡片。
  ///
  /// 同时从 assistant 的 toolCalls 中提取工具名，回填到 tool 结果消息上
  /// （兼容旧数据）。
  List<Object> _buildDisplayItems(AgentChatState chatState) {
    if (chatState.messages.isEmpty) return [];

    final items = <Object>[];
    // chatState.messages 目前是按时间倒序的（最新在 0）。
    // 为了和原有的合并连续工具调用的顺时逻辑保持高度一致，我们先将其翻转为正序（先发生在前，即 index=0）。
    final messages = chatState.messages.reversed.toList();

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];

      // 检测到空内容 assistant（仅包含 toolCalls）或 tool 消息
      // → 开始收集一组工具调用
      if (_isToolRelated(msg)) {
        final toolGroup = <ChatMessage>[];

        while (i < messages.length && _isToolRelated(messages[i])) {
          final current = messages[i];

          if (current.role == MessageRole.assistant &&
              current.toolCalls != null &&
              current.toolCalls!.isNotEmpty) {
            // 这是一个空内容 assistant 消息，包含 toolCalls 信息
            // 向后查找对应的 tool 结果并回填工具名
            final callMap = {
              for (final call in current.toolCalls!) call.id: call.name,
            };

            // 向后扫描紧邻的 tool 消息
            i++;
            while (i < messages.length &&
                messages[i].role == MessageRole.tool) {
              final toolMsg = messages[i];
              // 如果 toolName 为空，从 callMap 中回填
              if (toolMsg.toolName == null || toolMsg.toolName!.isEmpty) {
                final resolvedName =
                    callMap[toolMsg.toolCallId] ?? toolMsg.toolName;
                // 创建带工具名的副本（避免修改原对象）
                toolGroup.add(
                  ChatMessage(
                    id: toolMsg.id,
                    role: toolMsg.role,
                    content: toolMsg.content,
                    toolCallId: toolMsg.toolCallId,
                    toolName: resolvedName,
                    timestamp: toolMsg.timestamp,
                  ),
                );
              } else {
                toolGroup.add(toolMsg);
              }
              i++;
            }
            // 不 i++，因为 while 已经移动了
          } else if (current.role == MessageRole.tool) {
            // 单独的 tool 消息（没有前置 assistant）
            toolGroup.add(current);
            i++;
          } else {
            break;
          }
        }

        if (toolGroup.isNotEmpty) {
          items.add(_ToolGroup(toolGroup));
        }
        // i 现在指向下一个非工具消息，但 for 的 i++ 还会执行，所以回退一步
        i--;
      } else {
        items.add(msg);
      }
    }

    // 最后，将合并好工具调用的 items 再次翻转回倒序，供 ListView(reverse: true) 使用
    return items.reversed.toList();
  }

  /// 判断消息是否属于工具调用序列的一部分
  bool _isToolRelated(ChatMessage msg) {
    if (msg.role == MessageRole.tool) return true;
    if (msg.role == MessageRole.assistant &&
        (msg.content == null || msg.content!.trim().isEmpty) &&
        msg.toolCalls != null &&
        msg.toolCalls!.isNotEmpty) {
      return true;
    }
    return false;
  }
}

/// 连续工具消息的分组标记
class _ToolGroup {
  final List<ChatMessage> messages;
  const _ToolGroup(this.messages);
}

/// 费用详情弹窗中的 label-value 行
class _CostRow extends StatelessWidget {
  final String label;
  final String value;
  const _CostRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'RobotoMono',
            ),
          ),
        ],
      ),
    );
  }
}
