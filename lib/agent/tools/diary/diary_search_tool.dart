/// DiarySearchTool — 关键词搜索日记内容
///
/// 基于 ShadowIndexDatabase 的 FTS5 全文索引进行搜索
/// Agent 通过此工具按关键词查找日记，无需知道具体日期

import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';

class DiarySearchTool extends AgentTool {
  final ShadowIndexDatabase _indexDb;

  DiarySearchTool(this._indexDb);

  @override
  String get id => 'diary_search';

  @override
  String get description =>
      'Search diary entries by keyword. Returns matching diary dates and content snippets. '
      'Useful when the user asks about a topic but does not specify a date.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'The search keyword or phrase to find in diary entries.',
          },
          'start_date': {
            'type': 'string',
            'description':
                'Optional. Only search diary entries on or after this date (YYYY-MM-DD). '
                    'Use this to narrow results to a specific time period.',
          },
          'end_date': {
            'type': 'string',
            'description':
                'Optional. Only search diary entries on or before this date (YYYY-MM-DD).',
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
    final query = arguments['query'] as String?;
    final startDate = arguments['start_date'] as String?;
    final endDate = arguments['end_date'] as String?;
    final limit = (arguments['limit'] as num?)?.toInt() ?? 10;

    if (query == null || query.trim().isEmpty) {
      return ToolResult.error('Missing required parameter: query');
    }

    try {
      final db = await _indexDb.database;

      // 构建日期过滤条件
      String dateFilter = '';
      final params = <Object>[query.trim()];

      if (startDate != null) {
        dateFilter += ' AND ji.date >= ?';
        params.add(startDate);
      }
      if (endDate != null) {
        dateFilter += ' AND ji.date <= ?';
        params.add(endDate);
      }
      params.add(limit);

      // 使用 FTS5 MATCH 语法搜索
      // snippet() 函数返回匹配上下文，方便 Agent 理解内容
      final results = await db.rawQuery(
        '''
        SELECT 
          ji.date,
          ji.mood,
          ji.weather,
          ji.location,
          snippet(journals_fts, 0, '**', '**', '...', 64) AS snippet
        FROM journals_fts 
        JOIN journals_index ji ON journals_fts.rowid = ji.id
        WHERE journals_fts MATCH ?$dateFilter
        ORDER BY ji.date DESC
        LIMIT ?
        ''',
        params,
      );

      if (results.isEmpty) {
        return ToolResult(
          output: 'No diary entries found matching "$query".',
          success: true,
          metadata: {'query': query, 'count': 0},
        );
      }

      final buffer = StringBuffer()
        ..writeln('Found ${results.length} diary entries matching "$query":')
        ..writeln();

      for (final row in results) {
        final date = row['date'] as String;
        final snippet = row['snippet'] as String? ?? '';
        final mood = row['mood'] as String?;
        final weather = row['weather'] as String?;
        final location = row['location'] as String?;

        buffer.writeln('## $date');
        if (mood != null || weather != null || location != null) {
          final meta = [
            if (mood != null) 'Mood: $mood',
            if (weather != null) 'Weather: $weather',
            if (location != null) 'Location: $location',
          ].join(' | ');
          buffer.writeln(meta);
        }
        buffer.writeln(snippet);
        buffer.writeln();
      }

      return ToolResult(
        output: buffer.toString(),
        success: true,
        metadata: {
          'query': query,
          'count': results.length,
          'dates': results.map((r) => r['date']).toList(),
        },
      );
    } catch (e) {
      // FTS5 不可用时降级为 LIKE 查询
      return _fallbackSearch(query, limit, context);
    }
  }

  /// 降级方案：FTS5 不可用时使用 LIKE 查询
  Future<ToolResult> _fallbackSearch(
    String query,
    int limit,
    ToolContext context,
  ) async {
    try {
      final db = await _indexDb.database;

      final results = await db.rawQuery(
        '''
        SELECT 
          ji.date,
          ji.mood,
          jf.content
        FROM journals_fts jf
        JOIN journals_index ji ON jf.rowid = ji.id
        WHERE jf.content LIKE ?
        ORDER BY ji.date DESC
        LIMIT ?
        ''',
        ['%$query%', limit],
      );

      if (results.isEmpty) {
        return ToolResult(
          output: 'No diary entries found matching "$query".',
          success: true,
          metadata: {'query': query, 'count': 0},
        );
      }

      final buffer = StringBuffer()
        ..writeln(
            'Found ${results.length} diary entries matching "$query" (fuzzy):')
        ..writeln();

      for (final row in results) {
        final date = row['date'] as String;
        final content = row['content'] as String? ?? '';
        // 截取前 200 字作为摘要
        final preview =
            content.length > 200 ? '${content.substring(0, 200)}...' : content;
        buffer.writeln('## $date');
        buffer.writeln(preview);
        buffer.writeln();
      }

      return ToolResult(
        output: buffer.toString(),
        success: true,
        metadata: {'query': query, 'count': results.length},
      );
    } catch (e) {
      return ToolResult.error('Search failed: $e');
    }
  }
}
