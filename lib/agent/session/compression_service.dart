import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/session/compression_prompt.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'compression_service.g.dart';

/// 压缩时保留的最近用户对话轮数（保留最近 N 轮 user 消息及其后续的全部消息不参与摘要）
const int _kRetainUserTurns = 3;

/// 被剪枝后的替代文本
const String _kPrunedPlaceholder = '[工具输出已剪枝]';

/// 粗略估算文本 token 数（仅用于剪枝判断，不用于压缩触发）
int _roughTokens(String text) {
  if (text.isEmpty) return 0;
  return (text.length / 3.5).ceil();
}

/// 会话压缩服务
@riverpod
CompressionService compressionService(Ref ref) {
  return CompressionService(
    db: ref.read(agentDatabaseProvider),
    sessionManager: ref.read(sessionManagerProvider),
    apiConfig: ref.read(apiConfigServiceProvider),
  );
}

class CompressionService {
  final AgentDatabase db;
  final SessionManager sessionManager;
  final ApiConfigService apiConfig;

  CompressionService({
    required this.db,
    required this.sessionManager,
    required this.apiConfig,
  });

  /// 获取会话的最新压缩快照
  Future<CompressionSnapshot?> getLatestSnapshot(String sessionId) async {
    final query = db.select(db.compressionSnapshots)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(1);
    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  // ─── 压缩触发判断（使用真实 API token） ────────────────────

  /// 检查是否需要压缩
  /// 使用 session 表中 API 返回的真实累计 inputTokens
  Future<bool> shouldCompress(String sessionId, int threshold) async {
    if (threshold <= 0) return false;

    final session = await sessionManager.getSession(sessionId);
    if (session == null) return false;

    // 直接用 DB 里累计的真实 token（每次 API 调用后 addUsage 写入）
    final realTokens = session.totalInputTokens;
    debugPrint(
      'CompressionService: shouldCompress? '
      'realTokens=$realTokens, threshold=$threshold',
    );
    return realTokens > threshold;
  }

  // ─── 工具输出剪枝（参考 OpenCode prune 策略） ─────────────

  /// 剪枝：保留最近一部分工具输出，擦除更早的
  ///
  /// 保护区 = 阈值 × 50%，最小收益 = 阈值 × 20%。
  /// 纯本地操作，不需要 AI 调用。
  Future<int> prune(String sessionId, int threshold) async {
    final pruneProtect = (threshold * 0.5).toInt();  // 保护区
    final pruneMinimum = (threshold * 0.2).toInt();  // 最小收益

    final allMessages = await sessionManager.getMessages(sessionId);

    int totalToolTokens = 0;
    int prunedTokens = 0;
    final toPrune = <ChatMessage>[];

    // 从后往前遍历
    for (int i = allMessages.length - 1; i >= 0; i--) {
      final msg = allMessages[i];

      // 只处理工具返回消息
      if (msg.role != MessageRole.tool) continue;

      final content = msg.content ?? '';
      // 已经剪枝过的跳过
      if (content == _kPrunedPlaceholder) continue;

      final tokens = _roughTokens(content);
      totalToolTokens += tokens;

      // 保护区内的不动
      if (totalToolTokens <= pruneProtect) continue;

      // 超出保护区：标记为需要剪枝
      prunedTokens += tokens;
      toPrune.add(msg);
    }

    // 收益不够就不剪
    if (prunedTokens < pruneMinimum) {
      debugPrint('CompressionService: prune skipped '
          '(gain=$prunedTokens < min=$pruneMinimum)');
      return 0;
    }

    // 执行剪枝：更新 DB 中的消息内容
    for (final msg in toPrune) {
      await sessionManager.updateMessageContent(msg.id, _kPrunedPlaceholder);
    }

    debugPrint(
      'CompressionService: pruned ${toPrune.length} tool outputs, '
      'saved ~$prunedTokens tokens (protect=$pruneProtect)',
    );
    return toPrune.length;
  }

  // ─── 摘要压缩（AI 调用） ────────────────────────────────

  /// 执行压缩：先剪枝，再摘要
  ///
  /// [threshold] 压缩阈值，用于计算剪枝保护区大小
  Future<void> compress(String sessionId, {required int threshold}) async {
    try {
      debugPrint('CompressionService: Starting compression for $sessionId');

      // Step 1: 剪枝旧工具输出
      await prune(sessionId, threshold);

      // Step 2: 摘要压缩
      final snapshot = await getLatestSnapshot(sessionId);
      final allMessages = await sessionManager.getMessages(sessionId);

      // 获取压缩点之后的消息
      final messagesAfterPoint = _getMessagesAfterCompressionPoint(
        allMessages, snapshot,
      );

      // 保留最近 N 轮 user 消息及其后续的所有消息不参与压缩
      // 从后往前找到第 _kRetainUserTurns 个 user 消息的位置
      int userTurnsSeen = 0;
      int retainFromIndex = messagesAfterPoint.length;
      for (int i = messagesAfterPoint.length - 1; i >= 0; i--) {
        if (messagesAfterPoint[i].role == MessageRole.user) {
          userTurnsSeen++;
          if (userTurnsSeen >= _kRetainUserTurns) {
            retainFromIndex = i;
            break;
          }
        }
      }

      if (retainFromIndex <= 0) {
        debugPrint('CompressionService: Not enough messages to compress');
        return;
      }

      final messagesToCompress = messagesAfterPoint.sublist(0, retainFromIndex);

      if (messagesToCompress.isEmpty) return;

      // 确保不在 tool call pair 中间截断
      var cutIndex = messagesToCompress.length;
      while (cutIndex > 0 &&
          messagesToCompress[cutIndex - 1].role == MessageRole.tool) {
        cutIndex--;
      }
      if (cutIndex <= 0) return;
      final safeMessages = messagesToCompress.sublist(0, cutIndex);

      // 构建 prompt
      final formattedMessages = CompressionPrompt.formatMessages(safeMessages);
      final prompt = CompressionPrompt.build(
        previousSummary: snapshot?.summaryText,
        messagesToCompress: formattedMessages,
      );

      // 调用 AI 生成摘要
      final providerId = apiConfig.globalDialogueProviderId;
      final modelId = apiConfig.globalDialogueModelId;
      final provider = apiConfig.getProvider(providerId);

      if (provider == null || modelId.isEmpty) {
        debugPrint('CompressionService: No model configured, skipping');
        return;
      }

      final client = AiClientFactory.createClient(provider);
      final summaryText = await client.generateContent(
        prompt: prompt,
        modelId: modelId,
      );

      if (summaryText.isEmpty) {
        debugPrint('CompressionService: Empty summary, skipping');
        return;
      }

      // 计算累计压缩消息数
      final previousCount = snapshot?.messageCount ?? 0;
      final newCount = previousCount + safeMessages.length;

      // 获取最后被压缩的消息 ID
      final lastCompressedMessage = safeMessages.last;
      final coveredUpToMessageId = lastCompressedMessage.id;

      // 存入快照表（追加）
      await db.into(db.compressionSnapshots).insert(
        CompressionSnapshotsCompanion.insert(
          sessionId: sessionId,
          summaryText: summaryText,
          coveredUpToMessageId: coveredUpToMessageId,
          messageCount: newCount,
        ),
      );

      debugPrint(
        'CompressionService: Compressed $newCount messages into summary',
      );
    } catch (e) {
      debugPrint('CompressionService: Error during compression: $e');
    }
  }

  /// 获取压缩点之后的消息
  List<ChatMessage> _getMessagesAfterCompressionPoint(
    List<ChatMessage> allMessages,
    CompressionSnapshot? snapshot,
  ) {
    if (snapshot == null) return allMessages;

    final cutoffIndex = allMessages.indexWhere(
      (m) => m.id == snapshot.coveredUpToMessageId,
    );

    if (cutoffIndex < 0) return allMessages;
    return allMessages.sublist(cutoffIndex + 1);
  }
}
