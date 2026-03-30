/// 记忆去重与语义合并服务
///
/// 在 Agent 存储新记忆前，自动完成去重检测和语义合并：
/// 1. 对新记忆做 embedding，在向量库中做 top-K 相似度检索
/// 2. 根据相似度分三种情况处理：
///    - > duplicateThreshold → 完全重复，跳过
///    - mergeThreshold ~ duplicateThreshold → LLM 判断是否合并
///    - < mergeThreshold → 无相关记忆，直接存入

import 'dart:convert';

import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_deduplication_service.g.dart';

/// 去重动作
enum DeduplicationAction {
  stored, // 直接存入（无相似记忆）
  skipped, // 跳过（完全重复）
  merged, // 语义合并（已删旧插新）
}

/// 去重结果
class DeduplicationResult {
  final DeduplicationAction action;
  final String? mergedContent; // 合并后的文本（仅 merged 时有值）
  final List<String> removedIds; // 被合并删除的旧记忆 messageId
  final double highestSimilarity; // 最高相似度分数（调试用）

  const DeduplicationResult({
    required this.action,
    this.mergedContent,
    this.removedIds = const [],
    this.highestSimilarity = 0.0,
  });

  @override
  String toString() =>
      'DeduplicationResult(action=$action, similarity=$highestSimilarity'
      '${mergedContent != null ? ', merged=${mergedContent!.length}chars' : ''}'
      '${removedIds.isNotEmpty ? ', removed=${removedIds.length}' : ''})';
}

/// 记忆去重与语义合并服务
class MemoryDeduplicationService {
  /// 高于此阈值视为完全重复（跳过存储）
  static const double duplicateThreshold = 0.92;

  /// 高于此阈值进入 LLM 合并判断
  static const double mergeThreshold = 0.70;

  /// 检索候选记忆数量
  static const int _topK = 5;

  final EmbeddingService _embeddingService;
  final AgentDatabase _db;
  final ApiConfigService _apiConfig;

  MemoryDeduplicationService(this._embeddingService, this._db, this._apiConfig);

  /// 在存储新记忆前调用，返回去重/合并结果
  ///
  /// [newMemoryContent] 新记忆的文本内容
  /// [sessionId] 所属会话ID
  ///
  /// 如果 LLM 调用失败，fallback 为直接存储（宁可多存也不丢失记忆）
  Future<DeduplicationResult> checkAndMerge({
    required String newMemoryContent,
    required String sessionId,
    String sourceType = 'chat',
    String? sourceId,
  }) async {
    try {
      return await _doCheckAndMerge(
        newMemoryContent: newMemoryContent,
        sessionId: sessionId,
        sourceType: sourceType,
        sourceId: sourceId,
      );
    } catch (e) {
      debugPrint('MemoryDedup: 去重流程异常，fallback 为直接存储: $e');
      return const DeduplicationResult(action: DeduplicationAction.stored);
    }
  }

  Future<DeduplicationResult> _doCheckAndMerge({
    required String newMemoryContent,
    required String sessionId,
    required String sourceType,
    String? sourceId,
  }) async {
    // 1. 对新记忆做 embedding
    final queryVec = await _embeddingService.embedQuery(newMemoryContent);
    if (queryVec == null || queryVec.isEmpty) {
      debugPrint('MemoryDedup: embedding 生成失败，直接存储');
      return const DeduplicationResult(action: DeduplicationAction.stored);
    }

    // 2. 在向量数据库中做 top-K 相似度检索
    final candidates = await _db.searchSimilar(
      queryEmbedding: queryVec,
      topK: _topK,
    );

    if (candidates.isEmpty) {
      debugPrint('MemoryDedup: 无候选记忆，直接存储');
      return const DeduplicationResult(action: DeduplicationAction.stored);
    }

    // 转换 distance → similarity（cosine distance: similarity = 1 - distance）
    final scored = candidates.map((c) {
      final distance = (c['distance'] as double?) ?? 2.0;
      return _ScoredMemory(
        embeddingId: c['embedding_id'] as String,
        sourceType: c['source_type'] as String,
        sourceId: c['source_id'] as String,
        chunkText: c['chunk_text'] as String,
        createdAt: c['created_at'] as int,
        similarity: 1.0 - distance,
      );
    }).toList();

    final best = scored.first;
    debugPrint(
      'MemoryDedup: 最高相似度=${best.similarity.toStringAsFixed(4)} '
      '(${best.chunkText.length > 50 ? '${best.chunkText.substring(0, 50)}...' : best.chunkText})',
    );

    // 3. 根据相似度分三种情况处理

    // ── 完全重复 ──
    if (best.similarity > duplicateThreshold) {
      debugPrint(
        'MemoryDedup: 完全重复 (${best.similarity.toStringAsFixed(4)}), 跳过存储',
      );
      // 更新已有记忆的时间戳（标记最近被提及）
      await _updateTimestamp(best.embeddingId);
      return DeduplicationResult(
        action: DeduplicationAction.skipped,
        highestSimilarity: best.similarity,
      );
    }

    // ── 语义相关，需 LLM 判断 ──
    if (best.similarity > mergeThreshold) {
      debugPrint(
        'MemoryDedup: 进入 LLM 合并判断 (${best.similarity.toStringAsFixed(4)})',
      );
      // 取所有相似度 > mergeThreshold 的记忆
      final relevantMemories = scored
          .where((s) => s.similarity > mergeThreshold)
          .toList();
      return _llmMergeJudgment(
        newMemoryContent: newMemoryContent,
        sessionId: sessionId,
        candidates: relevantMemories,
        highestSimilarity: best.similarity,
        sourceType: sourceType,
        sourceId: sourceId,
      );
    }

    // ── 无关 ──
    debugPrint(
      'MemoryDedup: 无相关记忆 (${best.similarity.toStringAsFixed(4)}), 直接存储',
    );
    return DeduplicationResult(
      action: DeduplicationAction.stored,
      highestSimilarity: best.similarity,
    );
  }

  /// 调用 LLM 进行语义合并判断
  Future<DeduplicationResult> _llmMergeJudgment({
    required String newMemoryContent,
    required String sessionId,
    required List<_ScoredMemory> candidates,
    required double highestSimilarity,
    required String sourceType,
    String? sourceId,
  }) async {
    try {
      final llmResult = await _callLlmForMerge(newMemoryContent, candidates);
      if (llmResult == null) {
        // LLM 调用失败，fallback 为直接存储
        return DeduplicationResult(
          action: DeduplicationAction.stored,
          highestSimilarity: highestSimilarity,
        );
      }

      switch (llmResult.action) {
        case 'skip':
          debugPrint('MemoryDedup: LLM 判定 skip');
          // 更新最相似记忆的时间戳
          if (candidates.isNotEmpty) {
            await _updateTimestamp(candidates.first.embeddingId);
          }
          return DeduplicationResult(
            action: DeduplicationAction.skipped,
            highestSimilarity: highestSimilarity,
          );

        case 'merge':
          debugPrint(
            'MemoryDedup: LLM 判定 merge, 目标 IDs=${llmResult.mergeTargetIds}',
          );
          final mergedContent = llmResult.mergedContent;
          if (mergedContent.isEmpty) {
            return DeduplicationResult(
              action: DeduplicationAction.stored,
              highestSimilarity: highestSimilarity,
            );
          }

          // 原子操作：删旧 + 插新
          final removedIds = <String>[];
          for (final targetId in llmResult.mergeTargetIds) {
            // 找到对应的 sourceType 和 sourceId 进行删除
            // 使用 firstOrNull 防止 LLM 幻觉伪造 ID 导致误删其他数据
            final target = candidates.where(
              (c) => c.embeddingId == targetId || c.sourceId == targetId
            ).firstOrNull;
            
            if (target != null) {
              await _db.deleteEmbeddingsBySource(
                target.sourceType,
                target.sourceId,
              );
              removedIds.add(target.sourceId);
            } else {
              debugPrint('MemoryDedup: LLM 提供了无效的合并目标 ID: $targetId');
            }
          }

          // 存入合并后的新记忆（embedding_service 会重新 embedding）
          await _embeddingService.embedText(
            text: mergedContent,
            sourceType: sourceType,
            sourceId:
                sourceId ?? 'mem_${DateTime.now().millisecondsSinceEpoch}',
            groupId: sessionId,
          );

          return DeduplicationResult(
            action: DeduplicationAction.merged,
            mergedContent: mergedContent,
            removedIds: removedIds,
            highestSimilarity: highestSimilarity,
          );

        case 'new':
        default:
          debugPrint('MemoryDedup: LLM 判定 new');
          return DeduplicationResult(
            action: DeduplicationAction.stored,
            highestSimilarity: highestSimilarity,
          );
      }
    } catch (e) {
      debugPrint('MemoryDedup: LLM 合并判断失败，fallback 为直接存储: $e');
      return DeduplicationResult(
        action: DeduplicationAction.stored,
        highestSimilarity: highestSimilarity,
      );
    }
  }

  /// 调用 LLM 判断合并
  Future<_LlmMergeResult?> _callLlmForMerge(
    String newMemory,
    List<_ScoredMemory> existingMemories,
  ) async {
    // 获取用于合并判断的 LLM provider
    final providerId = _apiConfig.globalDialogueProviderId;
    final modelId = _apiConfig.globalDialogueModelId;
    if (providerId.isEmpty || modelId.isEmpty) return null;

    final provider = _apiConfig.getProvider(providerId);
    if (provider == null) return null;

    final client = AiClientFactory.createClient(provider);

    // 构建 prompt
    final existingBlock = existingMemories
        .map(
          (m) =>
              '- [ID: ${m.embeddingId}] ${m.chunkText}'
              '（记录于 ${DateTime.fromMillisecondsSinceEpoch(m.createdAt).toIso8601String()}）',
        )
        .join('\n');

    final prompt =
        '''你是AI记忆管理器。请判断新记忆是否应与已有记忆合并。

## 已有记忆
$existingBlock

## 新记忆
$newMemory

## 规则
1. 如果新记忆和某条已有记忆表达的是完全相同的事实，输出 "skip"
2. 如果新记忆是对已有记忆的补充、修正或更新，输出 "merge"，并提供合并后的完整记忆文本
3. 如果新记忆是全新的信息，只是主题相关但内容不同，输出 "new"

## 输出格式（严格JSON，不要markdown代码块）
{"action": "merge" | "new" | "skip", "merge_target_ids": [], "merged_content": ""}''';

    try {
      final response = await client.generateContent(
        prompt: prompt,
        modelId: modelId,
      );

      return _parseLlmResponse(response);
    } catch (e) {
      debugPrint('MemoryDedup: LLM 调用失败: $e');
      return null;
    }
  }

  /// 解析 LLM JSON 响应
  _LlmMergeResult? _parseLlmResponse(String response) {
    try {
      // 提取 JSON（LLM 可能会包在代码块中）
      String jsonStr = response.trim();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final action = json['action'] as String? ?? 'new';
      final mergeTargetIds =
          (json['merge_target_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final mergedContent = json['merged_content'] as String? ?? '';

      return _LlmMergeResult(
        action: action,
        mergeTargetIds: mergeTargetIds,
        mergedContent: mergedContent,
      );
    } catch (e) {
      debugPrint('MemoryDedup: LLM 响应解析失败: $e');
      return null;
    }
  }

  /// 更新已有记忆的时间戳
  Future<void> _updateTimestamp(String embeddingId) async {
    try {
      await _db.customStatement(
        'UPDATE memory_embeddings SET created_at = ? WHERE embedding_id = ?',
        [DateTime.now().millisecondsSinceEpoch, embeddingId],
      );
    } catch (e) {
      debugPrint('MemoryDedup: 更新时间戳失败: $e');
    }
  }
}

/// 内部模型：相似度打分的记忆条目
class _ScoredMemory {
  final String embeddingId;
  final String sourceType;
  final String sourceId;
  final String chunkText;
  final int createdAt;
  final double similarity;

  const _ScoredMemory({
    required this.embeddingId,
    required this.sourceType,
    required this.sourceId,
    required this.chunkText,
    required this.createdAt,
    required this.similarity,
  });
}

/// 内部模型：LLM 合并判断结果
class _LlmMergeResult {
  final String action; // "merge" | "new" | "skip"
  final List<String> mergeTargetIds;
  final String mergedContent;

  const _LlmMergeResult({
    required this.action,
    this.mergeTargetIds = const [],
    this.mergedContent = '',
  });
}

@Riverpod(keepAlive: true)
MemoryDeduplicationService memoryDeduplicationService(Ref ref) {
  return MemoryDeduplicationService(
    ref.read(embeddingServiceProvider),
    ref.read(agentDatabaseProvider),
    ref.read(apiConfigServiceProvider),
  );
}
