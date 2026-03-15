import 'package:baishou/agent/database/agent_tables.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_database.g.dart';

/// Agent 专属数据库
/// 独立于主数据库（app_database），存储 Agent 的会话和消息历史
@DriftDatabase(tables: [AgentSessions, AgentMessages])
class AgentDatabase extends _$AgentDatabase {
  AgentDatabase(super.executor);

  @override
  int get schemaVersion => 1;
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
