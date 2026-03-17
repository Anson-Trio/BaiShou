// Embedding 嵌入服务
//
// 职责：
// 1. 从 ApiConfigService 获取用户配置的嵌入模型和供应商
// 2. 调用 AiClient.generateEmbedding 获取向量
// 3. 文本分块（chunk）后逐块嵌入
// 4. 存入 AgentDatabase

import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'embedding_service.g.dart';

/// 文本分块策略
class ChunkResult {
  final int index;
  final String text;
  ChunkResult({required this.index, required this.text});
}

/// 嵌入服务
class EmbeddingService {
  static const int _maxChunkLength = 512; // 字符数
  static const int _chunkOverlap = 64;

  final Ref _ref;

  EmbeddingService(this._ref);

  /// 检查用户是否配置了嵌入模型
  bool get isConfigured {
    final service = _ref.read(apiConfigServiceProvider);
    final embeddingModelId = service.globalEmbeddingModelId;
    final embeddingProviderId = service.globalEmbeddingProviderId;
    return embeddingModelId.isNotEmpty && embeddingProviderId.isNotEmpty;
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
      final service = _ref.read(apiConfigServiceProvider);
      final embeddingModelId = service.globalEmbeddingModelId;
      final embeddingProviderId = service.globalEmbeddingProviderId;

      final provider = service.getProvider(embeddingProviderId);
      if (provider == null) return;

      final client = AiClientFactory.createClient(provider);
      final db = _ref.read(agentDatabaseProvider);
      final uuid = const Uuid();

      // 文本分块
      final chunks = _splitIntoChunks(content);

      // 逐块嵌入并存储
      for (final chunk in chunks) {
        try {
          final embedding = await client.generateEmbedding(
            input: chunk.text,
            modelId: embeddingModelId,
          );

          await db.insertEmbedding(
            id: uuid.v4(),
            messageId: messageId,
            sessionId: sessionId,
            chunkIndex: chunk.index,
            chunkText: chunk.text,
            embedding: embedding,
          );
        } catch (e) {
          debugPrint('Failed to embed chunk ${chunk.index}: $e');
        }
      }
    } catch (e) {
      debugPrint('Embedding failed: $e');
    }
  }

  /// 生成查询向量（不存库，仅用于搜索）
  Future<List<double>?> embedQuery(String query) async {
    if (!isConfigured) return null;

    try {
      final service = _ref.read(apiConfigServiceProvider);
      final embeddingModelId = service.globalEmbeddingModelId;
      final embeddingProviderId = service.globalEmbeddingProviderId;

      final provider = service.getProvider(embeddingProviderId);
      if (provider == null) return null;

      final client = AiClientFactory.createClient(provider);
      return await client.generateEmbedding(
        input: query,
        modelId: embeddingModelId,
      );
    } catch (e) {
      debugPrint('Query embedding failed: $e');
      return null;
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
      start = end - _chunkOverlap;
      if (start >= text.length) break;
      index++;
    }

    return chunks;
  }
}

/// EmbeddingService Provider
@riverpod
EmbeddingService embeddingService(Ref ref) {
  return EmbeddingService(ref);
}
