// MessageSearchTool — 跨会话历史消息搜索
//
// 基于 AgentDatabase 的 FTS5 全文索引搜索历史对话消息
// Agent 通过此工具回忆过去的对话内容，实现跨会话记忆

import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_config_param.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class MessageSearchTool extends AgentTool {
  final SessionManager _sessionManager;

  MessageSearchTool(this._sessionManager);

  @override
  String get id => 'message_search';

  @override
  String get displayName => t.agent.tools.message_search;

  @override
  String get category => 'memory';

  @override
  IconData get icon => Icons.history_rounded;

  @override
  List<ToolConfigParam> get configurableParams => [
        ToolConfigParam(
          key: 'max_results',
          label: t.agent.tools.param_max_results,
          description: t.agent.tools.param_max_results_desc,
          type: ParamType.integer,
          defaultValue: 10,
          min: 1,
          max: 50,
          icon: Icons.format_list_numbered,
        ),
      ];

  @override
  String get description =>
      'Search past conversation messages across all sessions by keyword. '
      'Returns matching message snippets with session title and date. '
      'Useful when the user references something discussed before, '
      'or when you need to recall previous conversations.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'The search keyword or phrase to find in past conversations.',
          },
          'limit': {
            'type': 'integer',
            'description':
                'Maximum number of results to return. Defaults to 10.',
          },
        },
        'required': ['query'],
      };

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  ) async {
    final query = arguments['query'] as String? ?? '';
    final limit = (arguments['limit'] as num?)?.toInt() ?? 10;

    if (query.trim().isEmpty) {
      return ToolResult.error('请提供搜索关键词。');
    }

    try {
      final results = await _sessionManager.searchMessages(
        query,
        limit: limit,
      );

      if (results.isEmpty) {
        return ToolResult(output: '未找到包含「$query」的历史消息。');
      }

      final buffer = StringBuffer();
      buffer.writeln('找到 ${results.length} 条包含「$query」的历史消息：\n');

      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final role = r['role'] == 'user' ? '用户' : 'AI';
        final sessionTitle = r['session_title'] ?? '未命名会话';
        final updatedAt = r['session_updated_at'];
        final dateStr = updatedAt != null
            ? '${(updatedAt as DateTime).year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')}'
            : '未知日期';
        final snippet = r['snippet'] ?? '';

        buffer.writeln('${i + 1}. [$role] 会话「$sessionTitle」($dateStr)');
        buffer.writeln('   $snippet');
        buffer.writeln();
      }

      return ToolResult(output: buffer.toString());
    } catch (e) {
      return ToolResult.error('搜索失败：$e');
    }
  }
}

