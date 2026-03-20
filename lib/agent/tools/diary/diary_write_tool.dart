/// DiaryWriteTool — AI 写入/追加日记内容
///
/// Agent 通过此工具将内容写入指定日期的 Markdown 日记文件。
/// 如果日记已存在，默认追加；可设置 overwrite 覆盖。
/// AI 应先用 diary_read 读取再用此工具写入，确保不覆盖重要内容。

import 'dart:io';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class DiaryWriteTool extends AgentTool {
  @override
  String get id => 'diary_write';

  @override
  String get displayName => t.agent.tools.diary_write;

  @override
  String get category => 'diary';

  @override
  IconData get icon => Icons.edit_note_rounded;

  @override
  bool get canBeDisabled => false;

  @override
  String get description =>
      'Write or append content to a diary entry for a specific date. '
      'The diary file is a Markdown file located at Journals/YYYY/MM/YYYY-MM-DD.md. '
      'IMPORTANT: Always use diary_read first to check existing content before writing, '
      'to avoid overwriting important entries. '
      'By default, content is appended to the end of the file. '
      'When appending, content MUST be formatted with a level-5 heading using the current time: '
      '"##### HH:mm\n{content}". If no date is specified, the current date will be used. '
      'Set mode to "overwrite" to replace the entire file content.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'date': {
            'type': 'string',
            'description':
                'The date of the diary to write, in YYYY-MM-DD format. '
                'If omitted, the current date will be used.',
          },
          'content': {
            'type': 'string',
            'description':
                'The Markdown content to write to the diary. '
                'For append mode, this will be added after existing content with a newline separator.',
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

    // 如果未指定日期，使用当前日期
    final date = (rawDate != null && rawDate.isNotEmpty)
        ? rawDate
        : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (content == null || content.isEmpty) {
      return ToolResult.error('Missing required parameter: content');
    }

    // 验证日期格式
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(date)) {
      return ToolResult.error(
        'Invalid date format "$date". Expected YYYY-MM-DD.',
      );
    }

    // 解析年月 → 构建路径: Journals/YYYY/MM/YYYY-MM-DD.md
    final parts = date.split('-');
    final year = parts[0];
    final month = parts[1];
    final dirPath = '${context.vaultPath}/Journals/$year/$month';
    final filePath = '$dirPath/$date.md';

    try {
      // 确保目录存在
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(filePath);
      final existed = await file.exists();

      if (mode == 'overwrite' || !existed) {
        // 覆盖模式或文件不存在：直接写入
        await file.writeAsString(content);
        return ToolResult(
          output: existed
              ? 'Diary for $date has been overwritten successfully.'
              : 'Diary for $date has been created successfully.',
          success: true,
          metadata: {
            'date': date,
            'mode': existed ? 'overwrite' : 'create',
            'length': content.length,
          },
        );
      } else {
        // 追加模式：自动加上 ##### HH:mm 五级标题
        final existing = await file.readAsString();
        final separator = existing.endsWith('\n') ? '\n' : '\n\n';
        final timeHeader = '##### ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        // 如果内容已包含五级标题则不再自动添加
        final formattedContent = content.trimLeft().startsWith('#####')
            ? content
            : '$timeHeader\n$content';
        final newContent = '$existing$separator$formattedContent';
        await file.writeAsString(newContent);
        return ToolResult(
          output: 'Content has been appended to diary for $date. '
              'Total length: ${newContent.length} characters.',
          success: true,
          metadata: {
            'date': date,
            'mode': 'append',
            'previous_length': existing.length,
            'appended_length': formattedContent.length,
            'total_length': newContent.length,
          },
        );
      }
    } catch (e) {
      return ToolResult.error('Failed to write diary: $e');
    }
  }
}
