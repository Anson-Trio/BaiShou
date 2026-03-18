/// Agent 聊天状态管理
///
/// 管理当前对话的消息列表、流式输出、工具执行状态

import 'dart:async';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/runner/agent_runner.dart';
import 'package:baishou/agent/session/context_window.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_repository.dart';
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

  const AgentChatState({
    this.sessionId,
    this.messages = const [],
    this.streamingText = '',
    this.isLoading = false,
    this.activeToolName,
    this.error,
    this.completedTools = const [],
  });

  AgentChatState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    String? streamingText,
    bool? isLoading,
    String? Function()? activeToolName,
    String? Function()? error,
    List<ToolExecution>? completedTools,
  }) {
    return AgentChatState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      streamingText: streamingText ?? this.streamingText,
      isLoading: isLoading ?? this.isLoading,
      activeToolName:
          activeToolName != null ? activeToolName() : this.activeToolName,
      error: error != null ? error() : this.error,
      completedTools: completedTools ?? this.completedTools,
    );
  }
}

@riverpod
class AgentChatNotifier extends _$AgentChatNotifier {
  /// 最近一次发送的用户文本（用于重试）
  String? _lastSendText;

  @override
  AgentChatState build() {
    return const AgentChatState();
  }

  /// 重试最后一次发送
  Future<void> retryLast() async {
    if (_lastSendText == null || _lastSendText!.isEmpty) return;
    // 移除失败产生的最后一条 assistant 消息（如果有）
    final msgs = List<ChatMessage>.from(state.messages);
    while (msgs.isNotEmpty && msgs.last.role != MessageRole.user) {
      msgs.removeLast();
    }
    state = state.copyWith(
      messages: msgs,
      error: () => null,
    );
    await sendMessage(
      text: _lastSendText!,
    );
  }

  /// 加载已有会话
  Future<void> loadSession(String sessionId) async {
    final manager = ref.read(sessionManagerProvider);
    final messages = await manager.getMessages(sessionId);
    state = state.copyWith(
      sessionId: sessionId,
      messages: messages,
    );
  }

  /// 发送消息并运行 Agent
  Future<void> sendMessage({
    required String text,
    String? persona,
    String? guidelines,
  }) async {
    if (text.trim().isEmpty || state.isLoading) return;

    // 缓存发送文本用于重试
    _lastSendText = text.trim();

    // 清除错误状态
    state = state.copyWith(
      error: () => null,
      isLoading: true,
    );

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
        error: () => '请先在设置中配置 AI 模型',
        isLoading: false,
      );
      return;
    }

    // 创建或复用会话
    // 伴侣模式：固定单一会话，无"新建对话"概念
    // 会话模式：每次可新建独立会话
    final isCompanionMode = apiConfig.agentCompanionMode;
    String sessionId = state.sessionId ?? '';
    bool isNewSession = false;

    if (sessionId.isEmpty) {
      if (isCompanionMode) {
        // 伴侣模式：查找或创建固定的伴侣会话
        final sessions = await manager.getSessions();
        final companion = sessions.where(
          (s) => s.id == SessionManager.companionSessionId,
        );
        if (companion.isNotEmpty) {
          sessionId = companion.first.id;
          // 加载历史消息到 UI
          final history = await manager.getMessages(sessionId);
          state = state.copyWith(
            sessionId: sessionId,
            messages: history,
          );
        } else {
          isNewSession = true;
          // 用固定 ID 创建伴侣会话
          await manager.createCompanionSession(
            vaultName: vaultName,
            providerId: providerId,
            modelId: modelId,
          );
          sessionId = SessionManager.companionSessionId;
          state = state.copyWith(sessionId: sessionId);
        }
      } else {
        // 会话模式：正常新建
        isNewSession = true;
        sessionId = await manager.createSession(
          vaultName: vaultName,
          providerId: providerId,
          modelId: modelId,
        );
        state = state.copyWith(sessionId: sessionId);
      }
    }

    // 添加用户消息到 UI
    final userMsg = ChatMessage.user(text);
    final updatedMessages = [...state.messages, userMsg];
    state = state.copyWith(messages: updatedMessages);

    // 持久化用户消息
    await manager.addMessage(sessionId, userMsg);

    // 构建工具注册表
    final tools = _buildToolRegistry();

    // 构建 System Prompt（优先用参数传入，否则从设置读取）
    final systemPrompt = SystemPromptBuilder.build(
      persona: persona ?? apiConfig.agentPersona,
      guidelines: guidelines ?? apiConfig.agentGuidelines,
      vaultName: vaultName,
      tools: tools,
    );

    // 创建 Agent Runner
    final client = AiClientFactory.createClient(provider);
    final runner = AgentRunner(
      client: client,
      tools: tools,
      config: AgentConfig(
        modelId: modelId,
        systemPrompt: systemPrompt,
      ),
    );

    // 运行 Agent Loop
    //  → 滑动窗口：只取最近 N 条消息作为上下文
    final windowSize = apiConfig.agentContextWindowSize;
    final contextMessages = ContextWindow.fromMemory(
      messages: state.messages
          .where((m) => m.role != MessageRole.system)
          .toList(),
      config: ContextWindowConfig(recentCount: windowSize),
    );

    try {
      final assistantMessages = <ChatMessage>[];

      await for (final event in runner.run(
        messages: contextMessages,
        context: ToolContext(sessionId: sessionId, vaultPath: vaultPath),
      )) {
        switch (event) {
          case AgentTextDelta(:final text):
            state = state.copyWith(
              streamingText: state.streamingText + text,
            );
            break;

          case AgentToolStart(:final toolCall):
            state = state.copyWith(
              activeToolName: () => toolCall.name,
            );
            break;

          case AgentToolComplete(:final toolCall, :final durationMs):
            state = state.copyWith(
              activeToolName: () => null,
              completedTools: [
                ...state.completedTools,
                ToolExecution(
                  name: toolCall.name,
                  durationMs: durationMs,
                ),
              ],
            );
            break;

          case AgentComplete(:final text, :final messages, :final usage):
            // runner 返回的 messages 仅包含本轮新增的 assistant/tool 消息
            assistantMessages.addAll(messages);

            // 持久化 assistant/tool 消息
            if (assistantMessages.isNotEmpty) {
              await manager.addMessages(
                sessionId,
                assistantMessages,
                providerId: providerId,
                modelId: modelId,
              );
            }

            // 更新 UI 状态
            state = state.copyWith(
              messages: [...state.messages, ...assistantMessages],
              streamingText: '',
              isLoading: false,
              activeToolName: () => null,
              completedTools: const [],
            );

            // 自动生成对话标题（仅新会话首次回复时触发，异步不阻塞）
            if (isNewSession && text.isNotEmpty) {
              _generateTitle(
                client: client,
                modelId: modelId,
                userMessage: userMsg.content ?? '',
                assistantReply: text,
                sessionId: sessionId,
                manager: manager,
              );
            }

            // 异步保存 token 用量和费用（不阻塞 UI）
            if (usage != null) {
              _saveUsage(
                providerId: providerId,
                modelId: modelId,
                usage: usage,
                sessionId: sessionId,
                manager: manager,
              );
            }
            break;

          case AgentError(:final error):
            state = state.copyWith(
              error: () => error.toString(),
              isLoading: false,
              streamingText: '',
              activeToolName: () => null,
            );
            break;

          case AgentStepInfo():
            break;
        }
      }
    } catch (e) {
      debugPrint('AgentChatNotifier error: $e');
      state = state.copyWith(
        error: () => e.toString(),
        isLoading: false,
        streamingText: '',
        activeToolName: () => null,
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
          ChatMessage.user('用户: $userPreview\n助手: $replyPreview'),
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

  /// 异步保存 token 用量和费用
  Future<void> _saveUsage({
    required String providerId,
    required String modelId,
    required TokenUsage usage,
    required String sessionId,
    required SessionManager manager,
  }) async {
    try {
      // 查询模型价格并计算费用
      final costUsd = await ModelPricingService.instance
          .calculateCost(providerId, modelId, usage);

      // 将美元转换为 micros（× 1,000,000）
      final costMicros =
          costUsd != null ? (costUsd * 1000000).round() : 0;

      await manager.addUsage(
        sessionId: sessionId,
        inputTokens: usage.inputTokens,
        outputTokens: usage.outputTokens,
        costMicros: costMicros,
      );

      debugPrint(
        'Usage saved: ${usage.inputTokens} in / ${usage.outputTokens} out'
        ' = \$${costUsd?.toStringAsFixed(6) ?? "unknown"}',
      );
    } catch (e) {
      debugPrint('Save usage failed: $e');
    }
  }

  /// 清空当前对话
  void clearChat() {
    state = const AgentChatState();
  }
}
