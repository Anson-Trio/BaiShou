import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/prompts/system_prompt_builder.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/agent/session/compression_service.dart';
import 'package:baishou/agent/session/context_window.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_repository.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgentRunPreparation {
  final String systemPrompt;
  final List<ChatMessage> contextMessages;
  final Map<String, dynamic> toolUserConfig;
  final ToolRegistry tools;

  const AgentRunPreparation({
    required this.systemPrompt,
    required this.contextMessages,
    required this.toolUserConfig,
    required this.tools,
  });
}

class AgentContextBuilder {
  /// 收集并组装单次 Agent 运行需要的所有上下文和环境配置信息
  static Future<AgentRunPreparation> build({
    required Ref ref,
    required String sessionId,
    required String vaultName,
    String? persona,
    String? guidelines,
  }) async {
    final manager = ref.read(sessionManagerProvider);
    final apiConfig = ref.read(apiConfigServiceProvider);
    final tools = ref.read(toolRepositoryProvider.notifier).buildRegistry();

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
        resolvedPersona = assistant.systemPrompt.isNotEmpty
            ? assistant.systemPrompt
            : null;
        assistantContextWindow = assistant.contextWindow;
      }
    }

    if (!hasAssistant) resolvedPersona = persona ?? apiConfig.agentPersona;
    final userProfile = ref.read(userProfileProvider);

    final systemPrompt = SystemPromptBuilder.build(
      persona: resolvedPersona,
      guidelines: hasAssistant
          ? null
          : (guidelines ?? apiConfig.agentGuidelines),
      userProfileBlock: userProfile.toMarkdownBlock(),
      vaultName: vaultName,
      tools: tools,
    );

    // 滑动窗口上下文
    final windowSize =
        assistantContextWindow ?? apiConfig.agentContextWindowSize;
    final dbMessages = await manager.getMessages(
      sessionId,
      descending: true,
    );

    final compressor = ref.read(compressionServiceProvider);
    final snapshot = await compressor.getLatestSnapshot(sessionId);
    String? compressionSummary;

    List<ChatMessage> messagesForWindow = dbMessages
        .where((m) => m.role != MessageRole.system)
        .toList()
        .reversed
        .toList();

    if (snapshot != null) {
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

    // 构建工具上下文（合并全局 RAG 参数和 per-tool 用户配置）
    final toolUserConfig = <String, dynamic>{
      'rag_top_k': apiConfig.ragTopK,
      'rag_similarity_threshold': apiConfig.ragSimilarityThreshold,
    };
    for (final tool in tools.ids) {
      final perToolConfig = apiConfig.getToolConfig(tool);
      if (perToolConfig.isNotEmpty) {
        toolUserConfig.addAll(perToolConfig);
      }
    }

    return AgentRunPreparation(
      systemPrompt: systemPrompt,
      contextMessages: contextMessages,
      toolUserConfig: toolUserConfig,
      tools: tools,
    );
  }
}
