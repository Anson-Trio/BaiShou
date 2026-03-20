// 混合搜索 — 合并 FTS5（关键词）和向量（语义）检索结果
//
// 使用 RRF (Reciprocal Rank Fusion) 算法融合两路排序，
// 返回最终的混合排序结果。

import 'dart:math';

/// 搜索结果统一模型
class SearchResult {
  final String messageId;
  final String sessionId;
  final String chunkText;
  final String sessionTitle;
  final double score;
  final String source; // 'fts' | 'vector' | 'hybrid'
  final DateTime? createdAt;

  const SearchResult({
    required this.messageId,
    required this.sessionId,
    required this.chunkText,
    required this.sessionTitle,
    required this.score,
    required this.source,
    this.createdAt,
  });
}

/// 混合搜索引擎
class HybridSearch {
  /// RRF 常数 k（经典值 60）
  static const int _rrfK = 60;

  /// 合并 FTS5 和向量搜索结果
  ///
  /// [ftsResults] — 来自 FTS5 的按 rank 排序结果
  /// [vectorResults] — 来自向量相似度排序结果
  /// [limit] — 返回数量上限
  /// [ftsWeight] — FTS 权重（默认 0.3）
  /// [vectorWeight] — 向量权重（默认 0.7）
  static List<SearchResult> merge({
    required List<SearchResult> ftsResults,
    required List<SearchResult> vectorResults,
    int limit = 10,
    double ftsWeight = 0.3,
    double vectorWeight = 0.7,
  }) {
    final scoreMap = <String, _MergedScore>{};

    // FTS RRF 分数（FTS 没有有意义的分数，用 RRF 排名分数）
    for (int i = 0; i < ftsResults.length; i++) {
      final r = ftsResults[i];
      final key = '${r.messageId}:${r.sessionId}';
      final rrfScore = ftsWeight / (i + _rrfK);
      scoreMap.putIfAbsent(key, () => _MergedScore(result: r));
      scoreMap[key]!.ftsScore = rrfScore;
    }

    // Vector 分数：使用原始余弦相似度 × 权重
    for (int i = 0; i < vectorResults.length; i++) {
      final r = vectorResults[i];
      final key = '${r.messageId}:${r.sessionId}';
      scoreMap.putIfAbsent(key, () => _MergedScore(result: r));
      scoreMap[key]!.vectorScore = r.score * vectorWeight;
      scoreMap[key]!.rawVectorScore = r.score; // 保留原始分数
    }

    // 合并排序
    final merged = scoreMap.values.toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return merged
        .take(min(limit, merged.length))
        .map((m) => SearchResult(
              messageId: m.result.messageId,
              sessionId: m.result.sessionId,
              chunkText: m.result.chunkText,
              sessionTitle: m.result.sessionTitle,
              // 混合结果用blended分数，纯向量结果用原始余弦分数
              score: m.rawVectorScore > 0 ? m.rawVectorScore : m.totalScore,
              source: m.source,
              createdAt: m.result.createdAt,
            ))
        .toList();
  }

  /// 纯向量搜索：余弦相似度 KNN
  ///
  /// [queryEmbedding] — 查询向量
  /// [allEmbeddings] — 数据库中的所有向量
  /// [topK] — 返回前 K 个
  static List<SearchResult> vectorSearch({
    required List<double> queryEmbedding,
    required List<Map<String, dynamic>> allEmbeddings,
    int topK = 20,
  }) {
    final scored = <_ScoredEmbedding>[];

    for (final row in allEmbeddings) {
      final docEmbedding = row['embedding'] as List<double>;
      if (docEmbedding.length != queryEmbedding.length) continue;

      final sim = _cosineSimilarity(queryEmbedding, docEmbedding);
      scored.add(_ScoredEmbedding(row: row, score: sim));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored
        .take(min(topK, scored.length))
        .map((s) => SearchResult(
              messageId: s.row['message_id'] as String,
              sessionId: s.row['session_id'] as String,
              chunkText: s.row['chunk_text'] as String,
              sessionTitle: s.row['session_title'] as String,
              score: s.score,
              source: 'vector',
            ))
        .toList();
  }

  /// 余弦相似度
  static double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    if (denom == 0) return 0;
    return dot / denom;
  }
}

class _MergedScore {
  final SearchResult result;
  double ftsScore = 0;
  double vectorScore = 0;
  double rawVectorScore = 0; // 原始余弦相似度（未加权）

  _MergedScore({required this.result});

  double get totalScore => ftsScore + vectorScore;

  String get source {
    if (ftsScore > 0 && vectorScore > 0) return 'hybrid';
    if (ftsScore > 0) return 'fts';
    return 'vector';
  }
}

class _ScoredEmbedding {
  final Map<String, dynamic> row;
  final double score;
  _ScoredEmbedding({required this.row, required this.score});
}
