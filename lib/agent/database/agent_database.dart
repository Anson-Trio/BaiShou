import 'package:baishou/agent/database/agent_tables.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_database.g.dart';

/// Agent 专属数据库
/// 独立于主数据库（app_database），存储 Agent 的会话、消息和 Part
@DriftDatabase(tables: [AgentSessions, AgentMessages, AgentParts])
class AgentDatabase extends _$AgentDatabase {
  AgentDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2: 三表重构
            // 创建新的 AgentParts 表
            await m.createTable(agentParts);

            // AgentMessages: 添加新列
            await m.addColumn(agentMessages, agentMessages.isSummary);
            await m.addColumn(agentMessages, agentMessages.providerId);
            await m.addColumn(agentMessages, agentMessages.modelId);

            // 注：当前无旧 AI 对话数据，不需要数据迁移
            // 旧列（content, tool_calls, tool_call_id）保留不删
          }
        },
      );
}

/// 打开 Agent 数据库连接
/// 数据库存放在：BaiShou_Root/.baishou/agent.sqlite
QueryExecutor _openAgentConnection(StoragePathService pathService) {
  return driftDatabase(
    name: 'agent',
    native: DriftNativeOptions(
      databasePath: () async {
        final sysDir = await pathService.getGlobalRegistryDirectory();
        return p.join(sysDir.path, 'agent.sqlite');
      },
    ),
  );
}

/// Riverpod Provider
@Riverpod(keepAlive: true)
AgentDatabase agentDatabase(Ref ref) {
  final pathService = ref.watch(storagePathServiceProvider);
  return AgentDatabase(_openAgentConnection(pathService));
}
