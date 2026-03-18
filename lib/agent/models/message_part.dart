/// Agent 消息 Part 模型
/// 参考 opencode: packages/opencode/src/session/message-v2.ts (Part 类型)
///
/// 每条 Message 包含多个 Part，Part 是最细粒度的存储单元。
/// 在 DB 中以 JSON blob 存储 data 字段。

import 'dart:convert';

/// Part 类型枚举
enum PartType {
  text,
  tool,
  stepFinish,
  compaction,
}

/// 消息 Part 基类
sealed class MessagePart {
  final String id;
  final String messageId;
  final String sessionId;
  PartType get type;

  const MessagePart({
    required this.id,
    required this.messageId,
    required this.sessionId,
  });

  /// 序列化 data 字段（不含 id/messageId/sessionId，那些是列字段）
  Map<String, dynamic> toDataMap();

  /// 完整序列化（含元信息）
  Map<String, dynamic> toMap() => {
        'id': id,
        'messageId': messageId,
        'sessionId': sessionId,
        'type': type.name,
        'data': toDataMap(),
      };

  /// 从 DB 行反序列化
  static MessagePart fromRow({
    required String id,
    required String messageId,
    required String sessionId,
    required String type,
    required String dataJson,
  }) {
    final data = jsonDecode(dataJson) as Map<String, dynamic>;
    final partType = PartType.values.byName(type);

    return switch (partType) {
      PartType.text => TextPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          text: data['text'] as String? ?? '',
          toolCallId: data['toolCallId'] as String?,
          toolName: data['toolName'] as String?,
        ),
      PartType.tool => ToolPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          callId: data['callId'] as String,
          toolName: data['toolName'] as String,
          status: ToolPartStatus.values.byName(
            data['status'] as String? ?? 'pending',
          ),
          input: data['input'] as Map<String, dynamic>? ?? {},
          output: data['output'] as String?,
          timeStartMs: data['timeStartMs'] as int?,
          timeEndMs: data['timeEndMs'] as int?,
          timeCompactedMs: data['timeCompactedMs'] as int?,
        ),
      PartType.stepFinish => StepFinishPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          inputTokens: data['inputTokens'] as int? ?? 0,
          outputTokens: data['outputTokens'] as int? ?? 0,
          cachedInputTokens: data['cachedInputTokens'] as int?,
          costMicros: data['costMicros'] as int? ?? 0,
        ),
      PartType.compaction => CompactionPart(
          id: id,
          messageId: messageId,
          sessionId: sessionId,
          auto: data['auto'] as bool? ?? true,
        ),
    };
  }
}

/// 文本 Part — 消息的文本内容
class TextPart extends MessagePart {
  final String text;
  /// tool result 消息的 toolCallId（仅 role=tool 时有值）
  final String? toolCallId;
  /// tool result 消息的 toolName（仅 role=tool 时有值）
  final String? toolName;

  const TextPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.text,
    this.toolCallId,
    this.toolName,
  });

  @override
  PartType get type => PartType.text;

  @override
  Map<String, dynamic> toDataMap() => {
        'text': text,
        if (toolCallId != null) 'toolCallId': toolCallId,
        if (toolName != null) 'toolName': toolName,
      };
}

/// 工具调用 Part 状态
enum ToolPartStatus { pending, running, completed, error }

/// 工具调用 Part — 记录工具调用的完整生命周期
class ToolPart extends MessagePart {
  final String callId;
  final String toolName;
  final ToolPartStatus status;
  final Map<String, dynamic> input;
  final String? output;
  final int? timeStartMs; // 开始时间戳（毫秒）
  final int? timeEndMs; // 结束时间戳（毫秒）
  final int? timeCompactedMs; // 被压缩的时间戳（prune 用）

  const ToolPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.callId,
    required this.toolName,
    required this.status,
    this.input = const {},
    this.output,
    this.timeStartMs,
    this.timeEndMs,
    this.timeCompactedMs,
  });

  /// 工具执行耗时（毫秒）
  int? get durationMs =>
      timeStartMs != null && timeEndMs != null
          ? timeEndMs! - timeStartMs!
          : null;

  /// 是否已被压缩（prune 后的工具输出不再发给 LLM）
  bool get isCompacted => timeCompactedMs != null;

  @override
  PartType get type => PartType.tool;

  @override
  Map<String, dynamic> toDataMap() => {
        'callId': callId,
        'toolName': toolName,
        'status': status.name,
        'input': input,
        if (output != null) 'output': output,
        if (timeStartMs != null) 'timeStartMs': timeStartMs,
        if (timeEndMs != null) 'timeEndMs': timeEndMs,
        if (timeCompactedMs != null) 'timeCompactedMs': timeCompactedMs,
      };

  /// 创建一个更新了状态的副本
  ToolPart copyWith({
    ToolPartStatus? status,
    String? output,
    int? timeStartMs,
    int? timeEndMs,
    int? timeCompactedMs,
  }) =>
      ToolPart(
        id: id,
        messageId: messageId,
        sessionId: sessionId,
        callId: callId,
        toolName: toolName,
        status: status ?? this.status,
        input: input,
        output: output ?? this.output,
        timeStartMs: timeStartMs ?? this.timeStartMs,
        timeEndMs: timeEndMs ?? this.timeEndMs,
        timeCompactedMs: timeCompactedMs ?? this.timeCompactedMs,
      );
}

/// LLM 单步统计 Part — 记录每次 LLM 调用的 token 和费用
class StepFinishPart extends MessagePart {
  final int inputTokens;
  final int outputTokens;
  final int? cachedInputTokens;
  final int costMicros; // 美元 × 1,000,000

  const StepFinishPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    required this.inputTokens,
    required this.outputTokens,
    this.cachedInputTokens,
    required this.costMicros,
  });

  @override
  PartType get type => PartType.stepFinish;

  @override
  Map<String, dynamic> toDataMap() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        if (cachedInputTokens != null) 'cachedInputTokens': cachedInputTokens,
        'costMicros': costMicros,
      };
}

/// 压缩标记 Part — 标记此消息是一次上下文压缩的结果
class CompactionPart extends MessagePart {
  final bool auto;

  const CompactionPart({
    required super.id,
    required super.messageId,
    required super.sessionId,
    this.auto = true,
  });

  @override
  PartType get type => PartType.compaction;

  @override
  Map<String, dynamic> toDataMap() => {'auto': auto};
}
