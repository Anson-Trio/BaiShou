import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:baishou/agent/database/agent_tables.dart';
import 'package:baishou/i18n/strings.g.dart';
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts5Table();
          await _createEmbeddingTable();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(agentSessions, agentSessions.isPinned);
            await m.addColumn(agentSessions, agentSessions.systemPrompt);
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
        'session_title': row.readNullable<String>('session_title') ?? t.agent.sessions.unnamed_session,
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
        model_id TEXT NOT NULL DEFAULT '',
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
    required String modelId,
  }) async {
    // 将 List<double> 转为 JSON 数组字符串，供 vector_as_f32() 解析
    final vectorJson = '[${embedding.join(',')}]';

    await customStatement(
      '''INSERT OR REPLACE INTO message_embeddings
         (embedding_id, message_id, session_id, chunk_index, chunk_text,
          embedding, dimension, model_id, created_at)
         VALUES (?, ?, ?, ?, ?, vector_as_f32(?), ?, ?, ?)''',
      [
        id,
        messageId,
        sessionId,
        chunkIndex,
        chunkText,
        vectorJson,
        embedding.length,
        modelId,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// 原生 KNN 向量搜索 — 使用 sqlite-vec 的 vector_full_scan
  ///
  /// 使用 sqlite-vec 的 vec_distance_cosine() 在 SQL 层计算余弦距离（SIMD 加速）。
  /// [dimension] 用于过滤维度不匹配的向量，防止跨模型搜索出错。
  Future<List<Map<String, dynamic>>> searchSimilar({
    required List<double> queryEmbedding,
    int topK = 20,
    int? dimension,
  }) async {
    final vectorJson = '[${queryEmbedding.join(',')}]';
    final effectiveDimension = dimension ?? queryEmbedding.length;

    debugPrint('searchSimilar: queryLen=${queryEmbedding.length}, '
        'dim=$effectiveDimension, topK=$topK');

    try {
      // 使用 vec_distance_cosine 在 SQL 层计算余弦距离
      final results = await customSelect(
        '''
        SELECT
          e.embedding_id,
          e.message_id,
          e.session_id,
          e.chunk_index,
          e.chunk_text,
          e.dimension,
          e.model_id,
          vec_distance_cosine(e.embedding, vector_as_f32(?)) AS distance,
          s.title AS session_title
        FROM message_embeddings AS e
        LEFT JOIN agent_sessions AS s ON e.session_id = s.id
        WHERE e.dimension = ?
        ORDER BY distance ASC
        LIMIT ?
        ''',
        variables: [
          Variable.withString(vectorJson),
          Variable.withInt(effectiveDimension),
          Variable.withInt(topK),
        ],
      ).get();

      debugPrint('searchSimilar: got ${results.length} results, '
          'best distance=${results.isNotEmpty ? results.first.read<double>('distance') : 'N/A'}');

      return results.map((row) {
        return {
          'embedding_id': row.read<String>('embedding_id'),
          'message_id': row.read<String>('message_id'),
          'session_id': row.read<String>('session_id'),
          'chunk_index': row.read<int>('chunk_index'),
          'chunk_text': row.read<String>('chunk_text'),
          'dimension': row.read<int>('dimension'),
          'model_id': row.read<String>('model_id'),
          'distance': row.read<double>('distance'),
          'session_title':
              row.readNullable<String>('session_title') ?? t.agent.sessions.unnamed_session,
        };
      }).toList();
    } catch (e) {
      debugPrint('searchSimilar vec_distance_cosine failed: $e');
      // 回退到 Dart 侧计算
      return _dartCosineSearch(queryEmbedding, effectiveDimension, topK);
    }
  }

  /// Dart 侧余弦相似度搜索（回退方案）
  Future<List<Map<String, dynamic>>> _dartCosineSearch(
    List<double> queryEmbedding,
    int dimension,
    int topK,
  ) async {
    debugPrint('_dartCosineSearch: using Dart-side cosine similarity');
    final rows = await customSelect(
      '''SELECT e.*, s.title AS session_title
         FROM message_embeddings AS e
         LEFT JOIN agent_sessions AS s ON e.session_id = s.id
         WHERE e.dimension = ?''',
      variables: [Variable.withInt(dimension)],
    ).get();

    if (rows.isEmpty) return [];

    final scored = <Map<String, dynamic>>[];
    final queryNorm = _vecNorm(queryEmbedding);

    for (final row in rows) {
      try {
        final blob = row.read<Uint8List>('embedding');
        final stored = _blobToFloats(blob);
        if (stored.length != queryEmbedding.length) continue;

        final dot = _vecDot(queryEmbedding, stored);
        final storedNorm = _vecNorm(stored);
        final cosine = (queryNorm > 0 && storedNorm > 0)
            ? dot / (queryNorm * storedNorm)
            : 0.0;

        scored.add({
          'embedding_id': row.read<String>('embedding_id'),
          'message_id': row.read<String>('message_id'),
          'session_id': row.read<String>('session_id'),
          'chunk_index': row.read<int>('chunk_index'),
          'chunk_text': row.read<String>('chunk_text'),
          'dimension': row.read<int>('dimension'),
          'model_id': row.read<String>('model_id'),
          'distance': 1.0 - cosine,
          'session_title':
              row.readNullable<String>('session_title') ?? t.agent.sessions.unnamed_session,
        });
      } catch (e) {
        // skip corrupt entries
      }
    }

    scored.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    return scored.take(topK).toList();
  }

  // 向量工具函数
  double _vecDot(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) sum += a[i] * b[i];
    return sum;
  }

  double _vecNorm(List<double> v) {
    double sum = 0;
    for (final x in v) sum += x * x;
    return sqrt(sum);
  }

  List<double> _blobToFloats(Uint8List blob) {
    final byteData = ByteData.sublistView(blob);
    final count = blob.length ~/ 4; // float32 = 4 bytes
    return List.generate(count, (i) => byteData.getFloat32(i * 4, Endian.little));
  }

  /// 删除某条消息的所有嵌入
  Future<void> deleteEmbeddingsByMessage(String messageId) async {
    await customStatement(
      'DELETE FROM message_embeddings WHERE message_id = ?',
      [messageId],
    );
  }

  /// 根据嵌入 ID 删除单条嵌入
  Future<void> deleteEmbeddingById(String embeddingId) async {
    await customStatement(
      'DELETE FROM message_embeddings WHERE embedding_id = ?',
      [embeddingId],
    );
  }

  /// 获取当前嵌入总数
  Future<int> getEmbeddingCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM message_embeddings',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// 清空全部向量嵌入
  Future<void> clearEmbeddings() async {
    await customStatement('DELETE FROM message_embeddings');
  }

  /// 清空特定维度的向量嵌入
  Future<int> clearEmbeddingsByDimension(int dimension) async {
    final count = await customSelect(
      'SELECT COUNT(*) AS cnt FROM message_embeddings WHERE dimension = ?',
      variables: [Variable.withInt(dimension)],
    ).getSingle();
    final deleted = count.read<int>('cnt');
    await customStatement(
      'DELETE FROM message_embeddings WHERE dimension = ?',
      [dimension],
    );
    return deleted;
  }

  /// 获取嵌入统计信息
  Future<Map<String, dynamic>> getEmbeddingStats() async {
    final result = await customSelect('''
      SELECT
        COUNT(*) AS total_count,
        COUNT(DISTINCT model_id) AS model_count,
        COUNT(DISTINCT dimension) AS dimension_count
      FROM message_embeddings
    ''').getSingle();

    // 获取当前使用的模型详情
    final models = await customSelect('''
      SELECT model_id, dimension, COUNT(*) AS count
      FROM message_embeddings
      GROUP BY model_id, dimension
    ''').get();

    return {
      'total_count': result.read<int>('total_count'),
      'model_count': result.read<int>('model_count'),
      'dimension_count': result.read<int>('dimension_count'),
      'models': models.map((row) => {
        'model_id': row.read<String>('model_id'),
        'dimension': row.read<int>('dimension'),
        'count': row.read<int>('count'),
      }).toList(),
    };
  }

  /// 获取所有已嵌入的 chunk（用于迁移重嵌入）
  ///
  /// 返回每条 chunk 的 id、message_id、session_id、chunk_index、chunk_text。
  Future<List<Map<String, dynamic>>> getAllEmbeddingChunks() async {
    final results = await customSelect('''
      SELECT embedding_id, message_id, session_id, chunk_index, chunk_text,
             model_id, dimension, created_at
      FROM message_embeddings
      ORDER BY created_at DESC, chunk_index
    ''').get();

    return results.map((row) {
      return {
        'embedding_id': row.read<String>('embedding_id'),
        'message_id': row.read<String>('message_id'),
        'session_id': row.read<String>('session_id'),
        'chunk_index': row.read<int>('chunk_index'),
        'chunk_text': row.read<String>('chunk_text'),
        'model_id': row.read<String>('model_id'),
        'dimension': row.read<int>('dimension'),
        'created_at': row.read<int>('created_at'),
      };
    }).toList();
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
