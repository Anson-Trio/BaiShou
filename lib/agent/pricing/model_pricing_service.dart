/// 模型定价服务
/// 从 models.dev 获取公开的模型价格表，计算 token 费用
///
/// 参考 opencode: packages/opencode/src/session/index.ts (getUsage)
///           & packages/opencode/src/provider/models.ts (ModelsDev)

import 'dart:convert';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 单个模型的价格信息（美元/百万 token）
class ModelPrice {
  final double input;
  final double output;
  final double cacheRead;
  final double cacheWrite;

  /// 200K+ 上下文的阶梯价格（可选）
  /// 当 input_tokens + cached_tokens > 200K 时使用此价格
  final ModelPrice? over200K;

  const ModelPrice({
    required this.input,
    required this.output,
    this.cacheRead = 0,
    this.cacheWrite = 0,
    this.over200K,
  });

  /// 根据 token 用量计算费用（美元）
  /// 自动判断是否使用 200K+ 阶梯价
  double calculateCost(TokenUsage usage) {
    final totalInput =
        usage.inputTokens + (usage.cachedInputTokens ?? 0);

    // 如果有 200K+ 阶梯价且总输入超过 200K，使用阶梯价
    final effectivePrice =
        (over200K != null && totalInput > 200000) ? over200K! : this;

    final inputCost =
        usage.inputTokens * effectivePrice.input / 1000000;
    final outputCost =
        usage.outputTokens * effectivePrice.output / 1000000;
    final cacheCost =
        (usage.cachedInputTokens ?? 0) * effectivePrice.cacheRead / 1000000;
    return inputCost + outputCost + cacheCost;
  }
}

/// 模型定价服务 — 单例
class ModelPricingService {
  ModelPricingService._();
  static final instance = ModelPricingService._();

  /// 缓存: providerID/modelID → ModelPrice
  final Map<String, ModelPrice> _prices = {};
  DateTime? _lastFetchTime;

  /// 缓存有效期 1 小时
  static const _cacheDuration = Duration(hours: 1);

  /// 获取模型价格
  Future<ModelPrice?> getPrice(String providerId, String modelId) async {
    await _ensureLoaded();
    // 先精确匹配
    final key = '$providerId/$modelId';
    if (_prices.containsKey(key)) return _prices[key];

    // 再尝试仅 modelId 匹配（用户可能用自定义 provider）
    for (final entry in _prices.entries) {
      if (entry.key.endsWith('/$modelId')) return entry.value;
    }
    return null;
  }

  /// 快速计算费用（返回美元，获取失败返回 null）
  Future<double?> calculateCost(
    String providerId,
    String modelId,
    TokenUsage usage,
  ) async {
    final price = await getPrice(providerId, modelId);
    if (price == null) return null;
    return price.calculateCost(usage);
  }

  /// 确保价格表已加载
  Future<void> _ensureLoaded() async {
    if (_prices.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }
    await _fetchPrices();
  }

  /// 从 models.dev 拉取价格表
  Future<void> _fetchPrices() async {
    try {
      final response = await http
          .get(Uri.parse('https://models.dev/api.json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('models.dev returned ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      _prices.clear();
      for (final entry in data.entries) {
        final providerId = entry.key;
        final provider = entry.value as Map<String, dynamic>?;
        if (provider == null) continue;

        final models = provider['models'] as Map<String, dynamic>?;
        if (models == null) continue;

        for (final modelEntry in models.entries) {
          final modelId = modelEntry.key;
          final model = modelEntry.value as Map<String, dynamic>?;
          if (model == null) continue;

          final cost = model['cost'] as Map<String, dynamic>?;
          if (cost == null) continue;

          final inputPrice = (cost['input'] as num?)?.toDouble() ?? 0;
          if (inputPrice == 0) continue; // 跳过免费/未知模型

          // 解析 200K+ 阶梯价
          final over200KData =
              cost['context_over_200k'] as Map<String, dynamic>?;
          ModelPrice? over200K;
          if (over200KData != null) {
            over200K = ModelPrice(
              input: (over200KData['input'] as num?)?.toDouble() ?? inputPrice,
              output: (over200KData['output'] as num?)?.toDouble() ??
                  (cost['output'] as num?)?.toDouble() ?? 0,
              cacheRead:
                  (over200KData['cache_read'] as num?)?.toDouble() ?? 0,
              cacheWrite:
                  (over200KData['cache_write'] as num?)?.toDouble() ?? 0,
            );
          }

          _prices['$providerId/$modelId'] = ModelPrice(
            input: inputPrice,
            output: (cost['output'] as num?)?.toDouble() ?? 0,
            cacheRead: (cost['cache_read'] as num?)?.toDouble() ?? 0,
            cacheWrite: (cost['cache_write'] as num?)?.toDouble() ?? 0,
            over200K: over200K,
          );
        }
      }

      _lastFetchTime = DateTime.now();
      debugPrint('ModelPricing: loaded ${_prices.length} models');
    } catch (e) {
      debugPrint('ModelPricing fetch failed: $e');
      // 获取失败不阻塞主流程
    }
  }
}
