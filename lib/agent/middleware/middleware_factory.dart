import 'package:baishou/agent/middleware/gemini_thought_signature.dart';
import 'package:baishou/agent/middleware/message_middleware.dart';
import 'package:baishou/agent/models/ai_provider_model.dart';

/// 中间件工厂 — 根据 Provider 类型自动组装中间件链
///
/// 所有中间件的注册和管理都集中在这里。
/// Client 无需直接 import 具体的中间件类，只需通过此工厂获取。
///
/// 新增中间件时：
/// 1. 在 `lib/agent/middleware/` 下创建新的中间件实现
/// 2. 在本文件的 `buildFor()` 中注册
class MiddlewareFactory {
  MiddlewareFactory._();

  /// 根据 Provider 类型构建对应的中间件列表
  static List<MessageMiddleware> buildFor(ProviderType type) {
    switch (type) {
      case ProviderType.gemini:
        return [
          GeminiThoughtSignatureMiddleware(),
          // 未来: GeminiSafetySettingsMiddleware(), ...
        ];

      case ProviderType.anthropic:
        return [
          // 未来: AnthropicCacheMiddleware(), ...
        ];

      default:
        // OpenAI 标准协议族 (OpenAI, DeepSeek, Kimi, GLM 等)
        return [];
    }
  }
}
