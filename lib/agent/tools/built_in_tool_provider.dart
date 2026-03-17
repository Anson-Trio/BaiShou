// 内置工具提供者 — 构建白守自带的所有 Agent 工具
//
// 所有具体工具类的 import 和实例化都在这一层完成。
// ToolRepository 通过调用此 provider 获取内置工具列表，无需知道具体类。

import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/diary/diary_list_tool.dart';
import 'package:baishou/agent/tools/diary/diary_read_tool.dart';
import 'package:baishou/agent/tools/diary/diary_search_tool.dart';
import 'package:baishou/agent/tools/message/message_search_tool.dart';
import 'package:baishou/agent/tools/summary/summary_read_tool.dart';
import 'package:baishou/core/database/app_database.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'built_in_tool_provider.g.dart';

/// 提供所有内置工具实例
///
/// 新增内置工具时只需在此处添加，其他地方无需改动。
@riverpod
List<AgentTool> builtInTools(Ref ref) {
  return [
    // ── 日记工具 ──
    DiaryReadTool(),
    DiaryListTool(),
    DiarySearchTool(ref.read(shadowIndexDatabaseProvider.notifier)),

    // ── 总结工具 ──
    SummaryReadTool(ref.read(appDatabaseProvider)),

    // ── 记忆工具 ──
    MessageSearchTool(ref.read(sessionManagerProvider)),
  ];
}
