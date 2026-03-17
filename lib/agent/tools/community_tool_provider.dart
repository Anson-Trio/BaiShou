// 社区工具提供者 — 加载用户安装的社区工具
//
// 当前为空实现（桩），为未来社区工具功能预留接口。
// 社区工具将通过数据库表（installed_tools）管理，
// 每个工具以声明式 manifest 描述，运行时动态加载。

import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'community_tool_provider.g.dart';

/// 提供所有社区工具实例
///
/// 当前返回空列表。未来将从数据库加载已安装的社区工具。
@riverpod
List<AgentTool> communityTools(Ref ref) {
  // TODO: 从数据库加载已安装的社区工具
  // final db = ref.read(appDatabaseProvider);
  // final manifests = await db.getInstalledCommunityTools();
  // return manifests.map((m) => CommunityToolAdapter(m)).toList();
  return [];
}
