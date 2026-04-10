// Embedding 嵌入服务
//
// 职责：
// 1. 从 ApiConfigService 获取用户配置的嵌入模型和供应商
// 2. 调用 AiClient.generateEmbedding 获取向量
// 3. 文本分块（chunk）后逐块嵌入
// 4. 存入 AgentDatabase

import 'dart:math';

import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:baishou/agent/rag/embedding_models.dart';

part 'embedding_service.g.dart';

/// 嵌入服务
class EmbeddingService {
  static const int _maxChunkLength = 1024; // 字符数
  static const int _chunkOverlap = 128;

  final ApiConfigService _apiConfig;
  final AgentDatabase _db;
  bool _isMigrating = false;

  EmbeddingService(this._apiConfig, this._db);

  /// 检查用户是否配置了嵌入模型
  bool get isConfigured {
    final embeddingModelId = _apiConfig.globalEmbeddingModelId;
    final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;
    return embeddingModelId.isNotEmpty && embeddingProviderId.isNotEmpty;
  }

  /// 自动检测嵌入模型的向量维度
  ///
  /// 检测结果缓存到 SharedPreferences，避免重复调用。
  Future<int> detectDimension() async {
    if (!isConfigured) return 0;

    final cachedDimension = _apiConfig.globalEmbeddingDimension;
    if (cachedDimension > 0) return cachedDimension;

    try {
      final embeddingModelId = _apiConfig.globalEmbeddingModelId;
      final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;
      final provider = _apiConfig.getProvider(embeddingProviderId);
      if (provider == null) return 0;

      final client = AiClientFactory.createClient(provider);
      final testEmbedding = await client.generateEmbedding(
        input: 'hi',
        modelId: embeddingModelId,
      );
      final dimension = testEmbedding.length;
      await _apiConfig.setGlobalEmbeddingDimension(dimension);
      debugPrint('EmbeddingService: 检测到维度 $dimension ($embeddingModelId)');
      return dimension;
    } catch (e) {
      debugPrint('EmbeddingService: 维度检测失败: $e');
      return 0;
    }
  }

  /// 发送极简心跳探针，不缓存，直接测活
  Future<bool> testConnection() async {
    if (!isConfigured) return false;

    try {
      final embeddingModelId = _apiConfig.globalEmbeddingModelId;
      final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;
      final provider = _apiConfig.getProvider(embeddingProviderId);
      if (provider == null) return false;

      final client = AiClientFactory.createClient(provider);
      await client.generateEmbedding(
        input: 'hi',
        modelId: embeddingModelId,
      );
      return true;
    } catch (e) {
      debugPrint('EmbeddingService: 网络探针连接失败: $e');
      return false;
    }
  }

  /// 嵌入一条消息并存入数据库
  Future<void> embedMessage({
    required String messageId,
    required String sessionId,
    required String content,
  }) async {
    if (!isConfigured) return;
    if (content.trim().isEmpty) return;

    try {
      final embeddingModelId = _apiConfig.globalEmbeddingModelId;
      final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;

      final provider = _apiConfig.getProvider(embeddingProviderId);
      if (provider == null) return;

      final client = AiClientFactory.createClient(provider);
      final uuid = const Uuid();

      // 首次嵌入前自动检测维度
      final currentDimension = await detectDimension();

      // 初始化向量索引
      if (currentDimension > 0) {
        await _db.initVectorIndex(currentDimension);
      }

      // 文本分块
      final chunks = _splitIntoChunks(content);

      // 逐块嵌入并存储（带重试）
      for (final chunk in chunks) {
        await _retryEmbed(() async {
          final embedding = await client.generateEmbedding(
            input: chunk.text,
            modelId: embeddingModelId,
          );

          await _db.insertEmbedding(
            id: uuid.v4(),
            sourceType: 'chat',
            sourceId: messageId,
            groupId: sessionId,
            chunkIndex: chunk.index,
            chunkText: chunk.text,
            embedding: _normalize(embedding),
            modelId: embeddingModelId,
          );
        }, label: 'embedMessage chunk ${chunk.index}');
      }
    } catch (e) {
      debugPrint('Embedding failed: $e');
    }
  }

  /// 生成查询向量（不存库，仅用于搜索）
  Future<List<double>?> embedQuery(String query) async {
    if (!isConfigured) return null;

    try {
      final embeddingModelId = _apiConfig.globalEmbeddingModelId;
      final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;

      final provider = _apiConfig.getProvider(embeddingProviderId);
      if (provider == null) return null;

      final client = AiClientFactory.createClient(provider);
      final raw = await client.generateEmbedding(
        input: query,
        modelId: embeddingModelId,
      );
      return _normalize(raw);
    } catch (e) {
      debugPrint('Query embedding failed: $e');
      return null;
    }
  }

  // ── Phase 3: 单条记忆管理 ─────────────────────────────────

  /// 编辑一条指定的记忆记录（重新生成嵌入并覆盖保存）
  Future<void> updateMemoryChunk({
    required Map<String, dynamic> entry,
    required String newText,
  }) async {
    if (!isConfigured || newText.trim().isEmpty) return;

    final embeddingModelId = _apiConfig.globalEmbeddingModelId;
    final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;
    final provider = _apiConfig.getProvider(embeddingProviderId);
    if (provider == null) return;

    final client = AiClientFactory.createClient(provider);

    await _retryEmbed(() async {
      final embedding = await client.generateEmbedding(
        input: newText,
        modelId: embeddingModelId,
      );

      await _db.insertEmbedding(
        id: entry['embedding_id'] as String,
        sourceType: entry['source_type'] as String,
        sourceId: entry['source_id'] as String,
        groupId: entry['group_id'] as String,
        chunkIndex: entry['chunk_index'] as int,
        chunkText: newText,
        metadataJson: entry['metadata_json'] as String? ?? '{}',
        embedding: _normalize(embedding),
        modelId: embeddingModelId,
      );
    }, label: 'updateMemoryChunk ${entry['embedding_id']}');
  }

  /// 嵌入一段独立文本并存入数据库
  ///
  /// 用于 Agent 主动存储记忆（memory_store_tool），
  /// 不依赖消息上下文。
  Future<void> embedText({
    required String text,
    required String sourceType,
    required String sourceId,
    required String groupId,
    String metadataJson = '{}',
    int? sourceCreatedAt,
    String? chunkPrefix,
  }) async {
    if (!isConfigured || text.trim().isEmpty) return;

    final embeddingModelId = _apiConfig.globalEmbeddingModelId;
    final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;
    final provider = _apiConfig.getProvider(embeddingProviderId);
    if (provider == null) return;

    final client = AiClientFactory.createClient(provider);
    final uuid = const Uuid();
    final chunks = _splitIntoChunks(text);

    // 首次嵌入前自动检测维度并初始化向量索引
    final currentDimension = await detectDimension();
    if (currentDimension > 0) {
      await _db.initVectorIndex(currentDimension);
    }

    // 并发度 3 嵌入所有 chunk
    final futures = <Future<void>>[];
    for (final chunk in chunks) {
      final embeddingInput = chunkPrefix != null
          ? '$chunkPrefix${chunk.text}'
          : chunk.text;
      final future = _retryEmbed(() async {
        final embedding = await client.generateEmbedding(
          input: embeddingInput,
          modelId: embeddingModelId,
        );
        await _db.insertEmbedding(
          id: uuid.v4(),
          sourceType: sourceType,
          sourceId: sourceId,
          groupId: groupId,
          chunkIndex: chunk.index,
          chunkText: embeddingInput,
          metadataJson: metadataJson,
          embedding: _normalize(embedding),
          modelId: embeddingModelId,
          sourceCreatedAt: sourceCreatedAt,
        );
      }, label: 'embedText chunk ${chunk.index}');

      futures.add(future);

      // 每积攒 3 个并发任务就等待它们全部完成
      if (futures.length >= 3) {
        await Future.wait(futures);
        futures.clear();
      }
    }
    // 处理剩余不足 3 个的任务
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// 重新嵌入一段独立文本（先删除旧的，再重新生成并插入）
  Future<void> reEmbedText({
    required String text,
    required String sourceType,
    required String sourceId,
    required String groupId,
    String metadataJson = '{}',
    int? sourceCreatedAt,
    String? chunkPrefix,
  }) async {
    await _db.deleteEmbeddingsBySource(sourceType, sourceId);
    await embedText(
      text: text,
      sourceType: sourceType,
      sourceId: sourceId,
      groupId: groupId,
      metadataJson: metadataJson,
      sourceCreatedAt: sourceCreatedAt,
      chunkPrefix: chunkPrefix,
    );
  }

  /// 重新嵌入某条消息（删旧 + 重新生成）
  Future<void> reEmbedMessage({
    required String messageId,
    required String sessionId,
    required String content,
  }) async {
    await _db.deleteEmbeddingsBySource('chat', messageId);
    await embedMessage(
      messageId: messageId,
      sessionId: sessionId,
      content: content,
    );
  }

  /// 清空全部嵌入数据
  Future<void> clearAllEmbeddings() async {
    await _db.clearEmbeddings();
    // 同时清除维度缓存
    await _apiConfig.setGlobalEmbeddingDimension(0);
  }

  // ── 嵌入模型迁移（备份表方案） ─────────────────────────────

  /// 检查是否有未完成的迁移（启动时调用）
  Future<bool> hasPendingMigration() => _db.hasPendingMigration();

  /// 检查当前工作区的 RAG 是否与全局设定模型不一致
  Future<bool> hasHeterogeneousEmbeddings() async {
    final String currentGlobalModelId = _apiConfig.globalEmbeddingModelId;
    if (currentGlobalModelId.isEmpty) return false;
    final int count = await _db.countHeterogeneousEmbeddings(
      currentGlobalModelId,
    );
    return count > 0;
  }

  /// 安全迁移嵌入模型（备份 → 清空 → 重嵌入 → 校验 → 清理备份）
  ///
  /// 流程：
  /// 1. 创建 _embedding_migration_backup 保存所有 chunk 元数据
  /// 2. 原子清空 message_embeddings + 用新维度重建索引
  /// 3. 逐条从 backup 读取 chunk_text，用新模型嵌入并写入
  /// 4. 每条完成后标记 migrated = 1
  /// 5. 全部完成后校验完整性
  /// 6. 校验通过 → DROP backup
  Stream<MigrationProgress> migrateEmbeddings() async* {
    if (_isMigrating) {
      yield MigrationProgress(total: 0, completed: 0, status: '已经有迁移任务在运行');
      return;
    }
    _isMigrating = true;
    try {
      if (!isConfigured) {
        yield MigrationProgress(total: 0, completed: 0, status: '嵌入模型未配置');
        return;
      }

      final embeddingModelId = _apiConfig.globalEmbeddingModelId;
      final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;
      final provider = _apiConfig.getProvider(embeddingProviderId);
      if (provider == null) {
        yield MigrationProgress(total: 0, completed: 0, status: '供应商未找到');
        return;
      }

      final client = AiClientFactory.createClient(provider);

      // ── 步骤 1: 创建备份表 ──
      yield MigrationProgress(total: 0, completed: 0, status: '正在备份元数据...');
      final total = await _db.createMigrationBackup();

      if (total == 0) {
        await _db.dropMigrationBackup();
        yield MigrationProgress(total: 0, completed: 0, status: '没有需要迁移的数据');
        return;
      }

      // ── 步骤 2: 检测新维度 + 清空 + 重建索引（原子操作） ──
      yield MigrationProgress(
        total: total,
        completed: 0,
        status: '正在检测新模型维度...',
      );
      final newDimension = await _detectDimensionWithClient(
        client,
        embeddingModelId,
      );
      if (newDimension <= 0) {
        yield MigrationProgress(
          total: total,
          completed: 0,
          status: '新模型维度检测失败，迁移中止',
        );
        return;
      }
      await _db.clearAndReinitEmbeddings(newDimension);
      await _apiConfig.setGlobalEmbeddingDimension(newDimension);

      // ── 步骤 3-4: 逐条重嵌入 ──
      yield* _doReEmbedFromBackup(client, embeddingModelId, total);
    } finally {
      _isMigrating = false;
    }
  }

  /// 继续未完成的迁移（崩溃恢复）
  Stream<MigrationProgress> continueMigration() async* {
    if (_isMigrating) {
      yield MigrationProgress(total: 0, completed: 0, status: '已经有迁移任务在运行');
      return;
    }
    _isMigrating = true;
    try {
      if (!isConfigured) {
        yield MigrationProgress(total: 0, completed: 0, status: '嵌入模型未配置');
        return;
      }

      final embeddingModelId = _apiConfig.globalEmbeddingModelId;
      final embeddingProviderId = _apiConfig.globalEmbeddingProviderId;
      final provider = _apiConfig.getProvider(embeddingProviderId);
      if (provider == null) {
        yield MigrationProgress(total: 0, completed: 0, status: '供应商未找到');
        return;
      }

      final client = AiClientFactory.createClient(provider);
      final remaining = await _db.getUnmigratedCount();

      if (remaining == 0) {
        // 上次其实已完成，直接清理
        await _db.dropMigrationBackup();
        yield MigrationProgress(total: 0, completed: 0, status: '迁移已完成');
        return;
      }

      yield* _doReEmbedFromBackup(client, embeddingModelId, remaining);
    } finally {
      _isMigrating = false;
    }
  }

  /// 逐条从备份表重嵌入（共用逻辑）
  Stream<MigrationProgress> _doReEmbedFromBackup(
    dynamic client,
    String embeddingModelId,
    int total,
  ) async* {
    yield MigrationProgress(total: total, completed: 0, status: '开始重嵌入...');

    final chunks = await _db.getUnmigratedBackupChunks();
    int completed = 0;
    int failed = 0;

    for (final chunk in chunks) {
      try {
        await _retryEmbed(() async {
          final embedding = await client.generateEmbedding(
            input: chunk['chunk_text'] as String,
            modelId: embeddingModelId,
          );

          await _db.insertEmbedding(
            id: chunk['embedding_id'] as String,
            sourceType: chunk['source_type'] as String,
            sourceId: chunk['source_id'] as String,
            groupId: chunk['group_id'] as String,
            chunkIndex: chunk['chunk_index'] as int,
            chunkText: chunk['chunk_text'] as String,
            metadataJson: chunk['metadata_json'] as String,
            embedding: _normalize(embedding),
            modelId: embeddingModelId,
            sourceCreatedAt: chunk['source_created_at'] as int?,
          );

          // 标记这条 chunk 迁移完成
          await _db.markBackupChunkMigrated(chunk['embedding_id'] as String);
        }, label: 'migrate chunk ${chunk['embedding_id']}');
        completed++;
      } catch (e) {
        failed++;
        debugPrint('Migration failed for chunk ${chunk['embedding_id']}: $e');
      }

      yield MigrationProgress(
        total: total,
        completed: completed,
        failed: failed,
        status: '迁移中 $completed/$total${failed > 0 ? ' (失败 $failed)' : ''}',
      );
    }

    // ── 步骤 5: 校验完整性 ──
    final (allMigrated, noStale) = await _db.verifyMigrationComplete(
      embeddingModelId,
    );

    if (allMigrated && noStale) {
      // ── 步骤 6: 校验通过，清理备份 ──
      await _db.dropMigrationBackup();
      yield MigrationProgress(
        total: total,
        completed: completed,
        failed: failed,
        status: '迁移完成 ✅ $completed/$total',
      );
    } else {
      yield MigrationProgress(
        total: total,
        completed: completed,
        failed: failed,
        status:
            '迁移完成但校验未通过 ⚠️'
            '${!allMigrated ? ' (部分 chunk 未迁移)' : ''}'
            '${!noStale ? ' (存在旧模型数据)' : ''}',
      );
    }
  }

  /// 用指定 client 检测维度（不缓存）
  Future<int> _detectDimensionWithClient(dynamic client, String modelId) async {
    try {
      final testEmbedding = await client.generateEmbedding(
        input: 'hi',
        modelId: modelId,
      );
      return testEmbedding.length;
    } catch (e) {
      debugPrint('Dimension detection failed: $e');
      return 0;
    }
  }

  /// 文本分块：按字符长度滑窗切分
  List<ChunkResult> _splitIntoChunks(String text) {
    if (text.length <= _maxChunkLength) {
      return [ChunkResult(index: 0, text: text)];
    }

    final chunks = <ChunkResult>[];
    int start = 0;
    int index = 0;

    while (start < text.length) {
      int end = start + _maxChunkLength;
      if (end > text.length) end = text.length;

      chunks.add(ChunkResult(index: index, text: text.substring(start, end)));

      if (end >= text.length) break;

      start = end - _chunkOverlap;
      if (start >= text.length) break;
      index++;
    }

    return chunks;
  }

  /// 重试包装器：遇到网络波动时自动重试（最多 3 次，指数退避）
  Future<void> _retryEmbed(
    Future<void> Function() action, {
    String label = '',
    int maxAttempts = 3,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await action();
        return;
      } catch (e) {
        if (attempt < maxAttempts) {
          final delay = Duration(seconds: attempt); // 1s, 2s
          debugPrint(
            '$label 失败 (attempt $attempt/$maxAttempts), '
            '${delay.inSeconds}s 后重试: $e',
          );
          await Future.delayed(delay);
        } else {
          debugPrint('$label 失败 (已耗尽重试): $e');
          throw Exception('Failed to generate embedding: $e');
        }
      }
    }
  }

  /// L2 归一化：将向量缩放为单位向量
  ///
  /// 归一化后 L2 距离范围变为 [0, 2]，语义相似的向量距离接近 0。
  List<double> _normalize(List<double> vec) {
    double norm = 0;
    for (final v in vec) norm += v * v;
    norm = sqrt(norm);
    debugPrint('_normalize: dim=${vec.length}, norm_before=$norm');
    if (norm == 0) return vec;
    final result = vec.map((v) => v / norm).toList();
    // 验证归一化后的 norm ≈ 1.0
    double check = 0;
    for (final v in result) check += v * v;
    debugPrint('_normalize: norm_after=${sqrt(check)}');
    return result;
  }
}

/// EmbeddingService Provider
@riverpod
EmbeddingService embeddingService(Ref ref) {
  return EmbeddingService(
    ref.read(apiConfigServiceProvider),
    ref.read(agentDatabaseProvider),
  );
}
