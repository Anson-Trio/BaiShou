/// Agent 聊天状态管理
///
/// 管理当前对话的消息列表、流式输出、工具执行状态
///
/// SOLID 拆分：
/// - State 模型 → agent_chat_state.dart
/// - 模型解析 → model_resolver.dart
/// - 副作用服务 → chat_side_effects.dart

import 'dart:async';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/message_attachment.dart';
import 'package:baishou/agent/runner/agent_runner.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_repository.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_state.dart';
import 'package:baishou/agent/presentation/notifiers/model_resolver.dart';
import 'package:baishou/agent/presentation/notifiers/chat_side_effects.dart';
import 'package:baishou/agent/presentation/notifiers/helpers/agent_context_builder.dart';
import 'package:baishou/agent/presentation/notifiers/helpers/agent_stream_handler.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:baishou/features/diary/data/vault_index_notifier.dart';
import 'package:baishou/features/index/data/shadow_index_sync_service.dart';
import 'package:baishou/agent/rag/memory_deduplication_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// 向后兼容：重新导出 AgentChatState 和 ToolExecution
export 'package:baishou/agent/presentation/notifiers/agent_chat_state.dart';

part 'agent_chat_notifier.g.dart';

@Riverpod(keepAlive: true)
class AgentChatNotifier extends _$AgentChatNotifier {
  /// 当前运行 ID（用于中止当前会话的生成）
  int _currentRunId = 0;

  /// 每个会话的状态缓存（支持切换后保持生成）
  final Map<String, AgentChatState> _sessionStateCache = {};

  @override
  AgentChatState build() {
    _initDefaultAssistant();
    return const AgentChatState();
  }

  // ========================================================================
  // 会话管理
  // ========================================================================

  /// 加载已有会话
  Future<void> loadSession(String sessionId) async {
    if (state.sessionId != null && state.sessionId!.isNotEmpty) {
      _sessionStateCache[state.sessionId!] = state;
    }

    final cached = _sessionStateCache[sessionId];
    if (cached != null) {
      if (cached.isLoading) {
        state = cached;
        return;
      }
      _sessionStateCache.remove(sessionId);
    }

    final manager = ref.read(sessionManagerProvider);
    final messages = await manager.getMessages(
      sessionId,
      limit: 10,
      descending: true,
    );
    final session = await manager.getSession(sessionId);
    final lastInput = await manager.getLastInputTokens(sessionId);
    state = state.copyWith(
      sessionId: () => sessionId,
      messages: messages,
      isLoading: false,
      streamingText: '',
      activeToolName: () => null,
      error: () => null,
      completedTools: const [],
      totalCostMicros: session?.totalCostMicros ?? 0,
      totalInputTokens: session?.totalInputTokens ?? 0,
      totalOutputTokens: session?.totalOutputTokens ?? 0,
      lastInputTokens: lastInput,
      currentAssistantId: () => session?.assistantId,
      currentProviderId: () => session?.providerId,
      currentModelId: () => session?.modelId,
      hasMore: messages.length == 10,
      isLoadingMore: false,
    );
  }

  /// 加载更多历史记录
  Future<void> loadMore() async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final manager = ref.read(sessionManagerProvider);
    final moreMessages = await manager.getMessages(
      sessionId,
      limit: 10,
      offset: state.messages.length,
      descending: true,
    );

    state = state.copyWith(
      messages: [...state.messages, ...moreMessages],
      hasMore: moreMessages.length == 10,
      isLoadingMore: false,
    );
  }

  /// 清空当前对话
  void clearChat([String? targetAssistantId]) {
    _currentRunId++;
    if (state.sessionId != null) {
      _sessionStateCache.remove(state.sessionId);
    }
    state = AgentChatState(
      currentAssistantId: targetAssistantId ?? state.currentAssistantId,
    );
  }

  /// 停止当前正在进行的生成
  void stopGeneration() {
    if (!state.isLoading) return;
    _currentRunId++;
    final sessionId = state.sessionId;
    if (sessionId != null) {
      final currentState = _getSessionState(sessionId);
      _updateSessionCache(
        sessionId,
        currentState.copyWith(
          isLoading: false,
          streamingText: '',
          activeToolName: () => null,
          completedTools: const [],
        ),
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        streamingText: '',
        activeToolName: () => null,
        completedTools: const [],
      );
    }
  }

  // ========================================================================
  // 伙伴 & 模型设置
  // ========================================================================

  void setAssistant(String? id) {
    state = state.copyWith(currentAssistantId: () => id);
  }

  void setCurrentAssistantId(String id) => setAssistant(id);

  void setCurrentModel({required String providerId, required String modelId}) {
    state = state.copyWith(
      currentProviderId: () => providerId,
      currentModelId: () => modelId,
    );
  }

  // ========================================================================
  // 消息发送
  // ========================================================================

  /// 发送消息并运行 Agent
  Future<void> sendMessage({
    required String text,
    String? persona,
    String? guidelines,
    List<MessageAttachment>? attachments,
  }) async {
    if (text.trim().isEmpty && (attachments == null || attachments.isEmpty))
      return;
    if (state.isLoading) return;

    _currentRunId++;
    final runId = _currentRunId;
    state = state.copyWith(error: () => null, isLoading: true);

    final manager = ref.read(sessionManagerProvider);
    final apiConfig = ref.read(apiConfigServiceProvider);

    final vaultInfo = await ref.read(vaultServiceProvider.future);
    final vaultName = vaultInfo?.name ?? 'Personal';
    final storageService = ref.read(storagePathServiceProvider);
    final vaultDir = await storageService.getVaultDirectory(vaultName);
    final vaultPath = vaultDir.path;

    // 模型解析（使用 ModelResolver 消除重复）
    final resolved = await ModelResolver.resolve(
      apiConfig: apiConfig,
      assistantRepo: ref.read(assistantRepositoryProvider),
      assistantId: state.currentAssistantId,
      sessionProviderId: state.currentProviderId,
      sessionModelId: state.currentModelId,
    );

    final provider = apiConfig.getProvider(resolved.providerId);
    if (provider == null || resolved.modelId.isEmpty) {
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
        providerId: resolved.providerId,
        modelId: resolved.modelId,
        assistantId: state.currentAssistantId,
      );
      state = state.copyWith(sessionId: () => sessionId);
    }

    // 复制附件到私有目录
    List<MessageAttachment>? persistedAttachments;
    if (attachments != null && attachments.isNotEmpty) {
      persistedAttachments = await AttachmentService.copyToPrivate(
        attachments: attachments,
        vaultPath: vaultPath,
        sessionId: sessionId,
      );
    }

    // 添加用户消息到 UI
    final userMsg = ChatMessage.user(text, attachments: persistedAttachments);
    List<ChatMessage> updatedMessages = [userMsg, ...state.messages];
    
    // 滑动窗口截断：按完整的对话轮次（User 消息）进行截断，保证 5 轮会话
    // 并且绝不会切断中间的 Tool / RAG 链条导致数据丢失
    bool hasMore = state.hasMore;
    int userMsgCount = 0;
    int cutoffIndex = -1;
    for (int i = 0; i < updatedMessages.length; i++) {
      if (updatedMessages[i].role == MessageRole.user) {
        userMsgCount++;
      }
      if (userMsgCount == 5) {
        // 当数到第 5 个 User 消息时，它就是第 5 轮的最早起点。
        // 其后的所有消息（i+1）都是更早一轮的 AI 回复，应被直接舍弃。
        cutoffIndex = i + 1;
        break;
      }
    }
    
    if (cutoffIndex != -1 && cutoffIndex < updatedMessages.length) {
      updatedMessages = updatedMessages.sublist(0, cutoffIndex);
      hasMore = true;
    }

    state = state.copyWith(messages: updatedMessages, hasMore: hasMore);
    _sessionStateCache[sessionId] = state;

    await manager.addMessage(sessionId, userMsg);

    await _runAgentLoop(
      sessionId: sessionId,
      runId: runId,
      askId: userMsg.id,
      vaultName: vaultName,
      vaultPath: vaultPath,
      providerId: resolved.providerId,
      modelId: resolved.modelId,
      provider: provider,
      isNewSession: isNewSession,
      userMessageContent: userMsg.content ?? '',
      persona: persona,
      guidelines: guidelines,
    );
  }

  /// 重发用户消息
  Future<void> resendUserMessage(String userMessageId) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.isLoading) return;

    final manager = ref.read(sessionManagerProvider);
    final apiConfig = ref.read(apiConfigServiceProvider);

    // 删除该用户消息之后的所有消息
    final userMsgIndex = state.messages.indexWhere(
      (m) => m.id == userMessageId,
    );
    if (userMsgIndex == -1) return;

    final msgsAfter = state.messages.sublist(0, userMsgIndex);
    if (msgsAfter.isNotEmpty) {
      final idsToDelete = msgsAfter.map((m) => m.id).toList();
      await manager.deleteMessagesByIds(idsToDelete);
      state = state.copyWith(messages: state.messages.sublist(userMsgIndex));
      _sessionStateCache[sessionId] = state;
    }

    // 模型解析
    final resolved = await ModelResolver.resolve(
      apiConfig: apiConfig,
      assistantRepo: ref.read(assistantRepositoryProvider),
      assistantId: state.currentAssistantId,
      sessionProviderId: state.currentProviderId,
      sessionModelId: state.currentModelId,
    );

    final provider = apiConfig.getProvider(resolved.providerId);
    if (provider == null || resolved.modelId.isEmpty) {
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
      providerId: resolved.providerId,
      modelId: resolved.modelId,
      provider: provider,
      isNewSession: false,
      userMessageContent: userMsg.content ?? '',
    );
  }

  /// 重新生成 AI 回复
  Future<void> regenerateResponse(String assistantMessageId) async {
    final msg = state.messages.firstWhere(
      (m) => m.id == assistantMessageId,
      orElse: () => ChatMessage.assistant(),
    );
    if (msg.askId == null) return;
    await resendUserMessage(msg.askId!);
  }

  /// 编辑用户消息并重新发送
  Future<void> editAndResend(String messageId, String newText) async {
    if (newText.trim().isEmpty) return;
    final sessionId = state.sessionId;
    if (sessionId == null || state.isLoading) return;

    final manager = ref.read(sessionManagerProvider);
    await manager.deleteMessagesFromAndAfter(sessionId, messageId);

    final msgIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex != -1) {
      final truncated = state.messages.sublist(0, msgIndex);
      state = state.copyWith(messages: truncated, error: () => null);
      _sessionStateCache[sessionId] = state;
    }

    await sendMessage(text: newText);
  }

  // ========================================================================
  // Agent 运行循环
  // ========================================================================

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
    try {
      // 1. 组装环境与上下文
      final prep = await AgentContextBuilder.build(
        ref: ref,
        sessionId: sessionId,
        vaultName: vaultName,
        persona: persona,
        guidelines: guidelines,
      );

      // 2. 创建 Runner
      final client = AiClientFactory.createClient(provider);
      final runner = AgentRunner(
        client: client,
        tools: prep.tools,
        config: AgentConfig(
          modelId: modelId,
          systemPrompt: prep.systemPrompt,
        ),
      );

      // 3. 构建 ToolContext 并生成流
      final stream = runner.run(
        messages: prep.contextMessages,
        context: ToolContext(
          sessionId: sessionId,
          vaultPath: vaultPath,
          userConfig: prep.toolUserConfig,
          embeddingService: EmbeddingService(
            ref.read(apiConfigServiceProvider),
            ref.read(agentDatabaseProvider),
          ),
          deduplicationService: MemoryDeduplicationService(
            ref.read(embeddingServiceProvider),
            ref.read(agentDatabaseProvider),
            ref.read(apiConfigServiceProvider),
          ),
        ),
        askId: askId,
      );

      // 4. 重定向流到处理程序
      await AgentStreamHandler.handleStream(
        ref: ref,
        stream: stream,
        sessionId: sessionId,
        runId: runId,
        getCurrentRunId: () => _currentRunId,
        getSessionState: _getSessionState,
        updateSessionState: _updateSessionCache,
        providerId: providerId,
        modelId: modelId,
        isNewSession: isNewSession,
        userMessageContent: userMessageContent,
        contextMessages: prep.contextMessages,
        client: client,
        onDiaryWriteSuccess: _refreshDiaryIndexAfterWrite,
      );
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

  /// 日记写入后刷新索引（异步，不阻塞 Agent 循环）
  void _refreshDiaryIndexAfterWrite(Map<String, dynamic> arguments) {
    () async {
      try {
        final rawDate = arguments['date'] as String?;
        final now = DateTime.now();
        final dateStr = (rawDate != null && rawDate.isNotEmpty)
            ? rawDate
            : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final date = DateTime.parse(dateStr);

        final syncService = ref.read(shadowIndexSyncServiceProvider.notifier);
        final result = await syncService.syncJournal(date);

        if (result.isChanged && result.meta != null) {
          ref.read(vaultIndexProvider.notifier).upsert(result.meta!);
          debugPrint('AgentChatNotifier: Diary index refreshed for $dateStr');
          // RAG 向量嵌入已由 ShadowIndexSyncService 文件监听自动触发，此处无需手动调用
        }
      } catch (e) {
        debugPrint('AgentChatNotifier: Failed to refresh diary index: $e');
      }
    }();
  }

  // ========================================================================
  // 内部工具方法
  // ========================================================================

  void _updateSessionCache(String sessionId, AgentChatState newState) {
    _sessionStateCache[sessionId] = newState;
    if (state.sessionId == sessionId) {
      state = newState;
    }
  }

  AgentChatState _getSessionState(String sessionId) {
    return _sessionStateCache[sessionId] ?? state;
  }

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

  /// 清理会话附件目录
  static Future<void> cleanupSessionAttachments({
    required String vaultPath,
    required String sessionId,
  }) => AttachmentService.cleanupSessionAttachments(
    vaultPath: vaultPath,
    sessionId: sessionId,
  );
}
