/// Agent 聊天消息模型
/// 参考 opencode: packages/opencode/src/session/message-v2.ts

import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 消息角色
enum MessageRole { system, user, assistant, tool }

/// 工具调用请求
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'arguments': arguments,
      };

  factory ToolCall.fromMap(Map<String, dynamic> map) => ToolCall(
        id: map['id'] as String,
        name: map['name'] as String,
        arguments: Map<String, dynamic>.from(map['arguments'] as Map),
      );

  String toJson() => jsonEncode(toMap());
  factory ToolCall.fromJson(String source) =>
      ToolCall.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// 聊天消息
class ChatMessage {
  final String id;
  final MessageRole role;
  final String? content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? toolName;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.toolName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 创建 system 消息
  factory ChatMessage.system(String content) => ChatMessage(
        id: _generateId(),
        role: MessageRole.system,
        content: content,
      );

  /// 创建 user 消息
  factory ChatMessage.user(String content) => ChatMessage(
        id: _generateId(),
        role: MessageRole.user,
        content: content,
      );

  /// 创建 assistant 消息
  factory ChatMessage.assistant({
    String? content,
    List<ToolCall>? toolCalls,
  }) =>
      ChatMessage(
        id: _generateId(),
        role: MessageRole.assistant,
        content: content,
        toolCalls: toolCalls,
      );

  /// 创建 tool 执行结果消息
  factory ChatMessage.tool({
    required String callId,
    required String content,
    String? toolName,
  }) =>
      ChatMessage(
        id: _generateId(),
        role: MessageRole.tool,
        content: content,
        toolCallId: callId,
        toolName: toolName,
      );

  static const _uuid = Uuid();
  static String _generateId() => 'msg_${_uuid.v4()}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'toolCalls': toolCalls?.map((t) => t.toMap()).toList(),
        'toolCallId': toolCallId,
        'toolName': toolName,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        role: MessageRole.values.byName(map['role'] as String),
        content: map['content'] as String?,
        toolCalls: (map['toolCalls'] as List?)
            ?.map((t) => ToolCall.fromMap(t as Map<String, dynamic>))
            .toList(),
        toolCallId: map['toolCallId'] as String?,
        toolName: map['toolName'] as String?,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

  String toJson() => jsonEncode(toMap());
  factory ChatMessage.fromJson(String source) =>
      ChatMessage.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
