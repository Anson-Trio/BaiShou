/// SummaryReadTool — 读取 AI 生成的总结
///
/// Agent 通过此工具读取周/月/季度/年度总结

import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/core/database/app_database.dart';
import 'package:drift/drift.dart';

class SummaryReadTool extends AgentTool {
  final AppDatabase _db;

  SummaryReadTool(this._db);

  @override
  String get id => 'summary_read';

  @override
  String get description =>
      'Read AI-generated summaries (weekly, monthly, quarterly, or yearly). '
      'Returns the summary content for a specific time period. '
      'Use diary_list or diary_search for raw diary entries instead.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['weekly', 'monthly', 'quarterly', 'yearly'],
            'description': 'The type of summary to retrieve.',
          },
          'start_date': {
            'type': 'string',
            'description':
                'Start date of the summary period, in YYYY-MM-DD format. '
                    'For weekly: the Monday of that week. '
                    'For monthly: the first day of the month (e.g. 2026-03-01). '
                    'For quarterly: the first day of the quarter. '
                    'For yearly: the first day of the year (e.g. 2026-01-01).',
          },
        },
        'required': ['type', 'start_date'],
      };

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  ) async {
    final type = arguments['type'] as String?;
    final startDateStr = arguments['start_date'] as String?;

    if (type == null || startDateStr == null) {
      return ToolResult.error(
        'Missing required parameters: type and start_date',
      );
    }

    final validTypes = ['weekly', 'monthly', 'quarterly', 'yearly'];
    if (!validTypes.contains(type)) {
      return ToolResult.error(
        'Invalid type "$type". Must be one of: ${validTypes.join(", ")}',
      );
    }

    DateTime startDate;
    try {
      startDate = DateTime.parse(startDateStr);
    } catch (_) {
      return ToolResult.error(
        'Invalid date format "$startDateStr". Expected YYYY-MM-DD.',
      );
    }

    try {
      // 查询匹配的总结
      final results = await (_db.select(_db.summaries)
            ..where((s) =>
                s.type.equals(type) &
                s.startDate.equals(startDate)))
          .get();

      if (results.isEmpty) {
        // 如果精确日期找不到，列出该类型的可用总结
        final available = await (_db.select(_db.summaries)
              ..where((s) => s.type.equals(type))
              ..orderBy([(s) => OrderingTerm.desc(s.startDate)])
              ..limit(5))
            .get();

        if (available.isEmpty) {
          return ToolResult(
            output: 'No $type summaries found.',
            success: true,
            metadata: {'type': type, 'found': false},
          );
        }

        final dates = available
            .map((s) =>
                '- ${s.startDate.toIso8601String().substring(0, 10)} ~ ${s.endDate.toIso8601String().substring(0, 10)}')
            .join('\n');

        return ToolResult(
          output:
              'No $type summary found for $startDateStr. Available $type summaries:\n$dates',
          success: true,
          metadata: {'type': type, 'found': false},
        );
      }

      final summary = results.first;
      return ToolResult(
        output: summary.content,
        success: true,
        metadata: {
          'type': type,
          'found': true,
          'start_date': summary.startDate.toIso8601String().substring(0, 10),
          'end_date': summary.endDate.toIso8601String().substring(0, 10),
          'generated_at':
              summary.generatedAt.toIso8601String().substring(0, 10),
        },
      );
    } catch (e) {
      return ToolResult.error('Failed to read summary: $e');
    }
  }
}
