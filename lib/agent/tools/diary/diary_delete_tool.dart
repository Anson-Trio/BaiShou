/// DiaryDeleteTool — 删除指定日期的日记
///
/// Agent 通过此工具删除指定日期的日记文件。
/// 会同时删除物理文件和对应的 RAG 向量。


import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class DiaryDeleteTool extends AgentTool {
  final DiaryRepository _repo;

  DiaryDeleteTool(this._repo);

  @override
  String get id => 'diary_delete';

  @override
  String get displayName => t.agent.tools.diary_delete;

  @override
  String get category => 'diary';

  @override
  IconData get icon => Icons.delete_outline_rounded;

  @override
  bool get canBeDisabled => false;

  @override
  String get description =>
      'Delete a diary entry for a specific date. '
      'This permanently removes the Markdown file at Journals/YYYY/MM/YYYY-MM-DD.md. '
      'IMPORTANT: Always confirm with the user before deleting. '
      'Use diary_read first to verify the content that will be deleted.';

  @override
  Map<String, dynamic> get parameterSchema => {
    'type': 'object',
    'properties': {
      'date': {
        'type': 'string',
        'description': 'The date of the diary to delete, in YYYY-MM-DD format.',
      },
    },
    'required': ['date'],
  };

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  ) async {
    final date = arguments['date'] as String?;

    if (date == null || date.isEmpty) {
      return ToolResult.error('Missing required parameter: date');
    }

    // 验证日期格式
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(date)) {
      return ToolResult.error(
        'Invalid date format "$date". Expected YYYY-MM-DD.',
      );
    }

    try {
      final start = DateTime.parse(date);
      // 扩大前后一天的搜索范围，防止跨时区或特殊情况导致的漏删
      final startOfDay = DateTime(start.year, start.month, start.day).subtract(const Duration(days: 1));
      final endOfDay = DateTime(start.year, start.month, start.day, 23, 59, 59).add(const Duration(days: 1));
      final allDiaries = await _repo.getDiariesByDateRange(startOfDay, endOfDay);

      // 在内存中精准过滤出本地日期对应的那一天
      final diaries = allDiaries.where((d) {
        final localD = d.date.toLocal();
        return localD.year == start.year && localD.month == start.month && localD.day == start.day;
      }).toList();

      if (diaries.isEmpty) {
        return ToolResult(
          output: 'No diary found for date $date. Nothing to delete.',
          success: true,
          metadata: {'date': date, 'deleted': false},
        );
      }

      int deletedCount = 0;
      int deletedLength = 0;
      String lastPreview = '';

      for (final diary in diaries) {
        final content = diary.content;
        if (content.isNotEmpty) {
           lastPreview = content.length > 80
              ? '${content.substring(0, 80)}...'
              : content;
           deletedLength += content.length;
        }

        // 使用标准的 Repo 接口删除：会自动清理物理文件、SQLite索引、RAG向量，并直接同步内存更新 UI！
        await _repo.deleteDiary(diary.id);
        deletedCount++;
      }

      return ToolResult(
        output:
            'Diary for $date has been deleted successfully. ($deletedCount entry/entries removed)\n'
            'Deleted content preview: $lastPreview',
        success: true,
        metadata: {
          'date': date,
          'deleted': true,
          'deleted_length': deletedLength,
        },
      );
    } catch (e) {
      return ToolResult.error('Failed to delete diary: $e');
    }
  }
}
