/// DiaryReadTool — 读取指定日期的日记内容
///
/// Agent 通过此工具读取用户的 Markdown 日记文件

import 'dart:io';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class DiaryReadTool extends AgentTool {
  @override
  String get id => 'diary_read';

  @override
  String get displayName => t.agent.tools.diary_read;

  @override
  String get category => 'diary';

  @override
  IconData get icon => Icons.auto_stories_outlined;

  @override
  bool get canBeDisabled => false;

  @override
  String get description =>
      'Read diary entries for a specific date. Returns the full Markdown content of the diary file. '
      'Date format: YYYY-MM-DD (e.g. 2026-03-15).';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'date': {
            'type': 'string',
            'description':
                'The date of the diary to read, in YYYY-MM-DD format.',
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

    // 解析年月 → 构建路径: Journals/YYYY/MM/YYYY-MM-DD.md
    final parts = date.split('-');
    final year = parts[0];
    final month = parts[1];
    final filePath =
        '${context.vaultPath}/Journals/$year/$month/$date.md';

    final file = File(filePath);
    if (!await file.exists()) {
      return ToolResult(
        output: 'No diary found for date $date.',
        success: true,
        metadata: {'date': date, 'found': false},
      );
    }

    try {
      final content = await file.readAsString();
      return ToolResult(
        output: content,
        success: true,
        metadata: {'date': date, 'found': true, 'length': content.length},
      );
    } catch (e) {
      return ToolResult.error('Failed to read diary: $e');
    }
  }
}
