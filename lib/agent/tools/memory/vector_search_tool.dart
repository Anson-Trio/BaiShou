// 向量语义搜索工具
//
// Agent 工具：通过 sqlite-vec 原生向量引擎进行语义搜索历史消息。
// 支持纯向量搜索和 FTS5+向量混合搜索两种模式。

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/agent/rag/hybrid_search.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_config_param.dart';
import 'package:flutter/material.dart';

/// 向量语义搜索工具
class VectorSearchTool extends AgentTool {
  final AgentDatabase _db;
  final EmbeddingService _embeddingService;

  VectorSearchTool(this._db, this._embeddingService);

  @override
  String get id => 'vector_search';

  @override
  String get displayName => '语义搜索';

  @override
  String get category => 'memory';

  @override
  IconData get icon => Icons.travel_explore;

  @override
  bool get canBeDisabled => true;

  @override
  String get description =>
      '通过语义相似度搜索历史对话，理解用户意图而非精确关键词匹配。'
      '使用 sqlite-vec 原生 SIMD 加速向量搜索引擎。';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': '要搜索的语义查询，描述你想找的内容的含义',
          },
          'mode': {
            'type': 'string',
            'enum': ['vector', 'hybrid'],
            'description':
                '搜索模式: vector=纯语义搜索, hybrid=语义+关键词混合搜索（推荐）',
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
    final mode = arguments['mode'] as String? ?? 'hybrid';

    if (query.isEmpty) {
      return ToolResult(output: '请提供搜索查询内容。');
    }

    final maxResults = context.userConfig['max_results'] as int? ?? 10;

    try {
      // 生成查询向量
      final queryEmbedding = await _embeddingService.embedQuery(query);
      if (queryEmbedding == null) {
        return ToolResult(
          output: '嵌入模型未配置或查询嵌入失败。请在设置中配置嵌入模型。',
        );
      }

      List<SearchResult> results;

      if (mode == 'hybrid') {
        // ── 混合搜索：原生向量 KNN + FTS5 → RRF 融合 ──
        final vectorRaw = await _db.searchSimilar(
          queryEmbedding: queryEmbedding,
          topK: maxResults * 2,
        );
        final vectorResults = vectorRaw
            .map((r) => SearchResult(
                  messageId: r['message_id'] as String,
                  sessionId: r['session_id'] as String,
                  chunkText: r['chunk_text'] as String,
                  sessionTitle: r['session_title'] as String,
                  score: 1.0 - (r['distance'] as double), // distance → similarity
                  source: 'vector',
                ))
            .toList();

        // FTS5 搜索
        final ftsRaw = await _db.searchFts(query, limit: maxResults * 2);
        final ftsResults = ftsRaw
            .map((r) => SearchResult(
                  messageId: r['message_id'] as String,
                  sessionId: r['session_id'] as String,
                  chunkText: r['snippet'] as String,
                  sessionTitle: r['session_title'] as String,
                  score: 0,
                  source: 'fts',
                ))
            .toList();

        results = HybridSearch.merge(
          ftsResults: ftsResults,
          vectorResults: vectorResults,
          limit: maxResults,
        );
      } else {
        // ── 纯向量搜索：直接调用原生 KNN ──
        final vectorRaw = await _db.searchSimilar(
          queryEmbedding: queryEmbedding,
          topK: maxResults,
        );
        results = vectorRaw
            .map((r) => SearchResult(
                  messageId: r['message_id'] as String,
                  sessionId: r['session_id'] as String,
                  chunkText: r['chunk_text'] as String,
                  sessionTitle: r['session_title'] as String,
                  score: 1.0 - (r['distance'] as double),
                  source: 'vector',
                ))
            .toList();
      }

      if (results.isEmpty) {
        return ToolResult(output: '没有找到语义相关的历史消息。');
      }

      // 格式化输出
      final buffer = StringBuffer();
      buffer.writeln('找到 ${results.length} 条语义相关消息：\n');

      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        buffer.writeln('--- 结果 ${i + 1} [${r.source}] ---');
        buffer.writeln('会话: ${r.sessionTitle}');
        buffer.writeln('内容: ${r.chunkText}');
        buffer.writeln('相似度: ${r.score.toStringAsFixed(4)}');
        buffer.writeln();
      }

      return ToolResult(output: buffer.toString());
    } catch (e) {
      return ToolResult(output: '语义搜索失败: $e');
    }
  }

  @override
  List<ToolConfigParam> get configurableParams => [
        ToolConfigParam(
          key: 'max_results',
          label: '最大结果数',
          description: '语义搜索返回的最大结果数量',
          type: ParamType.integer,
          defaultValue: 10,
          min: 1,
          max: 50,
        ),
      ];
}
