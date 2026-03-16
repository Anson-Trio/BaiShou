/// 流式输出事件模型
/// 参考 opencode: packages/opencode/src/session/processor.ts (流事件类型)

import 'package:baishou/agent/models/chat_message.dart';

/// Token 用量统计
class TokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int? cachedInputTokens;
  final int? reasoningTokens;

  const TokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.cachedInputTokens,
    this.reasoningTokens,
  });

  int get totalTokens => inputTokens + outputTokens;

  Map<String, dynamic> toMap() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        if (cachedInputTokens != null) 'cachedInputTokens': cachedInputTokens,
        if (reasoningTokens != null) 'reasoningTokens': reasoningTokens,
      };

  factory TokenUsage.fromMap(Map<String, dynamic> map) => TokenUsage(
        inputTokens: map['inputTokens'] as int? ?? 0,
        outputTokens: map['outputTokens'] as int? ?? 0,
        cachedInputTokens: map['cachedInputTokens'] as int?,
        reasoningTokens: map['reasoningTokens'] as int?,
      );
}

/// LLM 流式响应事件 — 统一所有供应商的输出格式
sealed class StreamEvent {
  const StreamEvent();
}

/// 文本增量
class TextDelta extends StreamEvent {
  final String text;
  const TextDelta(this.text);
}

/// 工具调用开始
class ToolCallStart extends StreamEvent {
  final String callId;
  final String toolName;
  const ToolCallStart({required this.callId, required this.toolName});
}

/// 工具调用参数增量 (JSON 片段)
class ToolCallDelta extends StreamEvent {
  final String callId;
  final String argumentsDelta;
  const ToolCallDelta({required this.callId, required this.argumentsDelta});
}

/// 工具调用完成
class ToolCallComplete extends StreamEvent {
  final ToolCall toolCall;
  const ToolCallComplete(this.toolCall);
}

/// 流结束
class StreamDone extends StreamEvent {
  final String? finishReason;
  final TokenUsage? usage;
  const StreamDone({this.finishReason, this.usage});
}

/// 流错误
class StreamError extends StreamEvent {
  final Object error;
  final StackTrace? stackTrace;
  const StreamError(this.error, [this.stackTrace]);
}

