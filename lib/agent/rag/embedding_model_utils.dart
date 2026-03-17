// Embedding 模型识别工具
// 参考 cherry-studio: src/renderer/src/config/models/embedding.ts
//
// 通过正则匹配模型名来判断该模型是否为 Embedding（向量嵌入）模型，
// 用于在 UI 层过滤：对话/总结/命名选择器排除 Embedding 模型，
// Embedding 选择器只显示 Embedding 模型。

/// 匹配常见的 Embedding 模型名称模式
final RegExp _embeddingRegex = RegExp(
  r'(?:^text-embedding|embed|bge-|e5-|retrieval|uae-|gte-|jina-embeddings|voyage-|nomic-embed)',
  caseSensitive: false,
);

/// 匹配 Rerank 模型（排除在 Embedding 之外）
final RegExp _rerankRegex = RegExp(
  r'(?:rerank|re-rank|re-ranker|re-ranking)',
  caseSensitive: false,
);

/// 判断给定的模型 ID 是否为 Embedding 模型
bool isEmbeddingModel(String modelId) {
  // Rerank 模型不算 Embedding
  if (_rerankRegex.hasMatch(modelId)) return false;
  return _embeddingRegex.hasMatch(modelId);
}

/// 判断给定的模型 ID 是否为 Rerank 模型
bool isRerankModel(String modelId) {
  return _rerankRegex.hasMatch(modelId);
}
