/// Agent 聊天状态管理
///
/// 管理当前对话的消息列表、流式输出、工具执行状态

import 'dart:async';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/runner/agent_runner.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/diary/diary_list_tool.dart';
import 'package:baishou/agent/tools/diary/diary_read_tool.dart';
import 'package:baishou/agent/tools/diary/diary_search_tool.dart';
import 'package:baishou/agent/tools/summary/summary_read_tool.dart';
import 'package:baishou/agent/pricing/model_pricing_service.dart';
import 'package:baishou/agent/prompts/system_prompt_builder.dart';
import 'package:baishou/core/database/app_database.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_chat_notifier.g.dart';

/// 聊天页面 UI 状态
class AgentChatState {
  final String? sessionId;
  final List<ChatMessage> messages;
  final String streamingText;
  final bool isLoading;
  final String? activeToolName;
  final String? error;

  const AgentChatState({
    this.sessionId,
    this.messages = const [],
    this.streamingText = '',
    this.isLoading = false,
    this.activeToolName,
    this.error,
  });

  AgentChatState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    String? streamingText,
    bool? isLoading,
    String? Function()? activeToolName,
    String? Function()? error,
  }) {
    return AgentChatState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      streamingText: streamingText ?? this.streamingText,
      isLoading: isLoading ?? this.isLoading,
      activeToolName:
          activeToolName != null ? activeToolName() : this.activeToolName,
      error: error != null ? error() : this.error,
    );
  }
}

@riverpod
class AgentChatNotifier extends _$AgentChatNotifier {
  @override
  AgentChatState build() {
    return const AgentChatState();
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
    required String vaultName,
    required String vaultPath,
    String? persona,
    String? guidelines,
  }) async {
    if (text.trim().isEmpty || state.isLoading) return;

    // 清除错误状态
    state = state.copyWith(
      error: () => null,
      isLoading: true,
    );

    final manager = ref.read(sessionManagerProvider);
    final apiConfig = ref.read(apiConfigServiceProvider);

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
    String sessionId = state.sessionId ?? '';
    bool isNewSession = false;
    if (sessionId.isEmpty) {
      isNewSession = true;
      sessionId = await manager.createSession(
        vaultName: vaultName,
        providerId: providerId,
        modelId: modelId,
      );
      state = state.copyWith(sessionId: sessionId);
    }

    // 添加用户消息到 UI
    final userMsg = ChatMessage.user(text);
    final updatedMessages = [...state.messages, userMsg];
    state = state.copyWith(messages: updatedMessages);

    // 持久化用户消息
    await manager.addMessage(sessionId, userMsg);

    // 构建工具注册表
    final tools = _buildToolRegistry();

    // 构建 System Prompt
    final systemPrompt = SystemPromptBuilder.build(
      persona: persona ?? '你是白守的 AI 助手，帮助用户回顾日记和生活记录。',
      guidelines: guidelines ?? '请使用工具查阅日记内容，不要编造。引用时注明日期。',
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
    try {
      final assistantMessages = <ChatMessage>[];

      await for (final event in runner.run(
        messages: state.messages.where((m) => m.role != MessageRole.system).toList(),
        userMessage: text,
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

          case AgentToolComplete(toolCall: _, result: _):
            state = state.copyWith(
              activeToolName: () => null,
            );
            break;

          case AgentComplete(:final text, :final messages, :final usage):
            // 提取出新增的消息（跳过我们已有的 user message）
            // messages 包含了整个历史（含 runner 内添加的 user msg）
            // 我们只需要 assistant 和 tool 类型的新消息
            for (final msg in messages) {
              if (msg.role == MessageRole.assistant ||
                  msg.role == MessageRole.tool) {
                assistantMessages.add(msg);
              }
            }

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

  /// 构建工具注册表
  ToolRegistry _buildToolRegistry() {
    final registry = ToolRegistry();

    // Phase 1: 日记相关只读工具
    registry.registerAll([
      DiaryReadTool(),
      DiaryListTool(),
      DiarySearchTool(ref.read(shadowIndexDatabaseProvider.notifier)),
      SummaryReadTool(ref.read(appDatabaseProvider)),
    ]);

    return registry;
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
