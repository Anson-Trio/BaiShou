/// 流式输出事件模型
/// 参考 opencode: packages/opencode/src/session/processor.ts (流事件类型)

import 'package:baishou/agent/models/chat_message.dart';

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
  const StreamDone({this.finishReason});
}

/// 流错误
class StreamError extends StreamEvent {
  final Object error;
  final StackTrace? stackTrace;
  const StreamError(this.error, [this.stackTrace]);
}
