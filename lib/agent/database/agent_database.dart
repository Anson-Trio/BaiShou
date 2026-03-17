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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // 创建 FTS5 虚拟表（drift 不支持声明式定义虚拟表）
          await _createFts5Table();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2: 三表重构
            await m.createTable(agentParts);
            await m.addColumn(agentMessages, agentMessages.isSummary);
            await m.addColumn(agentMessages, agentMessages.providerId);
            await m.addColumn(agentMessages, agentMessages.modelId);
          }
          if (from < 3) {
            // v2 → v3: FTS5 全文搜索索引
            await _createFts5Table();
          }
        },
      );

  /// 创建 FTS5 虚拟表（用于跨会话消息全文搜索）
  Future<void> _createFts5Table() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS agent_messages_fts
      USING fts5(
        message_id UNINDEXED,
        session_id UNINDEXED,
        role UNINDEXED,
        content,
        tokenize='unicode61'
      )
    ''');
  }

  /// 向 FTS5 索引中插入一条记录
  Future<void> insertFtsRecord({
    required String messageId,
    required String sessionId,
    required String role,
    required String content,
  }) async {
    await customStatement(
      'INSERT INTO agent_messages_fts(message_id, session_id, role, content) VALUES (?, ?, ?, ?)',
      [messageId, sessionId, role, content],
    );
  }

  /// 跨会话全文搜索消息
  Future<List<Map<String, dynamic>>> searchFts(
    String query, {
    int limit = 20,
  }) async {
    final results = await customSelect(
      '''
      SELECT
        f.message_id,
        f.session_id,
        f.role,
        snippet(agent_messages_fts, 3, '<b>', '</b>', '...', 48) AS snippet,
        s.title AS session_title,
        s.updated_at AS session_updated_at
      FROM agent_messages_fts AS f
      LEFT JOIN agent_sessions AS s ON f.session_id = s.id
      WHERE agent_messages_fts MATCH ?
      ORDER BY rank
      LIMIT ?
      ''',
      variables: [Variable.withString(query), Variable.withInt(limit)],
    ).get();

    return results.map((row) {
      return {
        'message_id': row.read<String>('message_id'),
        'session_id': row.read<String>('session_id'),
        'role': row.read<String>('role'),
        'snippet': row.read<String>('snippet'),
        'session_title': row.readNullable<String>('session_title') ?? '未命名会话',
        'session_updated_at': row.readNullable<DateTime>('session_updated_at'),
      };
    }).toList();
  }
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
