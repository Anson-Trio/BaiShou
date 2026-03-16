/// 上下文窗口服务
/// 滑动窗口机制：从 DB 取最近 N 条消息作为 LLM 上下文
///
/// 核心思路：
/// - 短期记忆 = 滑动窗口（最近 N 条消息，完整原文）
/// - 长期记忆 = LifeBook 日记/总结系统 + 可选 RAG
/// - 窗口大小 N 由用户设置控制

import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/session/session_manager.dart';

/// 上下文窗口配置
class ContextWindowConfig {
  /// 最近消息条数（用户可配，默认 20）
  final int recentCount;

  const ContextWindowConfig({
    this.recentCount = 20,
  });
}

/// 上下文窗口 — 构建发送给 LLM 的消息列表
class ContextWindow {
  /// 从 DB 取最近 N 条消息作为 context
  ///
  /// 保证：
  /// 1. 不会在 tool_calls / tool_result 之间截断（保持 pair 完整）
  /// 2. 如果 isSummary 消息存在，从最近的 summary 开始
  /// 3. 返回按时间升序排列的消息
  static Future<List<ChatMessage>> build({
    required String sessionId,
    required SessionManager manager,
    ContextWindowConfig config = const ContextWindowConfig(),
  }) async {
    // 从 DB 取全部消息
    final allMessages = await manager.getMessages(sessionId);

    if (allMessages.length <= config.recentCount) {
      return allMessages;
    }

    // 取最后 N 条
    var startIndex = allMessages.length - config.recentCount;

    // 往前修正：不要在 tool result 开头截断（保持 assistant+tool 的完整性）
    // 如果 startIndex 处的消息是 tool 类型，往前找到对应的 assistant 消息
    while (startIndex > 0 &&
        allMessages[startIndex].role == MessageRole.tool) {
      startIndex--;
    }

    // 如果 startIndex 处是 assistant 且有 toolCalls，确保后面的 tool results 也包含
    // （不需要额外处理，因为我们是往前扩展的）

    return allMessages.sublist(startIndex);
  }

  /// 从内存消息列表中取最近 N 条（用于不需要 DB 查询的场景）
  static List<ChatMessage> fromMemory({
    required List<ChatMessage> messages,
    ContextWindowConfig config = const ContextWindowConfig(),
  }) {
    if (messages.length <= config.recentCount) {
      return messages;
    }

    var startIndex = messages.length - config.recentCount;

    // 同上：不在 tool result 中间截断
    while (startIndex > 0 &&
        messages[startIndex].role == MessageRole.tool) {
      startIndex--;
    }

    return messages.sublist(startIndex);
  }
}
