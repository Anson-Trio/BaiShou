// 向量语义搜索工具
//
// Agent 工具：通过 sqlite-vec 原生向量引擎进行语义搜索历史消息。
// 支持纯向量搜索和 FTS5+向量混合搜索两种模式。

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/rag/hybrid_search.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/tool_config_param.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

/// 向量语义搜索工具
class VectorSearchTool extends AgentTool {
  final AgentDatabase _db;

  VectorSearchTool(this._db);

  @override
  String get id => 'vector_search';

  @override
  String get displayName => t.agent.tools.vector_search;

  @override
  String get category => 'memory';

  @override
  IconData get icon => Icons.travel_explore;

  @override
  bool get canBeDisabled => true;

  @override
  String get description =>
      'Semantic search over conversation history and stored memories. '
      'When the user asks about past content, previous decisions, personal preferences, '
      'or anything discussed before, you MUST call this tool first. '
      'Returns the most semantically relevant conversation snippets with scores.';

  @override
  Map<String, dynamic> get parameterSchema => {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': '要搜索的语义查询，描述你想找的内容的含义'},
      'mode': {
        'type': 'string',
        'enum': ['vector', 'hybrid'],
        'description': '搜索模式: vector=纯语义搜索, hybrid=语义+关键词混合搜索（推荐）',
      },
      'min_score': {
        'type': 'number',
        'description': '最低相似度阈值(0-1)，低于此分数的结果将被过滤。默认0.3',
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
    // 从 userConfig 读取用户配置的相似度阈值，AI 也可通过参数覆盖
    final configThreshold =
        (context.userConfig['rag_similarity_threshold'] as num?)?.toDouble() ??
        0.3;
    final minScore =
        (arguments['min_score'] as num?)?.toDouble() ?? configThreshold;

    if (query.isEmpty) {
      return ToolResult(output: '请提供搜索查询内容。');
    }

    // 优先使用用户配置的 topK，工具自身的 max_results 作为备选
    final configTopK = context.userConfig['rag_top_k'] as int? ?? 20;
    final maxResults = context.userConfig['max_results'] as int? ?? configTopK;

    try {
      // 通过 ToolContext 获取 fresh EmbeddingService
      final embeddingService = context.embeddingService;
      if (embeddingService == null) {
        return ToolResult(output: '嵌入服务未配置，无法执行语义搜索。');
      }
      final queryEmbedding = await embeddingService.embedQuery(query);
      if (queryEmbedding == null) {
        return ToolResult(output: '嵌入模型未配置或查询嵌入失败。请在设置中配置嵌入模型。');
      }

      List<SearchResult> results;
      // 搜索流水线摘要（用于 UI 展示）
      final pipeline = StringBuffer();

      if (mode == 'hybrid') {
        // ── 混合搜索：原生向量 KNN + FTS5 → RRF 融合 ──

        // 1. 向量语义搜索
        final vectorRaw = await _db.searchSimilar(
          queryEmbedding: queryEmbedding,
          topK: maxResults,
        );
        final vectorResults = vectorRaw
            .map(
              (r) => SearchResult(
                messageId: r['message_id'] as String,
                sessionId: r['session_id'] as String,
                chunkText: r['chunk_text'] as String,
                sessionTitle: r['session_title'] as String,
                score: 1.0 - (r['distance'] as double),
                source: 'vector',
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['created_at'] as int,
                ),
              ),
            )
            .toList();
        final bestVecScore = vectorResults.isNotEmpty
            ? vectorResults.first.score.toStringAsFixed(4)
            : '-';
        pipeline.writeln(
          '🔍 向量语义搜索: ${vectorResults.length} 条命中 (最佳 $bestVecScore)',
        );

        // 2. FTS5 关键词搜索
        final ftsRaw = await _db.searchFts(query, limit: maxResults);
        final ftsResults = ftsRaw
            .map(
              (r) => SearchResult(
                messageId: r['message_id'] as String,
                sessionId: r['session_id'] as String,
                chunkText: r['snippet'] as String,
                sessionTitle: r['session_title'] as String,
                score: 0,
                source: 'fts',
              ),
            )
            .toList();
        pipeline.writeln('📝 FTS关键词搜索: ${ftsResults.length} 条命中');

        // 3. RRF 融合
        results = HybridSearch.merge(
          ftsResults: ftsResults,
          vectorResults: vectorResults,
          limit: maxResults,
        );
        pipeline.writeln('🔀 RRF融合排序: ${results.length} 条合并');
      } else {
        // ── 纯向量搜索 ──

        final vectorRaw = await _db.searchSimilar(
          queryEmbedding: queryEmbedding,
          topK: maxResults,
        );
        results = vectorRaw
            .map(
              (r) => SearchResult(
                messageId: r['message_id'] as String,
                sessionId: r['session_id'] as String,
                chunkText: r['chunk_text'] as String,
                sessionTitle: r['session_title'] as String,
                score: 1.0 - (r['distance'] as double),
                source: 'vector',
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['created_at'] as int,
                ),
              ),
            )
            .toList();
        pipeline.writeln('🔍 纯向量搜索: ${results.length} 条命中');
      }

      // 排序（高分优先）+ 按 min_score 过滤
      results.sort((a, b) => b.score.compareTo(a.score));
      final beforeCount = results.length;
      if (minScore > 0) {
        results = results.where((r) => r.score >= minScore).toList();
      }
      pipeline.writeln(
        '✂️ 相似度过滤 (≥${minScore.toStringAsFixed(2)}): '
        '$beforeCount → ${results.length} 条',
      );

      if (results.isEmpty) {
        return ToolResult(output: '${pipeline}没有找到语义相关的历史消息（阈值=$minScore）。');
      }

      // 格式化输出：流水线摘要 + 结果
      final buffer = StringBuffer();
      buffer.writeln('═══ 搜索流水线 ═══');
      buffer.write(pipeline);
      buffer.writeln('═══════════════');
      buffer.writeln();
      buffer.writeln('找到 ${results.length} 条相关记忆：\n');

      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        final sourceLabel = switch (r.source) {
          'hybrid' => '混合',
          'fts' => 'FTS',
          'vector' => '向量',
          _ => r.source,
        };
        buffer.writeln('--- 结果 ${i + 1} [$sourceLabel] ---');
        buffer.writeln('会话: ${r.sessionTitle}');
        if (r.createdAt != null) {
          final t = r.createdAt!;
          buffer.writeln(
            '时间: ${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
          );
        }
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
      label: t.agent.tools.param_max_results,
      description: t.agent.tools.param_max_results_desc,
      type: ParamType.integer,
      defaultValue: 10,
      min: 1,
      max: 50,
    ),
  ];
}
