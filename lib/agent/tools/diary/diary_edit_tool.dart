/// DiaryEditTool — AI 写入/追加/编辑日记内容
///
/// Agent 通过此工具将内容写入指定日期的 Markdown 日记文件。
/// 支持自动管理标签与获取时间上下文，并能处理增量读写。

import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';

class DiaryEditTool extends AgentTool {
  final DiaryRepository repository;

  DiaryEditTool(this.repository);

  @override
  String get id => 'diary_edit';

  @override
  String get displayName => t.agent.tools.diary_edit;

  @override
  String get category => 'diary';

  @override
  IconData get icon => Icons.edit_note_rounded;

  @override
  bool get canBeDisabled => false;

  @override
  String get description =>
      'Write, append, or edit content in a diary entry for a specific date. '
      'MANDATORY: You MUST call diary_read FIRST to check if a diary already exists '
      'for the target date and review its current content BEFORE calling this tool.\n'
      'TEMPORAL AWARENESS: When writing entries for past dates, use absolute temporal context. '
      'DO NOT write relative words like "yesterday" in yesterday\'s diary. Write "I did X" or "Today I did X" (as if writing exactly on that day).\n'
      'TAGS: Analyze the content to determine if new tags are needed (e.g. food, programming, weather). Pass them to the `tags` array parameter. The tool will merge them with existing tags.\n'
      'By default, content is appended. When appending, content MUST be formatted with a level-5 heading using the current time: '
      '"##### HH:mm\\n{content}". Use the current_time tool to get the exact time if needed. '
      'Set mode to "overwrite" to replace the entire file content.';

  @override
  Map<String, dynamic> get parameterSchema => {
    'type': 'object',
    'properties': {
      'date': {
        'type': 'string',
        'description':
            'The date of the diary to edit, in YYYY-MM-DD format. '
            'If omitted, the current date will be used.',
      },
      'content': {
        'type': 'string',
        'description':
            'The Markdown content to write to the diary.',
      },
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'A list of new tags relevant to this edit (e.g. ["美食", "日常"]). '
            'The tool will automatically merge these with existing tags.',
      },
      'mode': {
        'type': 'string',
        'enum': ['append', 'overwrite'],
        'description':
            'Write mode: "append" (default) adds content to the end, '
            '"overwrite" replaces the entire file.',
      },
    },
    'required': ['content'],
  };

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  ) async {
    final now = DateTime.now();
    final rawDate = arguments['date'] as String?;
    final content = arguments['content'] as String?;
    final mode = arguments['mode'] as String? ?? 'append';
    
    final tagsDynamic = arguments['tags'] as List<dynamic>?;
    final newTags = tagsDynamic?.map((e) => e.toString()).toList() ?? [];

    final date = (rawDate != null && rawDate.isNotEmpty)
        ? rawDate
        : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (content == null || content.isEmpty) {
      return ToolResult.error('Missing required parameter: content');
    }

    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(date)) {
      return ToolResult.error(
        'Invalid date format "$date". Expected YYYY-MM-DD.',
      );
    }

    final parts = date.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final logicalDate = DateTime(year, month, day);

    try {
      // 扩大前后一天的搜索范围，防止跨时区或特殊情况下导致的数据库截断偏差
      final startOfDay = DateTime(year, month, day).subtract(const Duration(days: 1));
      final endOfDay = DateTime(year, month, day, 23, 59, 59, 999).add(const Duration(days: 1));
      final allDiaries = await repository.getDiariesByDateRange(startOfDay, endOfDay);
      
      // 在内存中精准过滤出本地日期对应的那一天
      final diaries = allDiaries.where((d) {
        final localD = d.date.toLocal();
        return localD.year == year && localD.month == month && localD.day == day;
      }).toList();
      
      final existingDiary = diaries.isNotEmpty ? diaries.first : null;
      final existed = existingDiary != null;
      
      List<String> finalTags = [];
      if (existed && mode == 'append') {
        finalTags.addAll(existingDiary.tags);
      }
      for (final t in newTags) {
        if (!finalTags.contains(t)) {
          finalTags.add(t);
        }
      }

      String finalContent = content;

      if (mode == 'overwrite' || !existed) {
        // 覆盖或是新建
      } else {
        // 追加模式
        final existingContent = existingDiary.content;
        final separator = existingContent.endsWith('\n') ? '\n' : '\n\n';
        final timeHeader =
            '##### ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            
        final formattedContent = content.trimLeft().startsWith('#####')
            ? content
            : '$timeHeader\n$content';
            
        finalContent = '$existingContent$separator$formattedContent';
      }

      await repository.saveDiary(
        id: existed ? existingDiary!.id : null,
        date: logicalDate,
        content: finalContent,
        tags: finalTags,
      );

      return ToolResult(
        output: existed
            ? 'Diary for $date has been ${mode == 'append' ? 'appended' : 'overwritten'} successfully. Current tags: ${finalTags.join(", ")}'
            : 'Diary for $date has been created successfully. Current tags: ${finalTags.join(", ")}',
        success: true,
        metadata: {
          'date': date,
          'mode': existed ? mode : 'create',
          'tags_added': newTags.length,
          'total_tags': finalTags.length,
          'length': finalContent.length,
        },
      );
    } catch (e) {
      return ToolResult.error('Failed to edit diary through repository: $e');
    }
  }
}
