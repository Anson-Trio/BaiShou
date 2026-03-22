/// Agent 聊天状态管理
///
/// 管理当前对话的消息列表、流式输出、工具执行状态

import 'dart:async';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/runner/agent_runner.dart';
import 'package:baishou/agent/session/compression_service.dart';
import 'package:baishou/agent/session/context_window.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_repository.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/agent/pricing/model_pricing_service.dart';
import 'package:baishou/agent/prompts/system_prompt_builder.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_chat_notifier.g.dart';

/// 工具执行记录
class ToolExecution {
  final String name;
  final int durationMs;
  const ToolExecution({required this.name, required this.durationMs});
}

/// 聊天页面 UI 状态
class AgentChatState {
  final String? sessionId;
  final List<ChatMessage> messages;
  final String streamingText;
  final bool isLoading;
  final String? activeToolName;
  final String? error;

  /// 当前轮已完成的工具执行记录（含耗时）
  final List<ToolExecution> completedTools;

  /// 当前会话累计费用（微美元，1 USD = 1,000,000 micros）
  final int totalCostMicros;

  /// 当前会话累计输入 token
  final int totalInputTokens;

  /// 当前会话累计输出 token
  final int totalOutputTokens;

  /// 最近一次 API 调用的上下文 token 数（即当前对话上下文大小）
  final int lastInputTokens;

  /// 当前选择的伙伴 ID（新对话创建时使用）
  final String? currentAssistantId;

  /// 是否还有更多历史消息可加载
  final bool hasMore;

  /// 是否正在加载更多历史记录
  final bool isLoadingMore;

  const AgentChatState({
    this.sessionId,
    this.messages = const [],
    this.streamingText = '',
    this.isLoading = false,
    this.activeToolName,
    this.error,
    this.completedTools = const [],
    this.totalCostMicros = 0,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.lastInputTokens = 0,
    this.currentAssistantId,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  AgentChatState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    String? streamingText,
    bool? isLoading,
    String? Function()? activeToolName,
    String? Function()? error,
    List<ToolExecution>? completedTools,
    int? totalCostMicros,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? lastInputTokens,
    String? Function()? currentAssistantId,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return AgentChatState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      streamingText: streamingText ?? this.streamingText,
      isLoading: isLoading ?? this.isLoading,
      activeToolName: activeToolName != null
          ? activeToolName()
          : this.activeToolName,
      error: error != null ? error() : this.error,
      completedTools: completedTools ?? this.completedTools,
      totalCostMicros: totalCostMicros ?? this.totalCostMicros,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      lastInputTokens: lastInputTokens ?? this.lastInputTokens,
      currentAssistantId: currentAssistantId != null
          ? currentAssistantId()
          : this.currentAssistantId,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class AgentChatNotifier extends _$AgentChatNotifier {
  /// 当前运行 ID（用于中止当前会话的生成）
  int _currentRunId = 0;

  /// 每个会话的状态缓存（支持切换后保持生成）
  final Map<String, AgentChatState> _sessionStateCache = {};

  @override
  AgentChatState build() {
    // 初始化时加载默认伙伴
    _initDefaultAssistant();
    return const AgentChatState();
  }

  /// 重发用户消息（基于现有对话中的 user 消息并清空其后的无效模型响应）
  Future<void> resendUserMessage(String userMessageId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.isLoading) return;

    final manager = ref.read(sessionManagerProvider);

    // 1. 获取关联的伙伴/工具消息并将其删除
    final msgsToDelete = state.messages
        .where((m) => m.askId == userMessageId)
        .map((m) => m.id)
        .toList();
    if (msgsToDelete.isNotEmpty) {
      await manager.deleteMessagesByIds(msgsToDelete);
      state = state.copyWith(
        messages: state.messages
            .where((m) => m.askId != userMessageId)
            .toList(),
      );
      _sessionStateCache[sessionId] = state;
    }

    // 获取最新的 API Config 和 Provider
    final apiConfig = ref.read(apiConfigServiceProvider);
    final providerId = apiConfig.globalDialogueProviderId;
    final modelId = apiConfig.globalDialogueModelId;
    final provider = apiConfig.getProvider(providerId);

    if (provider == null || modelId.isEmpty) {
      state = state.copyWith(error: () => t.agent.chat.err_no_model);
      return;
    }

    final vaultInfo = await ref.read(vaultServiceProvider.future);
    final vaultName = vaultInfo?.name ?? 'Personal';
    final storageService = ref.read(storagePathServiceProvider);
    final vaultDir = await storageService.getVaultDirectory(vaultName);

    _currentRunId++;
    final runId = _currentRunId;

    state = state.copyWith(error: () => null, isLoading: true);
    _sessionStateCache[sessionId] = state;

    final userMsg = state.messages.firstWhere(
      (m) => m.id == userMessageId,
      orElse: () => ChatMessage.user(''),
    );

    await _runAgentLoop(
      sessionId: sessionId,
      runId: runId,
      askId: userMessageId,
      vaultName: vaultName,
      vaultPath: vaultDir.path,
      providerId: providerId,
      modelId: modelId,
      provider: provider,
      isNewSession: false,
      userMessageContent: userMsg.content ?? '',
    );
  }

  /// 重新生成 AI 回复（查找到对应最初提问的用户消息并重发）
  Future<void> regenerateResponse(String assistantMessageId) async {
    final msg = state.messages.firstWhere(
      (m) => m.id == assistantMessageId,
      orElse: () => ChatMessage.assistant(),
    );
    if (msg.askId == null) return;
    await resendUserMessage(msg.askId!);
  }

  /// 加载已有会话
  ///
  /// 不中断正在进行的生成 — 当前会话的状态会保存到缓存中，
  /// 后台生成的结果会持续写入缓存。切换回来时从缓存恢复。
  Future<void> loadSession(String sessionId) async {
    // 保存当前会话状态到缓存
    if (state.sessionId != null && state.sessionId!.isNotEmpty) {
      _sessionStateCache[state.sessionId!] = state;
    }

    // 尝试从缓存恢复目标会话
    final cached = _sessionStateCache[sessionId];
    if (cached != null) {
      state = cached;
      return;
    }

    // 缓存中没有，从数据库加载最近 20 条（倒序，最新的在前面）
    final manager = ref.read(sessionManagerProvider);
    final messages = await manager.getMessages(
      sessionId,
      limit: 20,
      descending: true,
    );
    final session = await manager.getSession(sessionId);
    state = state.copyWith(
      sessionId: sessionId,
      messages: messages,
      isLoading: false,
      streamingText: '',
      activeToolName: () => null,
      error: () => null,
      completedTools: const [],
      totalCostMicros: session?.totalCostMicros ?? 0,
      totalInputTokens: session?.totalInputTokens ?? 0,
      totalOutputTokens: session?.totalOutputTokens ?? 0,
      currentAssistantId: () => session?.assistantId,
      hasMore: messages.length == 20,
      isLoadingMore: false,
    );
  }

  /// 加载更多历史记录（向上滑动时触发）
  Future<void> loadMore() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final manager = ref.read(sessionManagerProvider);
    final moreMessages = await manager.getMessages(
      sessionId,
      limit: 20,
      offset: state.messages.length,
      descending: true,
    );

    state = state.copyWith(
      messages: [...state.messages, ...moreMessages],
      hasMore: moreMessages.length == 20,
      isLoadingMore: false,
    );
  }

  /// 更新指定会话的缓存状态（后台生成使用）
  void _updateSessionCache(String sessionId, AgentChatState newState) {
    _sessionStateCache[sessionId] = newState;
    // 如果是当前显示的会话，同步更新 UI
    if (state.sessionId == sessionId) {
      state = newState;
    }
  }

  /// 获取指定会话的最新状态（优先缓存，回退到当前 state）
  AgentChatState _getSessionState(String sessionId) {
    return _sessionStateCache[sessionId] ?? state;
  }

  /// 设置当前伙伴（新对话创建时使用）
  void setAssistant(String? id) {
    state = state.copyWith(currentAssistantId: () => id);
  }

  /// 初始化默认伙伴
  Future<void> _initDefaultAssistant() async {
    try {
      final assistantRepo = ref.read(assistantRepositoryProvider);
      final defaultAssistant = await assistantRepo.getDefault();
      if (defaultAssistant != null) {
        state = state.copyWith(
          currentAssistantId: () => defaultAssistant.id.toString(),
        );
      }
    } catch (_) {}
  }

  /// 发送消息并运行 Agent
  Future<void> sendMessage({
    required String text,
    String? persona,
    String? guidelines,
  }) async {
    if (text.trim().isEmpty || state.isLoading) return;

    // 生成本次运行的唯一 ID（用于会话隔离检查）
    _currentRunId++;
    final runId = _currentRunId;

    // 清除错误状态
    state = state.copyWith(error: () => null, isLoading: true);

    final manager = ref.read(sessionManagerProvider);
    final apiConfig = ref.read(apiConfigServiceProvider);

    // 从 VaultService 获取当前活跃的 Vault 名称
    final vaultInfo = await ref.read(vaultServiceProvider.future);
    final vaultName = vaultInfo?.name ?? 'Personal';

    // 从 StoragePathService 解析 Vault 的物理路径（供工具读写文件系统）
    final storageService = ref.read(storagePathServiceProvider);
    final vaultDir = await storageService.getVaultDirectory(vaultName);
    final vaultPath = vaultDir.path;

    // 获取 AI 供应商配置
    // 暂时使用全局对话模型，后续可改为 Agent 专用模型
    final providerId = apiConfig.globalDialogueProviderId;
    final modelId = apiConfig.globalDialogueModelId;
    final provider = apiConfig.getProvider(providerId);

    if (provider == null || modelId.isEmpty) {
      state = state.copyWith(
        error: () => t.agent.chat.err_no_model,
        isLoading: false,
      );
      return;
    }

    // 创建新会话
    String sessionId = state.sessionId ?? '';
    bool isNewSession = false;

    if (sessionId.isEmpty) {
      isNewSession = true;
      sessionId = await manager.createSession(
        vaultName: vaultName,
        providerId: providerId,
        modelId: modelId,
        assistantId: state.currentAssistantId,
      );
      state = state.copyWith(sessionId: sessionId);
    }

    // 添加用户消息到 UI（插到头部，因为是倒排）
    final userMsg = ChatMessage.user(text);
    final updatedMessages = [userMsg, ...state.messages];
    state = state.copyWith(messages: updatedMessages);

    // ★ 同步到缓存：确保 event loop 中 _getSessionState 拿到最新 state
    _sessionStateCache[sessionId] = state;

    // 持久化用户消息
    await manager.addMessage(sessionId, userMsg);

    await _runAgentLoop(
      sessionId: sessionId,
      runId: runId,
      askId: userMsg.id,
      vaultName: vaultName,
      vaultPath: vaultPath,
      providerId: providerId,
      modelId: modelId,
      provider: provider,
      isNewSession: isNewSession,
      userMessageContent: userMsg.content ?? '',
      persona: persona,
      guidelines: guidelines,
    );
  }

  /// 抽取出的公共 Agent 运行循环
  Future<void> _runAgentLoop({
    required String sessionId,
    required int runId,
    required String askId,
    required String vaultName,
    required String vaultPath,
    required String providerId,
    required String modelId,
    required dynamic provider,
    required bool isNewSession,
    required String userMessageContent,
    String? persona,
    String? guidelines,
  }) async {
    final manager = ref.read(sessionManagerProvider);
    final apiConfig = ref.read(apiConfigServiceProvider);

    // 构建工具注册表
    final tools = _buildToolRegistry();

    // 构建 System Prompt
    // 有伙伴时：用伙伴的提示词（没设就是没有，不回退到全局设置）
    // 无伙伴时：走参数传入 → 全局设置 的原有逻辑
    String? resolvedPersona;
    int? assistantContextWindow;
    bool hasAssistant = false;

    final db = ref.read(agentDatabaseProvider);
    final assistantRepo = ref.read(assistantRepositoryProvider);
    final session = await (db.select(
      db.agentSessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (session?.assistantId != null) {
      final assistant = await assistantRepo.get(session!.assistantId!);
      if (assistant != null) {
        hasAssistant = true;
        // 伙伴的提示词：有就用，没有就是空（不回退）
        resolvedPersona = assistant.systemPrompt.isNotEmpty
            ? assistant.systemPrompt
            : null;
        assistantContextWindow = assistant.contextWindow;
      }
    }

    // 只有没关联伙伴时，才用参数传入或全局配置
    if (!hasAssistant) {
      resolvedPersona = persona ?? apiConfig.agentPersona;
    }

    final systemPrompt = SystemPromptBuilder.build(
      persona: resolvedPersona,
      guidelines: hasAssistant
          ? null
          : (guidelines ?? apiConfig.agentGuidelines),
      vaultName: vaultName,
      tools: tools,
    );

    // 创建 Agent Runner
    final client = AiClientFactory.createClient(provider);
    final runner = AgentRunner(
      client: client,
      tools: tools,
      config: AgentConfig(modelId: modelId, systemPrompt: systemPrompt),
    );

    // 运行 Agent Loop
    //  → 滑动窗口：只取最近 N 条消息作为上下文
    final windowSize =
        assistantContextWindow ?? apiConfig.agentContextWindowSize;

    // 因为 UI 的 messages 只包含分页加载的几十条，不能用来组装完整的上下文
    // 我们需要直接从数据库加载所需的数量
    // 从 DB 取 windowSize 条历史记录（按时间倒序），然后翻转为正序供 AI 使用
    final dbMessages = await manager.getMessages(
      sessionId,
      limit: windowSize,
      descending: true,
    );

    // 获取压缩快照（如有）
    final compressor = ref.read(compressionServiceProvider);
    final snapshot = await compressor.getLatestSnapshot(sessionId);
    String? compressionSummary;

    // 过滤并翻转为正序
    List<ChatMessage> messagesForWindow = dbMessages
        .where((m) => m.role != MessageRole.system)
        .toList()
        .reversed
        .toList();

    if (snapshot != null) {
      // 裁剪掉压缩点之前的消息
      final cutoffIndex = messagesForWindow.indexWhere(
        (m) => m.id == snapshot.coveredUpToMessageId,
      );
      if (cutoffIndex >= 0 && cutoffIndex < messagesForWindow.length - 1) {
        messagesForWindow = messagesForWindow.sublist(cutoffIndex + 1);
        compressionSummary = snapshot.summaryText;
      }
    }

    final contextMessages = ContextWindow.fromMemory(
      messages: messagesForWindow,
      config: ContextWindowConfig(recentCount: windowSize),
      compressionSummary: compressionSummary,
    );

    try {
      final assistantMessages = <ChatMessage>[];

      await for (final event in runner.run(
        messages: contextMessages,
        context: ToolContext(
          sessionId: sessionId,
          vaultPath: vaultPath,
          userConfig: {
            'rag_top_k': apiConfig.ragTopK,
            'rag_similarity_threshold': apiConfig.ragSimilarityThreshold,
          },
          embeddingService: EmbeddingService(
            ref.read(apiConfigServiceProvider),
            ref.read(agentDatabaseProvider),
          ),
        ),
        askId: askId,
      )) {
        // 中止检查：仅在 clearChat 时中止（不因切换会话中止）
        if (_currentRunId != runId) return;

        // 从缓存获取当前会话的最新状态
        final currentState = _getSessionState(sessionId);

        switch (event) {
          case AgentTextDelta(:final text):
            _updateSessionCache(
              sessionId,
              currentState.copyWith(
                streamingText: currentState.streamingText + text,
              ),
            );
            break;

          case AgentToolStart(:final toolCall):
            _updateSessionCache(
              sessionId,
              currentState.copyWith(activeToolName: () => toolCall.name),
            );
            break;

          case AgentToolComplete(:final toolCall, :final durationMs):
            _updateSessionCache(
              sessionId,
              currentState.copyWith(
                activeToolName: () => null,
                completedTools: [
                  ...currentState.completedTools,
                  ToolExecution(name: toolCall.name, durationMs: durationMs),
                ],
              ),
            );
            break;

          case AgentComplete(:final text, :final messages, :final usage):
            // runner 返回的 messages 仅包含本轮新增的 assistant/tool 消息（正序，最旧在 0）
            assistantMessages.addAll(messages);

            // 为最后一条 assistant 消息附加调用链和用法信息
            // 找到带文本内容的 assistant 消息（最终回复）
            final annotatedMessages = <ChatMessage>[];
            for (final msg in assistantMessages) {
              if (msg.role == MessageRole.assistant &&
                  msg.content != null &&
                  msg.content!.isNotEmpty) {
                annotatedMessages.add(
                  msg.withUsage(
                    inputTokens: usage?.inputTokens,
                    outputTokens: usage?.outputTokens,
                    contextMessages: List.unmodifiable(contextMessages),
                  ),
                );
              } else {
                annotatedMessages.add(msg);
              }
            }

            // 修复 Bug：持久化时使用携带完整信息（context、tokens）的 annotatedMessages
            if (annotatedMessages.isNotEmpty) {
              await manager.addMessages(
                sessionId,
                annotatedMessages,
                providerId: providerId,
                modelId: modelId,
              );
            }

            // 累加 token 用量
            final latestState = _getSessionState(sessionId);
            final newInputTokens =
                latestState.totalInputTokens + (usage?.inputTokens ?? 0);
            final newOutputTokens =
                latestState.totalOutputTokens + (usage?.outputTokens ?? 0);

            // 更新会话状态
            // annotatedMessages 是顺排的（旧在0）。我们需要倒排后插入 UI 的头部（UI 的 0 是最新的）
            _updateSessionCache(
              sessionId,
              latestState.copyWith(
                messages: [
                  ...annotatedMessages.reversed,
                  ...latestState.messages,
                ],
                streamingText: '',
                isLoading: false,
                activeToolName: () => null,
                completedTools: const [],
                totalInputTokens: newInputTokens,
                totalOutputTokens: newOutputTokens,
                lastInputTokens: usage?.inputTokens ?? latestState.lastInputTokens,
              ),
            );

            // 自动生成对话标题（仅新会话首次回复时触发，异步不阻塞）
            if (isNewSession && text.isNotEmpty) {
              _generateTitle(
                client: client,
                modelId: modelId,
                userMessage: userMessageContent,
                assistantReply: text,
                sessionId: sessionId,
                manager: manager,
              );
            }

            // 异步保存 token 用量和费用（不阻塞 UI）
            if (usage != null) {
              _saveUsageAndUpdateCost(
                providerId: providerId,
                modelId: modelId,
                usage: usage,
                sessionId: sessionId,
                manager: manager,
                annotatedMessages: annotatedMessages,
              );
            }

            // 异步检查是否需要压缩（不阻塞 UI）
            if (usage != null && session?.assistantId != null) {
              final assist = await assistantRepo.get(session!.assistantId!);
              final threshold = assist?.compressTokenThreshold ?? 0;
              if (threshold > 0) {
                final currentContextTokens = usage.inputTokens;
                final needs = compressor.shouldCompress(
                  currentContextTokens,
                  threshold,
                );
                if (needs) {
                  // 异步执行，fire-and-forget
                  () async {
                    try {
                      await compressor.compress(
                        sessionId,
                        threshold: threshold,
                      );
                    } catch (e) {
                      debugPrint('CompressionService: Error: $e');
                    }
                  }();
                }
              }
            }
            break;

          case AgentError(:final error):
            _updateSessionCache(
              sessionId,
              currentState.copyWith(
                error: () => error.toString(),
                isLoading: false,
                streamingText: '',
                activeToolName: () => null,
              ),
            );
            break;

          case AgentStepInfo():
            break;
        }
      }
    } catch (e) {
      debugPrint('AgentChatNotifier error: $e');
      final currentState = _getSessionState(sessionId);
      _updateSessionCache(
        sessionId,
        currentState.copyWith(
          error: () => e.toString(),
          isLoading: false,
          streamingText: '',
          activeToolName: () => null,
        ),
      );
    }
  }

  /// 构建工具注册表（委托给 ToolRepository）
  ToolRegistry _buildToolRegistry() {
    return ref.read(toolRepositoryProvider.notifier).buildRegistry();
  }

  /// 自动生成对话标题（异步，不阻塞 UI）
  Future<void> _generateTitle({
    required AiClient client,
    required String modelId,
    required String userMessage,
    required String assistantReply,
    required String sessionId,
    required SessionManager manager,
  }) async {
    try {
      // 截取前 200 字，避免 prompt 过长
      final userPreview = userMessage.length > 200
          ? userMessage.substring(0, 200)
          : userMessage;
      final replyPreview = assistantReply.length > 200
          ? assistantReply.substring(0, 200)
          : assistantReply;

      String title = '';
      await for (final event in client.chatStream(
        messages: [
          ChatMessage.system(
            '根据以下对话生成一个简短的标题（10个字以内，不要标点符号，不要引号）。'
            '只输出标题本身，不要任何解释。',
          ),
          ChatMessage.user('用户: $userPreview\n伙伴: $replyPreview'),
        ],
        modelId: modelId,
      )) {
        if (event is TextDelta) {
          title += event.text;
        }
      }

      title = title.trim();
      if (title.isNotEmpty && title.length <= 30) {
        await manager.updateSessionTitle(sessionId, title);
      }
    } catch (e) {
      debugPrint('Auto-generate title failed: $e');
      // 标题生成失败不影响主流程
    }
  }

  /// 异步保存 token 用量和费用，并更新 state 中的费用累计
  Future<void> _saveUsageAndUpdateCost({
    required String providerId,
    required String modelId,
    required TokenUsage usage,
    required String sessionId,
    required SessionManager manager,
    List<ChatMessage>? annotatedMessages,
  }) async {
    try {
      // 查询模型价格并计算费用
      final costUsd = await ModelPricingService.instance.calculateCost(
        providerId,
        modelId,
        usage,
      );

      // 将美元转换为 micros（× 1,000,000）
      final costMicros = costUsd != null ? (costUsd * 1000000).round() : 0;

      await manager.addUsage(
        sessionId: sessionId,
        inputTokens: usage.inputTokens,
        outputTokens: usage.outputTokens,
        costMicros: costMicros,
      );

      // 更新 state 中的费用累计
      final currentState = _getSessionState(sessionId);
      if (costMicros > 0) {
        // 回填 cost 到标注过的 assistant 消息
        if (costUsd != null && annotatedMessages != null) {
          final updatedMessages = currentState.messages.map((msg) {
            // 匹配带 inputTokens 的 assistant 消息（本轮标注过的）
            if (msg.inputTokens != null &&
                annotatedMessages.any((a) => a.id == msg.id)) {
              return msg.withUsage(cost: costUsd);
            }
            return msg;
          }).toList();

          // 持久化 costMicros 到数据库
          for (final a in annotatedMessages) {
            await manager.updateMessageCost(a.id, costMicros);
          }

          _updateSessionCache(
            sessionId,
            currentState.copyWith(
              totalCostMicros: currentState.totalCostMicros + costMicros,
              messages: updatedMessages,
            ),
          );
        } else {
          _updateSessionCache(
            sessionId,
            currentState.copyWith(
              totalCostMicros: currentState.totalCostMicros + costMicros,
            ),
          );
        }
      }

      debugPrint(
        'Usage saved: ${usage.inputTokens} in / ${usage.outputTokens} out'
        ' = \$${costUsd?.toStringAsFixed(6) ?? "unknown"}',
      );
    } catch (e) {
      debugPrint('Save usage failed: $e');
    }
  }

  /// 编辑用户消息并重新发送
  ///
  /// 截断到目标用户消息及之后的所有消息，然后将其作为最新输入重发。
  Future<void> editAndResend(String messageId, String newText) async {
    if (newText.trim().isEmpty) return;

    final sessionId = state.sessionId;
    if (sessionId == null || state.isLoading) return;

    final manager = ref.read(sessionManagerProvider);

    // 截断该消息及之后的所有消息（包含自身）
    await manager.deleteMessagesFromAndAfter(sessionId, messageId);

    final msgIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex != -1) {
      final truncated = state.messages.sublist(0, msgIndex);
      state = state.copyWith(messages: truncated, error: () => null);
      _sessionStateCache[sessionId] = state;
    }

    // 用新文本作为普通发送
    await sendMessage(text: newText);
  }

  /// 清空当前对话
  void clearChat() {
    _currentRunId++; // 中断当前生成
    if (state.sessionId != null) {
      _sessionStateCache.remove(state.sessionId);
    }
    state = const AgentChatState();
  }

  /// 设置当前伙伴 ID（用于新建对话时绑定）
  void setCurrentAssistantId(String assistantId) {
    state = state.copyWith(currentAssistantId: () => assistantId);
  }
}
