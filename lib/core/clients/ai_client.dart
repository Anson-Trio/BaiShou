import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:baishou/core/clients/openai_client.dart';
import 'package:baishou/core/clients/gemini_client.dart';
import 'package:baishou/core/clients/anthropic_client.dart';

/// AI 客户端的基础接口 (Strategy 模式)
abstract class AiClient {
  /// 生成完整的对话或内容
  Future<String> generateContent({
    required String prompt,
    required String modelId,
  });

  /// 获取此服务商当前可用的所有模型列表
  Future<List<String>> fetchAvailableModels();

  /// 测试服务商的连接连通性
  Future<void> testConnection();
}

/// AI 客户端工厂 (Simple Factory 模式)
class AiClientFactory {
  /// 根据提供的 [provider] 创建并挂载对应的专属 API Client
  static AiClient createClient(AiProviderModel provider) {
    if (provider.apiKey.isEmpty) {
      throw Exception('未填写 API Key，无法进行有效操作。');
    }

    // 如果没有配置 baseUrl 且非特定支持空Url的供应商，可在此处做通用拦截
    // Gemini 允许为空（因为自带官方默认路径）

    switch (provider.type) {
      case ProviderType.gemini:
        return GeminiClient(provider: provider);
      case ProviderType.anthropic:
        return AnthropicClient(provider: provider);
      default:
        // OpenAI 标准协议族 (OpenAI, DeepSeek, Kimi, GLM等)
        return OpenAiClient(provider: provider);
    }
  }
}
