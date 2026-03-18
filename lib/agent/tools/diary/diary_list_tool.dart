/// DiaryListTool — 列出日期范围内的日记列表
///
/// Agent 通过此工具了解用户在某段时间内有哪些日记

import 'dart:io';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class DiaryListTool extends AgentTool {
  @override
  String get id => 'diary_list';

  @override
  String get displayName => t.agent.tools.diary_list;

  @override
  String get category => 'diary';

  @override
  IconData get icon => Icons.list_alt_rounded;

  @override
  bool get canBeDisabled => false;

  @override
  String get description =>
      'List diary entries within a date range. Returns a list of dates that have diary entries. '
      'Useful for discovering what dates have content before reading specific entries.';

  @override
  Map<String, dynamic> get parameterSchema => {
        'type': 'object',
        'properties': {
          'start_date': {
            'type': 'string',
            'description':
                'Start date (inclusive), in YYYY-MM-DD format.',
          },
          'end_date': {
            'type': 'string',
            'description':
                'End date (inclusive), in YYYY-MM-DD format.',
          },
        },
        'required': ['start_date', 'end_date'],
      };

  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  ) async {
    final startStr = arguments['start_date'] as String?;
    final endStr = arguments['end_date'] as String?;

    if (startStr == null || endStr == null) {
      return ToolResult.error(
        'Missing required parameters: start_date and end_date',
      );
    }

    DateTime startDate, endDate;
    try {
      startDate = DateTime.parse(startStr);
      endDate = DateTime.parse(endStr);
    } catch (e) {
      return ToolResult.error(
        'Invalid date format. Expected YYYY-MM-DD.',
      );
    }

    if (endDate.isBefore(startDate)) {
      return ToolResult.error('end_date must be after start_date.');
    }

    final journalsDir = Directory('${context.vaultPath}/Journals');
    if (!await journalsDir.exists()) {
      return const ToolResult(
        output: 'No diary entries found. The Journals directory does not exist.',
        success: true,
      );
    }

    // 扫描日期范围内的日记文件
    final foundDates = <String>[];
    var current = startDate;

    while (!current.isAfter(endDate)) {
      final dateStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      final yearMonth =
          '${current.year}-${current.month.toString().padLeft(2, '0')}';
      final filePath =
          '${context.vaultPath}/Journals/$yearMonth/$dateStr.md';

      if (await File(filePath).exists()) {
        foundDates.add(dateStr);
      }

      current = current.add(const Duration(days: 1));
    }

    if (foundDates.isEmpty) {
      return ToolResult(
        output:
            'No diary entries found between $startStr and $endStr.',
        success: true,
        metadata: {'count': 0},
      );
    }

    final output = StringBuffer()
      ..writeln('Found ${foundDates.length} diary entries:')
      ..writeln()
      ..writeAll(foundDates.map((d) => '- $d'), '\n');

    return ToolResult(
      output: output.toString(),
      success: true,
      metadata: {'count': foundDates.length, 'dates': foundDates},
    );
  }
}
