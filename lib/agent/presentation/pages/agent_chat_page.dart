/// Agent 聊天页面
///
/// 全屏覆盖路由，包含消息列表和输入框

import 'dart:io';

import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/widgets/assistant_picker_sheet.dart';
import 'package:baishou/agent/presentation/widgets/chat_input_bar.dart';
import 'package:baishou/agent/presentation/widgets/chat_message_bubble.dart';
import 'package:baishou/agent/presentation/widgets/model_switcher_popup.dart';
import 'package:baishou/agent/presentation/widgets/recall_bottom_sheet.dart';
import 'package:baishou/agent/presentation/widgets/streaming_bubble.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/agent/presentation/pages/widgets/agent_chat_app_bar.dart';
import 'package:baishou/agent/presentation/pages/widgets/agent_chat_empty_state.dart';
import 'package:baishou/agent/presentation/pages/widgets/agent_chat_error_panel.dart';
import 'package:baishou/agent/presentation/pages/helpers/agent_chat_message_grouper.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
        ref.read(agentChatProvider.notifier).loadSession(widget.sessionId!);
      } else {
        ref.read(agentChatProvider.notifier).clearChat();
      }
    });
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

    // 消息数量变化（如工具结果添加、AI 回复完成）时：仅在底部才自动滚动
    ref.listen(agentChatProvider, (prev, next) {
      // 新消息到达
      if (prev?.messages.length != next.messages.length) {
        if (_isAtBottom) {
          _scrollToBottom(animate: true);
        }
      }
      // 流式输出期间：用户在底部时确保粘底（reverse list 自然行为 +
      // 偶尔因极端 cacheExtent 导致的 offset 漂移补偿）
      if (_isAtBottom &&
          next.isLoading &&
          _scrollController.hasClients &&
          _scrollController.position.pixels > 1) {
        _scrollController.jumpTo(0);
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
    final bool isMobile =
        !(Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
        MediaQuery.of(context).size.width < 700;

    return ListenableBuilder(
      listenable: apiConfig,
      builder: (context, _) {
        // 优先显示会话级别的模型，其次伙伴绑定模型，最后全局模型
        final currentModel =
            chatState.currentModelId ??
            assistantData?.modelId ??
            apiConfig.globalDialogueModelId;

        return Scaffold(
          appBar: AgentChatAppBar(
            isMobile: isMobile,
            currentModel: currentModel,
            chatState: chatState,
            onMenuTap: isMobile
                ? () => Scaffold.of(context).openDrawer()
                : null,
            onTitleTap: () => _showModelSwitcher(context, ref, chatState),
          ),
          body: Column(
            children: [
              // 消息列表
              Expanded(
                child: chatState.messages.isEmpty && !chatState.isLoading
                    ? const AgentChatEmptyState()
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            reverse: true, // 核心改动：倒排列表
                            cacheExtent: 2500, // 适度缓存，避免缓存所有渲染节点导致对话过多时滑动卡顿
                            padding: const EdgeInsets.only(top: 20, bottom: 20),
                            itemCount:
                                AgentChatMessageGrouper.buildDisplayItems(
                                  chatState,
                                ).length +
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
                              final displayItems =
                                  AgentChatMessageGrouper.buildDisplayItems(
                                    chatState,
                                  );
                              if (index < displayItems.length) {
                                final item = displayItems[index];
                                if (item is ToolGroup) {
                                  return ToolResultGroup(
                                    key: ValueKey(
                                      'tg_${item.messages.first.id}',
                                    ),
                                    messages: item.messages,
                                  );
                                }
                                final message = item as ChatMessage;
                                if (message.role.name == 'system') {
                                  return SizedBox.shrink(
                                    key: ValueKey(message.id),
                                  );
                                }
                                if (message.role == MessageRole.assistant &&
                                    (message.content == null ||
                                        message.content!.trim().isEmpty)) {
                                  return SizedBox.shrink(
                                    key: ValueKey(message.id),
                                  );
                                }
                                return ChatMessageBubble(
                                  key: ValueKey(message.id),
                                  message: message,
                                  onEdit: message.role == MessageRole.user
                                      ? () => _showEditDialog(
                                          context,
                                          ref,
                                          message,
                                        )
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
                                // 3. 达到最顶部（历史最前），显示加载指示器或加载按钮
                                if (chatState.isLoadingMore) {
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
                                } else {
                                  return Container(
                                    padding: const EdgeInsets.all(20),
                                    alignment: Alignment.center,
                                    child: TextButton.icon(
                                      onPressed: () => ref
                                          .read(agentChatProvider.notifier)
                                          .loadMore(),
                                      icon: const Icon(Icons.history, size: 18),
                                      label: Text(t.common.confirm == 'Confirm' ? 'Load earlier history' : '加载更早的历史记录'),
                                    ),
                                  );
                                }
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
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
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
                AgentChatErrorPanel(
                  error: chatState.error!,
                  isLoading: chatState.isLoading,
                  onRetry: () {
                    final firstUserMsg = chatState.messages.firstWhere(
                      (m) => m.role == MessageRole.user,
                      orElse: () => ChatMessage.user(''),
                    );
                    if (firstUserMsg.id.isNotEmpty &&
                        firstUserMsg.content?.isNotEmpty == true) {
                      ref
                          .read(agentChatProvider.notifier)
                          .resendUserMessage(firstUserMsg.id);
                    }
                  },
                ),

              ChatInputBar(
                isLoading: chatState.isLoading,
                assistantName: assistantName,
                onStop: () {
                  ref.read(agentChatProvider.notifier).stopGeneration();
                },
                onRecall: () {
                  RecallBottomSheet.show(
                    context,
                    ref,
                    onConfirm: (contextText, months) {
                      // 将回忆作为用户消息发送给 AI
                      ref
                          .read(agentChatProvider.notifier)
                          .sendMessage(text: contextText);
                      AppToast.showSuccess(
                        context,
                        t.settings.recall_injected(months: months.toString()),
                      );
                      setState(() => _isAtBottom = true);
                      _scrollToBottom();
                    },
                  );
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
                onSend: (text, {attachments}) async {
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
                      .sendMessage(
                        text: text,
                        guidelines: guidelines,
                        attachments: attachments,
                      );
                  _scrollToBottom();
                },
              ),
            ],
          ),
        );
      },
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

  /// 模型快速切换器 — 点击标题栏弹出，直接切换当前会话使用的模型
  void _showModelSwitcher(
    BuildContext context,
    WidgetRef ref,
    AgentChatState chatState,
  ) async {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final providers = apiConfig
        .getProviders()
        .where((p) => p.isEnabled)
        .toList();
    final currentProviderId =
        chatState.currentProviderId ?? apiConfig.globalDialogueProviderId;
    final currentModelId =
        chatState.currentModelId ?? apiConfig.globalDialogueModelId;

    final result = await showModelSwitcherPopup(
      context: context,
      providers: providers,
      currentProviderId: currentProviderId,
      currentModelId: currentModelId,
    );

    if (result != null) {
      final (providerId, modelId) = result;
      ref
          .read(agentChatProvider.notifier)
          .setCurrentModel(providerId: providerId, modelId: modelId);
      if (chatState.sessionId != null) {
        await ref
            .read(sessionManagerProvider)
            .updateSessionModel(chatState.sessionId!, providerId, modelId);
      }
    }
  }
}
