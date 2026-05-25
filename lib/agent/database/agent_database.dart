import 'dart:convert';
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
import 'package:baishou/core/storage/vault_service.dart';

part 'agent_database.g.dart';

/// Agent 专属数据库
/// 独立于主数据库（app_database），存储 Agent 的会话、消息和 Part
/// 集成 sqlite-vec 原生向量搜索扩展
@DriftDatabase(
  tables: [
    AgentSessions,
    AgentMessages,
    AgentParts,
    AgentAssistants,
    CompressionSnapshots,
  ],
)
class AgentDatabase extends _$AgentDatabase {
  AgentDatabase(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createFts5Table();
      await _createEmbeddingTable();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 → v2: 创建压缩快照表
        await m.createTable(compressionSnapshots);
      }
      if (from < 3) {
        // v2 → v3: AgentMessages 新增 token/cost 列
        await m.addColumn(agentMessages, agentMessages.inputTokens);
        await m.addColumn(agentMessages, agentMessages.outputTokens);
        await m.addColumn(agentMessages, agentMessages.costMicros);
      }
      if (from < 4) {
        // v3 → v4: AgentAssistants 新增压缩保留轮数字段
        await m.addColumn(agentAssistants, agentAssistants.compressKeepTurns);
      }
      if (from < 5) {
        // v4 → v5: AgentAssistants 新增拖动排序字段
        await m.addColumn(agentAssistants, agentAssistants.sortOrder);
      }
      if (from < 6) {
        // v5 → v6: 迁移 message_embeddings 到 memory_embeddings
        await customStatement('''
              CREATE TABLE IF NOT EXISTS memory_embeddings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                embedding_id TEXT NOT NULL UNIQUE,
                source_type TEXT NOT NULL,
                source_id TEXT NOT NULL,
                group_id TEXT NOT NULL,
                chunk_index INTEGER NOT NULL DEFAULT 0,
                chunk_text TEXT NOT NULL,
                metadata_json TEXT NOT NULL DEFAULT '{}',
                embedding BLOB NOT NULL,
                dimension INTEGER NOT NULL,
                model_id TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL
              )
            ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_memory_group ON memory_embeddings(group_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_memory_source ON memory_embeddings(source_type, source_id)',
        );

        // 迁移旧数据
        await customStatement('''
              INSERT INTO memory_embeddings (
                embedding_id, source_type, source_id, group_id, 
                chunk_index, chunk_text, metadata_json, embedding, 
                dimension, model_id, created_at
              )
              SELECT 
                embedding_id, 
                CASE WHEN message_id LIKE 'diary_%' THEN 'diary' ELSE 'chat' END,
                CASE WHEN message_id LIKE 'diary_%' THEN SUBSTR(message_id, 7) ELSE message_id END,
                session_id, chunk_index, chunk_text, '{}', embedding, dimension, model_id, created_at
              FROM message_embeddings
            ''');
        await customStatement('DROP TABLE IF EXISTS message_embeddings');
      }
      if (from < 7) {
        // v6 → v7: 新增 source_created_at 列，分离"嵌入生成时间"和"源内容真实时间"
        await customStatement(
          'ALTER TABLE memory_embeddings ADD COLUMN source_created_at INTEGER',
        );
        // 回填：将 created_at 作为默认的 source_created_at
        await customStatement(
          'UPDATE memory_embeddings SET source_created_at = created_at WHERE source_created_at IS NULL',
        );
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
    // FTS5 短语搜索：用双引号包裹整段查询，内部的单引号等字符都安全
    // 只需要将查询中已有的双引号转义（替换为空格）即可
    final cleaned = query.replaceAll('"', ' ').trim();
    if (cleaned.isEmpty) return [];

    try {
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
        variables: [Variable.withString('"$cleaned"'), Variable.withInt(limit)],
      ).get();

      return results.map((row) {
        return {
          'message_id': row.read<String>('message_id'),
          'session_id': row.read<String>('session_id'),
          'role': row.read<String>('role'),
          'snippet': row.read<String>('snippet'),
          'session_title':
              row.readNullable<String>('session_title') ??
              t.agent.sessions.unnamed_session,
          'session_updated_at': row.readNullable<DateTime>('session_updated_at'),
        };
      }).toList();
    } catch (e) {
      debugPrint('searchFts failed for query "$cleaned": $e');
      return [];
    }
  }

  // ── 原生 sqlite-vector 向量搜索 ────────────────────────────────

  /// 创建向量嵌入表 + 初始化向量索引
  Future<void> _createEmbeddingTable() async {
    // 元数据表：存储 chunk 文本和关联信息
    await customStatement('''
      CREATE TABLE IF NOT EXISTS memory_embeddings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        embedding_id TEXT NOT NULL UNIQUE,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        group_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL DEFAULT 0,
        chunk_text TEXT NOT NULL,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        embedding BLOB NOT NULL,
        dimension INTEGER NOT NULL,
        model_id TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        source_created_at INTEGER
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_memory_group
      ON memory_embeddings(group_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_memory_source
      ON memory_embeddings(source_type, source_id)
    ''');
  }

  /// 初始化向量索引（每个连接都需要调用，首次插入时自动触发）
  ///
  /// 根据 sqlite-vector API，`vector_init` 必须在每个需要执行向量操作的数据库连接中调用。
  Future<void> initVectorIndex(int dimension) async {
    try {
      await customStatement(
        "SELECT vector_init('memory_embeddings', 'embedding', "
        "'type=FLOAT32,dimension=$dimension,distance=COSINE')",
      );
      debugPrint(
        'sqlite-vector: vector index initialized (dim=$dimension, distance=COSINE)',
      );
    } catch (e) {
      // 索引已被其它维度锁定或已存在时忽略，交由上层读写阶段去捕获异常降级处理
      debugPrint('sqlite-vector: vector_init skipped: $e');
    }
  }

  /// 插入向量嵌入（兼容华为等不支持 sqlite-vec 原生扩展的设备）
  Future<void> insertEmbedding({
    required String id,
    required String sourceType,
    required String sourceId,
    required String groupId,
    required int chunkIndex,
    required String chunkText,
    String metadataJson = '{}',
    required List<double> embedding,
    required String modelId,
    int? sourceCreatedAt,
  }) async {
    // 直接在 Dart 中生成 32-bit 小端序浮点数组，绕过对 vector_as_f32() 的依赖
    // 该字节格式与 sqlite-vec 完全一致，原生索引也可以完美挂载
    final floatList = Float32List.fromList(embedding);
    final blob = floatList.buffer.asUint8List();
    
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await customStatement(
        '''INSERT OR REPLACE INTO memory_embeddings
           (embedding_id, source_type, source_id, group_id, chunk_index, chunk_text,
            metadata_json, embedding, dimension, model_id, created_at, source_created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          id,
          sourceType,
          sourceId,
          groupId,
          chunkIndex,
          chunkText,
          metadataJson,
          blob,
          embedding.length,
          modelId,
          now,
          sourceCreatedAt ?? now,
        ],
      );
    } catch (e) {
      debugPrint('sqlite-vector: insertEmbedding failed (likely dimension locked): $e');
    }
  }

  /// 原生 KNN 向量搜索 — 使用 sqlite-vector 的 vector_full_scan
  ///
  /// 使用 `vector_full_scan` 虚拟表做暴力 KNN 搜索（SIMD 加速）。
  /// [dimension] 用于确保 vector_init 的维度匹配。
  Future<List<Map<String, dynamic>>> searchSimilar({
    required List<double> queryEmbedding,
    int topK = 20,
    int? dimension,
  }) async {
    final vectorJson = '[${queryEmbedding.join(',')}]';
    final effectiveDimension = dimension ?? queryEmbedding.length;

    debugPrint(
      'searchSimilar: queryLen=${queryEmbedding.length}, '
      'dim=$effectiveDimension, topK=$topK',
    );

    try {
      // 确保当前连接已初始化向量索引（vector_init 必须在每个连接中调用）
      await initVectorIndex(effectiveDimension);

      // 使用 vector_full_scan 虚拟表做 KNN 搜索，然后 JOIN 回原表获取元数据
      final results = await customSelect(
        '''
        SELECT
          e.embedding_id,
          e.source_type,
          e.source_id,
          e.group_id,
          e.chunk_index,
          e.chunk_text,
          e.metadata_json,
          e.dimension,
          e.model_id,
          v.distance,
          e.created_at,
          e.source_created_at
        FROM vector_full_scan('memory_embeddings', 'embedding', vector_as_f32(?), ?) AS v
        JOIN memory_embeddings AS e ON e.id = v.rowid
        WHERE e.dimension = ?
        ''',
        variables: [
          Variable.withString(vectorJson),
          Variable.withInt(topK),
          Variable.withInt(effectiveDimension),
        ],
      ).get();

      debugPrint('searchSimilar: got ${results.length} results');

      return results.map((row) {
        return {
          'embedding_id': row.read<String>('embedding_id'),
          'source_type': row.read<String>('source_type'),
          'source_id': row.read<String>('source_id'),
          'group_id': row.read<String>('group_id'),
          'chunk_index': row.read<int>('chunk_index'),
          'chunk_text': row.read<String>('chunk_text'),
          'metadata_json': row.read<String>('metadata_json'),
          'dimension': row.read<int>('dimension'),
          'model_id': row.read<String>('model_id'),
          'distance': row.read<double>('distance'),
          'created_at': row.read<int>('created_at'),
        };
      }).toList();
    } catch (e) {
      debugPrint('searchSimilar vector_full_scan failed: $e. Using Dart Fallback...');
      
      // ---------- 纯 Dart 退避降级方案 ----------
      try {
        final allRows = await customSelect(
          '''
          SELECT
            embedding_id, source_type, source_id, group_id, chunk_index,
            chunk_text, metadata_json, dimension, model_id, embedding,
            created_at, source_created_at
          FROM memory_embeddings
          WHERE dimension = ?
          ''',
          variables: [Variable.withInt(effectiveDimension)],
        ).get();

        final resultsWithScore = <Map<String, dynamic>>[];
        for (final row in allRows) {
          final blob = row.read<Uint8List>('embedding');
          final floatList = Float32List.view(blob.buffer);
          
          if (floatList.length != effectiveDimension) continue;

          // 计算余弦相似度并转换为 sqlite-vec 兼容的 COSINE Distance: (1.0 - CosSimilarity)
          double dot = 0.0, normA = 0.0, normB = 0.0;
          for (int i = 0; i < effectiveDimension; i++) {
            dot += queryEmbedding[i] * floatList[i];
            normA += queryEmbedding[i] * queryEmbedding[i];
            normB += floatList[i] * floatList[i];
          }
          
          double distance = 1.0;
          if (normA != 0 && normB != 0) {
            distance = 1.0 - (dot / (sqrt(normA) * sqrt(normB)));
          }

          resultsWithScore.add({
            'embedding_id': row.read<String>('embedding_id'),
            'source_type': row.read<String>('source_type'),
            'source_id': row.read<String>('source_id'),
            'group_id': row.read<String>('group_id'),
            'chunk_index': row.read<int>('chunk_index'),
            'chunk_text': row.read<String>('chunk_text'),
            'metadata_json': row.read<String>('metadata_json'),
            'dimension': row.read<int>('dimension'),
            'model_id': row.read<String>('model_id'),
            'distance': distance,
            'created_at': row.read<int>('created_at'),
          });
        }
        
        // 按距离从小到大排序（0 为完全相同）
        resultsWithScore.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        
        final finalResults = resultsWithScore.take(topK).toList();
        debugPrint('searchSimilar (Dart Fallback): got ${finalResults.length} results');
        return finalResults;
      } catch (fallbackErr) {
        debugPrint('searchSimilar Dart Fallback failed: $fallbackErr');
        return [];
      }
    }
  }

  // ── 嵌入模型迁移（备份表方案） ─────────────────────────────

  /// 检查是否存在未完成的迁移（启动时调用）
  Future<bool> hasPendingMigration() async {
    final result = await customSelect(
      "SELECT COUNT(*) AS cnt FROM sqlite_master "
      "WHERE type='table' AND name='_embedding_migration_backup'",
    ).getSingle();
    return result.read<int>('cnt') > 0;
  }

  /// 检查是否存在与其他模型关联的旧嵌入记录（异构）
  Future<int> countHeterogeneousEmbeddings(String currentGlobalModelId) async {
    final result = await customSelect(
      "SELECT COUNT(*) as c FROM memory_embeddings WHERE model_id != ? AND model_id != ''",
      variables: [Variable.withString(currentGlobalModelId)],
    ).getSingle();
    return result.read<int>('c');
  }

  /// 创建迁移备份表，复制元数据（不含向量 BLOB）
  Future<int> createMigrationBackup() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS _embedding_migration_backup (
        embedding_id  TEXT NOT NULL,
        source_type   TEXT NOT NULL,
        source_id     TEXT NOT NULL,
        group_id      TEXT NOT NULL,
        chunk_index   INTEGER NOT NULL,
        chunk_text    TEXT NOT NULL,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        old_model_id  TEXT NOT NULL,
        old_dimension INTEGER NOT NULL,
        migrated      INTEGER NOT NULL DEFAULT 0,
        created_at    INTEGER NOT NULL,
        source_created_at INTEGER
      )
    ''');
    await customStatement('''
      INSERT INTO _embedding_migration_backup
        (embedding_id, source_type, source_id, group_id, chunk_index, chunk_text,
         metadata_json, old_model_id, old_dimension, migrated, created_at, source_created_at)
      SELECT embedding_id, source_type, source_id, group_id, chunk_index, chunk_text,
             metadata_json, model_id, dimension, 0, created_at, source_created_at
      FROM memory_embeddings
    ''');
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM _embedding_migration_backup',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// 清空向量表 + 用新维度重建索引（原子操作）
  Future<void> clearAndReinitEmbeddings(int newDimension) async {
    // 强制 DROP 表来彻底切断 sqlite-vec 在旧内存表上对原维度的硬锁定
    await customStatement('DROP TABLE IF EXISTS memory_embeddings');
    await _createEmbeddingTable();
    
    if (newDimension > 0) {
      await initVectorIndex(newDimension);
    }
  }

  /// 获取未迁移的备份 chunk 列表
  Future<List<Map<String, dynamic>>> getUnmigratedBackupChunks() async {
    final results = await customSelect('''
      SELECT embedding_id, source_type, source_id, group_id, chunk_index, chunk_text, metadata_json, source_created_at
      FROM _embedding_migration_backup
      WHERE migrated = 0
      ORDER BY created_at, chunk_index
    ''').get();
    return results
        .map(
          (row) => {
            'embedding_id': row.read<String>('embedding_id'),
            'source_type': row.read<String>('source_type'),
            'source_id': row.read<String>('source_id'),
            'group_id': row.read<String>('group_id'),
            'chunk_index': row.read<int>('chunk_index'),
            'chunk_text': row.read<String>('chunk_text'),
            'metadata_json': row.read<String>('metadata_json'),
            'source_created_at': row.readNullable<int>('source_created_at'),
          },
        )
        .toList();
  }

  /// 标记某条 chunk 迁移完成
  Future<void> markBackupChunkMigrated(String embeddingId) async {
    await customStatement(
      'UPDATE _embedding_migration_backup SET migrated = 1 WHERE embedding_id = ?',
      [embeddingId],
    );
  }

  /// 校验迁移完整性
  /// 返回 (allMigrated, noStaleData)
  Future<(bool, bool)> verifyMigrationComplete(String newModelId) async {
    final unmigrated = await customSelect(
      'SELECT COUNT(*) AS cnt FROM _embedding_migration_backup WHERE migrated = 0',
    ).getSingle();
    final stale = await customSelect(
      'SELECT COUNT(*) AS cnt FROM memory_embeddings WHERE model_id != ?',
      variables: [Variable.withString(newModelId)],
    ).getSingle();
    return (unmigrated.read<int>('cnt') == 0, stale.read<int>('cnt') == 0);
  }

  /// 删除迁移备份表（校验通过后调用）
  Future<void> dropMigrationBackup() async {
    await customStatement('DROP TABLE IF EXISTS _embedding_migration_backup');
  }

  /// 获取未迁移的 chunk 数量
  Future<int> getUnmigratedCount() async {
    try {
      final result = await customSelect(
        'SELECT COUNT(*) AS cnt FROM _embedding_migration_backup WHERE migrated = 0',
      ).getSingle();
      return result.read<int>('cnt');
    } catch (_) {
      return 0;
    }
  }

  /// 根据唯一匹配来源信息删除相应的嵌入碎片
  Future<void> deleteEmbeddingsBySource(
    String sourceType,
    String sourceId,
  ) async {
    await customStatement(
      'DELETE FROM memory_embeddings WHERE source_type = ? AND source_id = ?',
      [sourceType, sourceId],
    );
  }

  /// 根据嵌入 ID 删除单条嵌入
  Future<void> deleteEmbeddingById(String embeddingId) async {
    await customStatement(
      'DELETE FROM memory_embeddings WHERE embedding_id = ?',
      [embeddingId],
    );
  }

  /// 获取当前嵌入总数
  Future<int> getEmbeddingCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM memory_embeddings',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// 清空全部向量嵌入
  Future<void> clearEmbeddings() async {
    await customStatement('DELETE FROM memory_embeddings');
  }

  /// 清空特定维度的向量嵌入
  Future<int> clearEmbeddingsByDimension(int dimension) async {
    final count = await customSelect(
      'SELECT COUNT(*) AS cnt FROM memory_embeddings WHERE dimension = ?',
      variables: [Variable.withInt(dimension)],
    ).getSingle();
    final deleted = count.read<int>('cnt');
    await customStatement('DELETE FROM memory_embeddings WHERE dimension = ?', [
      dimension,
    ]);
    return deleted;
  }

  /// 获取某种特换类型的嵌入实体集合映射表
  /// Returns: Map<String, String> => { sourceId : metadataJson }
  Future<Map<String, String>> getEmbeddedSourceMetadataByType(
    String sourceType,
  ) async {
    final results = await customSelect(
      'SELECT DISTINCT source_id, metadata_json FROM memory_embeddings WHERE source_type = ?',
      variables: [Variable.withString(sourceType)],
    ).get();
    return {
      for (final row in results)
        row.read<String>('source_id'): row.read<String>('metadata_json'),
    };
  }

  /// 获取嵌入统计信息
  Future<Map<String, dynamic>> getEmbeddingStats() async {
    final result = await customSelect('''
      SELECT
        COUNT(*) AS total_count,
        COUNT(DISTINCT model_id) AS model_count,
        COUNT(DISTINCT dimension) AS dimension_count
      FROM memory_embeddings
    ''').getSingle();

    // 获取当前使用的模型详情
    final models = await customSelect('''
      SELECT model_id, dimension, COUNT(*) AS count
      FROM memory_embeddings
      GROUP BY model_id, dimension
    ''').get();

    return {
      'total_count': result.read<int>('total_count'),
      'model_count': result.read<int>('model_count'),
      'dimension_count': result.read<int>('dimension_count'),
      'models': models
          .map(
            (row) => {
              'model_id': row.read<String>('model_id'),
              'dimension': row.read<int>('dimension'),
              'count': row.read<int>('count'),
            },
          )
          .toList(),
    };
  }

  /// 获取所有已嵌入的 chunk（用于迁移重嵌入）
  ///
  /// 返回每条 chunk 的 id、source_id、group_id、chunk_index、chunk_text。
  Future<List<Map<String, dynamic>>> getAllEmbeddingChunks() async {
    final results = await customSelect('''
      SELECT embedding_id, source_type, source_id, group_id, chunk_index, chunk_text,
             model_id, dimension, created_at, metadata_json
      FROM memory_embeddings
      ORDER BY created_at DESC, chunk_index
    ''').get();

    return results.map((row) {
      return {
        'embedding_id': row.read<String>('embedding_id'),
        'source_type': row.read<String>('source_type'),
        'source_id': row.read<String>('source_id'),
        'group_id': row.read<String>('group_id'),
        'chunk_index': row.read<int>('chunk_index'),
        'chunk_text': row.read<String>('chunk_text'),
        'metadata_json': row.read<String>('metadata_json'),
        'model_id': row.read<String>('model_id'),
        'dimension': row.read<int>('dimension'),
        'created_at': row.read<int>('created_at'),
      };
    }).toList();
  }

  // ── 数据导出与恢复支持 ───────────────────────────────────

  /// 导入前全量清空所有 Agent 数据
  Future<void> clearAllAgentData() async {
    await transaction(() async {
      await delete(agentParts).go();
      await delete(agentMessages).go();
      await delete(agentSessions).go();
      await delete(agentAssistants).go();
      await delete(compressionSnapshots).go();

      await customStatement('DELETE FROM memory_embeddings');
      await customStatement('DELETE FROM agent_messages_fts');
    });
  }

  /// 获取全量嵌入数据（包含 BLOB 的二进制片段），专用于 ZIP 导出序列化
  Future<List<Map<String, dynamic>>> getAllEmbeddingsForExport() async {
    final results = await customSelect('''
      SELECT *
      FROM memory_embeddings
    ''').get();

    return results.map((row) {
      return {
        'id': row.read<int>('id'),
        'embedding_id': row.read<String>('embedding_id'),
        'source_type': row.read<String>('source_type'),
        'source_id': row.read<String>('source_id'),
        'group_id': row.read<String>('group_id'),
        'chunk_index': row.read<int>('chunk_index'),
        'chunk_text': row.read<String>('chunk_text'),
        'metadata_json': row.read<String>('metadata_json'),
        'dimension': row.read<int>('dimension'),
        'model_id': row.read<String>('model_id'),
        'created_at': row.read<int>('created_at'),
        'source_created_at': row.readNullable<int>('source_created_at'),
        // 取出原生 BLOB 供外部 Base64 编码
        'embedding': row.read<Uint8List>('embedding'),
      };
    }).toList();
  }

  /// 从导入数据的原生 BLOB 恢复嵌入
  Future<void> importEmbeddingsRaw(
    List<Map<String, dynamic>> embeddings,
  ) async {
    await transaction(() async {
      // 在原生插入时由于使用 (?, ?) 语法，Uint8List 会自动由 drift 绑定为 sqlite3 BLOB
      final stmt =
          'INSERT INTO memory_embeddings '
          '(id, embedding_id, source_type, source_id, group_id, chunk_index, chunk_text, '
          'metadata_json, embedding, dimension, model_id, created_at, source_created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

      for (final e in embeddings) {
        await customStatement(stmt, [
          e['id'],
          e['embedding_id'],
          e['source_type'],
          e['source_id'],
          e['group_id'],
          e['chunk_index'], e['chunk_text'], e['metadata_json'],
          e['embedding'], // Uint8List
          e['dimension'], e['model_id'], e['created_at'],
          e['source_created_at'],
        ]);
      }
    });
  }

  /// 导入后全量重建 FTS 全文索引
  Future<void> rebuildFtsIndex() async {
    await transaction(() async {
      await customStatement('DELETE FROM agent_messages_fts');

      // 获取用户与助手的所有有效消息
      final messages = await (select(
        agentMessages,
      )..where((t) => t.role.isIn(['user', 'assistant']))).get();

      if (messages.isEmpty) return;

      // 取出文本类 Part 用于提取字符串
      final parts = await (select(
        agentParts,
      )..where((t) => t.type.equals('text'))).get();

      final partsByMsg = <String, String>{};
      for (final p in parts) {
        try {
          final data = jsonDecode(p.data) as Map<String, dynamic>;
          final text = data['text'] as String? ?? '';
          if (text.isNotEmpty) {
            final existing = partsByMsg[p.messageId] ?? '';
            partsByMsg[p.messageId] = existing + text;
          }
        } catch (_) {}
      }

      // 将拼装好的纯文本写入 FTS 虚表
      for (final msg in messages) {
        final text = partsByMsg[msg.id];
        if (text != null && text.trim().isNotEmpty) {
          await insertFtsRecord(
            messageId: msg.id,
            sessionId: msg.sessionId,
            role: msg.role,
            content: text,
          );
        }
      }
    });
  }
}

/// 打开 Agent 数据库连接
/// 使用 NativeDatabase + LazyDatabase，注入 sqlite-vec 扩展
QueryExecutor _openAgentConnection(
  StoragePathService pathService,
  String workspace,
) {
  return LazyDatabase(() async {
    final sysDir = await pathService.getVaultSystemDirectory(workspace);
    final dbFile = File(p.join(sysDir.path, 'agent.sqlite'));
    return NativeDatabase.createInBackground(
      dbFile,
      isolateSetup: () {
        // 必须在数据库打开前注册 auto-extension
        // setup 回调在 DB 打开后执行，已注册的 auto-extension 不会应用到当前连接
        try {
          sql.sqlite3.loadSqliteVectorExtension();
        } catch (e) {
          // 向量扩展在部分设备上可能不可用（如某些华为 HarmonyOS 设备的 linker 限制）
          // 降级处理：伙伴基础 CRUD 正常，仅 RAG 向量搜索不可用
          // ignore: avoid_print
          print('[AgentDB] sqlite-vec extension load failed: $e');
        }
      },
    );
  });
}

/// 缓存所有工作区的 AgentDatabase 实例，避免切换工作区时旧实例被提前关闭
/// 从而导致旧工作区后台仍处于活跃状态的任务（如生成对话标题、计算 token）因连接断开而失败。
final Map<String, AgentDatabase> _dbCache = {};

/// 清除并关闭指定工作区的数据库缓存（用于工作区永久删除时释放文件句柄）
void closeAgentDatabaseCache(String vaultName) {
  final db = _dbCache.remove(vaultName);
  db?.close();
}

/// 强制关闭全量数据库连接，专用于覆盖式的物理数据恢复
Future<void> closeAllAgentDatabases() async {
  for (final db in _dbCache.values) {
    await db.close();
  }
  _dbCache.clear();
}

/// Riverpod Provider
@Riverpod(keepAlive: true)
AgentDatabase agentDatabase(Ref ref) {
  final pathService = ref.watch(storagePathServiceProvider);
  final vaultName = ref.watch(activeVaultNameProvider) ?? 'Personal';

  // drift 的 close() 是异步操作，在同步 Provider 中无法 await，
  // 并且我们需要保持旧数据库实例连接开启，以应对旧工作区中尚未完结的网络请求。
  // vault 切换意味着多库共存，这是明确的设计需求，因此安全抑制警告。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  if (_dbCache.containsKey(vaultName)) {
    // LRU: 重新放入以将其移至 LinkedHashMap 迭代顺序的末尾
    final db = _dbCache.remove(vaultName)!;
    _dbCache[vaultName] = db;
  } else {
    // 限制最大缓存容量，防止 200+ 工作空间打开过多连接导致句柄耗尽崩溃
    const maxCacheSize = 5;
    if (_dbCache.length >= maxCacheSize) {
      final oldestVault = _dbCache.keys.first;
      final oldestDb = _dbCache.remove(oldestVault);
      oldestDb?.close();
      // ignore: avoid_print
      print('[AgentDB] LRU cache evicted and closed database connection for: $oldestVault');
    }

    final db = AgentDatabase(_openAgentConnection(pathService, vaultName));
    _dbCache[vaultName] = db;
  }

  return _dbCache[vaultName]!;
}
