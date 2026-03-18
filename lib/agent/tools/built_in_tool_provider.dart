import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/agent/tools/diary/diary_list_tool.dart';
import 'package:baishou/agent/tools/diary/diary_read_tool.dart';
import 'package:baishou/agent/tools/diary/diary_search_tool.dart';
import 'package:baishou/agent/tools/memory/memory_store_tool.dart';
import 'package:baishou/agent/tools/memory/vector_search_tool.dart';
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

    // ── 语义搜索工具 ──
    VectorSearchTool(
      ref.read(agentDatabaseProvider),
    ),

    // ── 记忆存储工具 ──
    MemoryStoreTool(),
  ];
}
