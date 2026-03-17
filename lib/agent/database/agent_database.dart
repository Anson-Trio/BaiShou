import 'dart:io';

import 'package:baishou/agent/database/agent_tables.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:sqlite_vector/sqlite_vector.dart';

part 'agent_database.g.dart';

/// Agent 专属数据库
/// 独立于主数据库（app_database），存储 Agent 的会话、消息和 Part
/// 集成 sqlite-vec 原生向量搜索扩展
@DriftDatabase(tables: [AgentSessions, AgentMessages, AgentParts])
class AgentDatabase extends _$AgentDatabase {
  AgentDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts5Table();
          await _createEmbeddingTable();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(agentParts);
            await m.addColumn(agentMessages, agentMessages.isSummary);
            await m.addColumn(agentMessages, agentMessages.providerId);
            await m.addColumn(agentMessages, agentMessages.modelId);
          }
          if (from < 3) {
            await _createFts5Table();
          }
          if (from < 4) {
            await _createEmbeddingTable();
          }
        },
      );

  // ── FTS5 全文搜索 ──────────────────────────────────────────

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

  // ── 原生 sqlite-vec 向量搜索 ────────────────────────────────

  /// 创建向量嵌入表 + 初始化向量索引
  Future<void> _createEmbeddingTable() async {
    // 元数据表：存储 chunk 文本和关联信息
    await customStatement('''
      CREATE TABLE IF NOT EXISTS message_embeddings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        embedding_id TEXT NOT NULL UNIQUE,
        message_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL DEFAULT 0,
        chunk_text TEXT NOT NULL,
        embedding BLOB NOT NULL,
        dimension INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_embeddings_session
      ON message_embeddings(session_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_embeddings_message
      ON message_embeddings(message_id)
    ''');
  }

  /// 初始化向量索引（首次插入时调用，需要知道维度）
  Future<void> initVectorIndex(int dimension) async {
    try {
      await customStatement(
        "SELECT vector_init('message_embeddings', 'embedding', "
        "'type=FLOAT32,dimension=$dimension')",
      );
      debugPrint('sqlite-vec: vector index initialized (dim=$dimension)');
    } catch (e) {
      // 索引已存在或 sqlite-vec 未加载时忽略
      debugPrint('sqlite-vec: vector_init skipped: $e');
    }
  }

  /// 使用原生 vector_as_f32 插入向量嵌入
  Future<void> insertEmbedding({
    required String id,
    required String messageId,
    required String sessionId,
    required int chunkIndex,
    required String chunkText,
    required List<double> embedding,
  }) async {
    // 将 List<double> 转为 JSON 数组字符串，供 vector_as_f32() 解析
    final vectorJson = '[${embedding.join(',')}]';

    await customStatement(
      '''INSERT OR REPLACE INTO message_embeddings
         (embedding_id, message_id, session_id, chunk_index, chunk_text,
          embedding, dimension, created_at)
         VALUES (?, ?, ?, ?, ?, vector_as_f32(?), ?, ?)''',
      [
        id,
        messageId,
        sessionId,
        chunkIndex,
        chunkText,
        vectorJson,
        embedding.length,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// 原生 KNN 向量搜索 — 使用 sqlite-vec 的 vector_full_scan
  ///
  /// 在 SQL 层直接用 SIMD 加速计算最近邻，比 Dart 侧全量扫描快数量级。
  Future<List<Map<String, dynamic>>> searchSimilar({
    required List<double> queryEmbedding,
    int topK = 20,
  }) async {
    final vectorJson = '[${queryEmbedding.join(',')}]';

    final results = await customSelect(
      '''
      SELECT
        e.embedding_id,
        e.message_id,
        e.session_id,
        e.chunk_index,
        e.chunk_text,
        e.dimension,
        v.distance,
        s.title AS session_title
      FROM message_embeddings AS e
      JOIN vector_full_scan(
        'message_embeddings', 'embedding',
        vector_as_f32(?), ?
      ) AS v ON e.id = v.rowid
      LEFT JOIN agent_sessions AS s ON e.session_id = s.id
      ''',
      variables: [Variable.withString(vectorJson), Variable.withInt(topK)],
    ).get();

    return results.map((row) {
      return {
        'embedding_id': row.read<String>('embedding_id'),
        'message_id': row.read<String>('message_id'),
        'session_id': row.read<String>('session_id'),
        'chunk_index': row.read<int>('chunk_index'),
        'chunk_text': row.read<String>('chunk_text'),
        'distance': row.read<double>('distance'),
        'session_title':
            row.readNullable<String>('session_title') ?? '未命名会话',
      };
    }).toList();
  }

  /// 删除某条消息的所有嵌入
  Future<void> deleteEmbeddingsByMessage(String messageId) async {
    await customStatement(
      'DELETE FROM message_embeddings WHERE message_id = ?',
      [messageId],
    );
  }

  /// 获取当前嵌入总数
  Future<int> getEmbeddingCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM message_embeddings',
    ).getSingle();
    return result.read<int>('cnt');
  }
}

/// 加载 sqlite-vec 扩展并返回 sqlite3 实例
sql.Sqlite3 _loadExtensions() {
  sql.sqlite3.loadSqliteVectorExtension();
  return sql.sqlite3;
}

/// 打开 Agent 数据库连接
/// 使用 NativeDatabase + LazyDatabase，注入 sqlite-vec 扩展
QueryExecutor _openAgentConnection(StoragePathService pathService) {
  return LazyDatabase(() async {
    final sysDir = await pathService.getGlobalRegistryDirectory();
    final dbFile = File(p.join(sysDir.path, 'agent.sqlite'));
    return NativeDatabase.createInBackground(
      dbFile,
      sqlite3: _loadExtensions,
    );
  });
}

/// Riverpod Provider
@Riverpod(keepAlive: true)
AgentDatabase agentDatabase(Ref ref) {
  final pathService = ref.watch(storagePathServiceProvider);
  return AgentDatabase(_openAgentConnection(pathService));
}
