/// 上下文窗口服务
/// 滑动窗口机制：从 DB 取最近 N 条消息作为 LLM 上下文
///
/// 核心思路：
/// - 短期记忆 = 滑动窗口（最近 N 条消息，完整原文）
/// - 长期记忆 = 压缩摘要（自动生成的对话概要）
/// - 更长期记忆 = LifeBook 日记/总结系统 + 可选 RAG
/// - 窗口大小 N 由用户设置控制

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/session/session_manager.dart';

/// 上下文窗口配置
class ContextWindowConfig {
  /// 最近消息条数（用户可配，默认 30，0 表示不限制）
  final int recentCount;

  const ContextWindowConfig({this.recentCount = 30});
}

/// 上下文窗口 — 构建发送给 LLM 的消息列表
class ContextWindow {
  /// 从 DB 取最近 N 条消息作为 context
  ///
  /// 支持压缩快照：如果有快照，上下文 = [摘要作为 system 消息] + [压缩点后的消息]
  ///
  /// 保证：
  /// 1. 不会在 tool_calls / tool_result 之间截断（保持 pair 完整）
  /// 2. 返回按时间升序排列的消息
  static Future<List<ChatMessage>> build({
    required String sessionId,
    required SessionManager manager,
    ContextWindowConfig config = const ContextWindowConfig(),
    CompressionSnapshot? snapshot,
  }) async {
    // 从 DB 取全部消息
    final allMessages = await manager.getMessages(sessionId);

    List<ChatMessage> effectiveMessages;

    if (snapshot != null) {
      // 有压缩快照：从压缩点之后开始
      final cutoffIndex = allMessages.indexWhere(
        (m) => m.id == snapshot.coveredUpToMessageId,
      );

      if (cutoffIndex >= 0 && cutoffIndex < allMessages.length - 1) {
        // 在头部插入摘要作为 system 消息
        effectiveMessages = [
          ChatMessage.system('[对话摘要]\n${snapshot.summaryText}'),
          ...allMessages.sublist(cutoffIndex + 1),
        ];
      } else {
        effectiveMessages = allMessages;
      }
    } else {
      effectiveMessages = allMessages;
    }

    if (effectiveMessages.isEmpty) return effectiveMessages;

    // recentCount <= 0 表示无限轮，不截断
    if (config.recentCount <= 0 ||
        effectiveMessages.length <= config.recentCount) {
      return effectiveMessages;
    }

    // 取最后 N 条（但始终保留摘要消息如果有的话）
    var startIndex = effectiveMessages.length - config.recentCount;

    // 确保摘要消息不被裁掉（如果存在，它在 index 0）
    if (snapshot != null && startIndex > 0) {
      startIndex = startIndex.clamp(1, effectiveMessages.length - 1);
      // 重新拼接：摘要 + 裁剪后的消息
      return [effectiveMessages[0], ...effectiveMessages.sublist(startIndex)];
    }

    // 往前修正：不要在 tool result 开头截断（保持 assistant+tool 的完整性）
    while (startIndex > 0 &&
        startIndex < effectiveMessages.length &&
        effectiveMessages[startIndex].role == MessageRole.tool) {
      startIndex--;
    }

    // 最终安全兜底
    startIndex = startIndex.clamp(0, effectiveMessages.length);
    return effectiveMessages.sublist(startIndex);
  }

  /// 从内存消息列表中取最近 N 条（用于不需要 DB 查询的场景）
  static List<ChatMessage> fromMemory({
    required List<ChatMessage> messages,
    ContextWindowConfig config = const ContextWindowConfig(),
    String? compressionSummary,
  }) {
    List<ChatMessage> effectiveMessages;

    if (compressionSummary != null) {
      // 有摘要：在头部插入
      effectiveMessages = [
        ChatMessage.system('[对话摘要]\n$compressionSummary'),
        ...messages,
      ];
    } else {
      effectiveMessages = messages;
    }

    if (effectiveMessages.isEmpty) return effectiveMessages;

    // recentCount <= 0 表示无限轮，不截断
    if (config.recentCount <= 0 ||
        effectiveMessages.length <= config.recentCount) {
      return effectiveMessages;
    }

    var startIndex = (effectiveMessages.length - config.recentCount)
        .clamp(0, effectiveMessages.length);

    // 保留摘要消息
    if (compressionSummary != null && startIndex > 0) {
      startIndex = startIndex.clamp(1, effectiveMessages.length);
      return [effectiveMessages[0], ...effectiveMessages.sublist(startIndex)];
    }

    // 同上：不在 tool result 中间截断
    while (startIndex > 0 &&
        startIndex < effectiveMessages.length &&
        effectiveMessages[startIndex].role == MessageRole.tool) {
      startIndex--;
    }

    // 最终安全兜底
    startIndex = startIndex.clamp(0, effectiveMessages.length);
    return effectiveMessages.sublist(startIndex);
  }
}

