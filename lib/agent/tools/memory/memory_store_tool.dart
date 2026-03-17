// 记忆存储工具
//
// Agent 工具：主动存储重要信息为长期记忆。
// 参考 OpenClaw 的 memory_search/memory_get 模式。

import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_config_param.dart';
import 'package:flutter/material.dart';

/// 记忆存储工具 — 让 Agent 主动存储重要信息
class MemoryStoreTool extends AgentTool {
  final EmbeddingService _embeddingService;

  MemoryStoreTool(this._embeddingService);

  @override
  String get id => 'memory_store';

  @override
  String get displayName => '记忆存储';

  @override
  String get category => 'memory';

  @override
  IconData get icon => Icons.save_alt;

  @override
  bool get canBeDisabled => true;

  @override
  String get description =>
      '将重要信息存储为长期记忆，供后续语义搜索检索。'
      '当用户告知偏好、做出决定、或你认为应该记住的信息时使用此工具。'
      '存储的记忆会被向量化索引，可通过 vector_search 工具检索。';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'content': {
            'type': 'string',
            'description':
                '要存储为记忆的文本内容。建议包含清晰的上下文，例如"用户偏好：喜欢深色主题"。',
          },
          'tags': {
            'type': 'string',
            'description':
                '可选标签，用逗号分隔，帮助分类记忆。例如: "偏好,UI设计"',
          },
        },
        'required': ['content'],
      };

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  ) async {
    final content = arguments['content'] as String? ?? '';
    final tags = arguments['tags'] as String? ?? '';

    if (content.trim().isEmpty) {
      return ToolResult(output: '请提供要存储的记忆内容。');
    }

    if (!_embeddingService.isConfigured) {
      return ToolResult(output: '嵌入模型未配置，无法存储记忆。请在设置中配置嵌入模型。');
    }

    try {
      // 如果有标签，附加到内容后面帮助检索
      final fullContent = tags.isNotEmpty ? '$content\n[标签: $tags]' : content;

      await _embeddingService.embedText(
        text: fullContent,
        sessionId: context.sessionId,
      );

      return ToolResult(
        output: '记忆已成功存储并建立向量索引。\n'
            '内容: ${content.length > 100 ? '${content.substring(0, 100)}...' : content}'
            '${tags.isNotEmpty ? '\n标签: $tags' : ''}',
      );
    } catch (e) {
      return ToolResult(output: '存储记忆失败: $e');
    }
  }

  @override
  List<ToolConfigParam> get configurableParams => [];
}
