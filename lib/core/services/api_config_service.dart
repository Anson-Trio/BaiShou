import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:baishou/core/providers/shared_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 服务配置管理类
/// 负责处理 AI 供应商列表、当前激活的供应商以及全局默认模型设置的持久化与读取。
class ApiConfigService {
  // SharedPreferences 键名定义
  static const String _keyProviders = 'ai_providers_list';
  static const String _keyActiveProviderId = 'active_ai_provider_id';
  static const String _keyGlobalDialogueProviderId =
      'global_dialogue_provider_id';
  static const String _keyGlobalDialogueModelId = 'global_dialogue_model_id';
  static const String _keyGlobalNamingProviderId = 'global_naming_provider_id';
  static const String _keyGlobalNamingModelId = 'global_naming_model_id';
  static const String _keyGlobalSummaryProviderId =
      'global_summary_provider_id';
  static const String _keyGlobalSummaryModelId = 'global_summary_model_id';

  final SharedPreferences _prefs;

  ApiConfigService(this._prefs) {
    _initializeDefaultProvidersIfEmpty();
  }

  /// 如果配置为空，初始化默认的 AI 供应商列表（OpenAI, Gemini, Claude, DeepSeek, Kimi, GLM）
  void _initializeDefaultProvidersIfEmpty() {
    final providersStr = _prefs.getString(_keyProviders);
    if (providersStr == null || providersStr.isEmpty) {
      final defaultProviders = [
        AiProviderModel(
          id: 'openai',
          name: 'OpenAI',
          type: ProviderType.openai,
          baseUrl: 'https://api.openai.com/v1',
          models: [],
          defaultDialogueModel: '',
          defaultNamingModel: '',
        ),
        AiProviderModel(
          id: 'gemini',
          name: 'Google Gemini',
          type: ProviderType.gemini,
          baseUrl: 'https://generativelanguage.googleapis.com',
          models: [],
          defaultDialogueModel: '',
          defaultNamingModel: '',
        ),
        AiProviderModel(
          id: 'anthropic',
          name: 'Anthropic Claude',
          type: ProviderType.anthropic,
          baseUrl: 'https://api.anthropic.com',
          models: [],
          defaultDialogueModel: '',
          defaultNamingModel: '',
        ),
        AiProviderModel(
          id: 'deepseek',
          name: 'DeepSeek',
          type: ProviderType.deepseek,
          baseUrl: 'https://api.deepseek.com',
          models: [],
          defaultDialogueModel: '',
          defaultNamingModel: '',
        ),
        AiProviderModel(
          id: 'kimi',
          name: 'Kimi (Moonshot)',
          type: ProviderType.kimi,
          baseUrl: 'https://api.moonshot.cn/v1',
          models: [],
          defaultDialogueModel: '',
          defaultNamingModel: '',
        ),
        AiProviderModel(
          id: 'glm',
          name: 'Zhipu GLM',
          type: ProviderType.glm,
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          models: [],
          defaultDialogueModel: '',
          defaultNamingModel: '',
        ),
      ];

      _saveProviders(defaultProviders);
      _prefs.setString(_keyActiveProviderId, 'gemini');
    }
  }

  /// 获取所有已配置的 AI 供应商列表
  List<AiProviderModel> getProviders() {
    final providersStr = _prefs.getString(_keyProviders);
    if (providersStr == null || providersStr.isEmpty) return [];

    try {
      final List<dynamic> decoded = json.decode(providersStr);
      return decoded.map((e) => AiProviderModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 将 AI 供应商列表保存到持久化存储
  Future<void> _saveProviders(List<AiProviderModel> providers) async {
    final encoded = json.encode(providers.map((e) => e.toMap()).toList());
    await _prefs.setString(_keyProviders, encoded);
  }

  /// 根据 ID 获取特定供应商的配置
  AiProviderModel? getProvider(String id) {
    final providers = getProviders();
    try {
      return providers.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 更新或添加一个新的供应商配置
  Future<void> updateProvider(AiProviderModel provider) async {
    final providers = getProviders();
    final index = providers.indexWhere((p) => p.id == provider.id);

    if (index != -1) {
      providers[index] = provider;
    } else {
      providers.add(provider);
    }

    await _saveProviders(providers);
  }

  /// 获取当前“活跃”供应商的 ID（用于向下兼容或页面默认选中）
  String get activeProviderId {
    return _prefs.getString(_keyActiveProviderId) ?? 'gemini';
  }

  /// 设置当前“活跃”供应商的 ID
  Future<void> setActiveProviderId(String id) async {
    await _prefs.setString(_keyActiveProviderId, id);
  }

  /// 获取当前“活跃”供应商的完整模型对象
  AiProviderModel? getActiveProvider() {
    return getProvider(activeProviderId);
  }

  // --- 全局默认模型设置 (Global Default Models) ---

  /// 获取全局默认对话模型的供应商 ID
  String get globalDialogueProviderId {
    return _prefs.getString(_keyGlobalDialogueProviderId) ?? activeProviderId;
  }

  /// 获取全局默认对话模型的 ID
  String get globalDialogueModelId {
    return _prefs.getString(_keyGlobalDialogueModelId) ??
        getActiveProvider()?.defaultDialogueModel ??
        '';
  }

  /// 设置全局默认对话模型
  Future<void> setGlobalDialogueModel(String providerId, String modelId) async {
    await _prefs.setString(_keyGlobalDialogueProviderId, providerId);
    await _prefs.setString(_keyGlobalDialogueModelId, modelId);
  }

  /// 获取全局默认命名模型的供应商 ID
  String get globalNamingProviderId {
    return _prefs.getString(_keyGlobalNamingProviderId) ?? activeProviderId;
  }

  /// 获取全局默认命名模型的 ID
  String get globalNamingModelId {
    return _prefs.getString(_keyGlobalNamingModelId) ??
        getActiveProvider()?.defaultNamingModel ??
        '';
  }

  /// 设置全局默认命名模型
  Future<void> setGlobalNamingModel(String providerId, String modelId) async {
    await _prefs.setString(_keyGlobalNamingProviderId, providerId);
    await _prefs.setString(_keyGlobalNamingModelId, modelId);
  }

  /// 获取全局记忆总结模型的供应商 ID
  String get globalSummaryProviderId {
    return _prefs.getString(_keyGlobalSummaryProviderId) ?? activeProviderId;
  }

  /// 获取全局记忆总结模型的 ID
  String get globalSummaryModelId {
    return _prefs.getString(_keyGlobalSummaryModelId) ?? '';
  }

  /// 设置全局记忆总结模型
  Future<void> setGlobalSummaryModel(String providerId, String modelId) async {
    await _prefs.setString(_keyGlobalSummaryProviderId, providerId);
    await _prefs.setString(_keyGlobalSummaryModelId, modelId);
  }

  /// 获取所有可用的模型列表，返回一个 Map 列表，方便 UI 渲染下拉框
  /// 每个 Map 包含 provider_id, provider_name, model_id
  List<Map<String, String>> getAllAvailableModels() {
    final providers = getProviders();
    final result = <Map<String, String>>[];
    for (var p in providers) {
      if (!p.isEnabled) continue; // 仅返回已启用的供应商模型
      for (var m in p.models) {
        result.add({
          'provider_id': p.id,
          'provider_name': p.name,
          'model_id': m,
        });
      }
    }
    return result;
  }

  /// 从远程 API 自动获取供应商支持的模型列表 (类似于 Cherry Studio)
  /// 支持大多数标准的 OpenAI 兼容接口 /models 端点
  Future<List<String>> fetchAvailableModels(AiProviderModel provider) async {
    if (provider.apiKey.isEmpty) {
      throw Exception('未填写 API Key，无法获取模型。');
    }
    if (provider.baseUrl.isEmpty) {
      throw Exception('未填写 API 地址，无法获取模型。');
    }

    // 格式化 Base URL，确保它不会以 /chat/completions 结尾，而是指向根路径以访问 /models
    var baseUrlStr = provider.baseUrl;
    if (baseUrlStr.endsWith('/')) {
      baseUrlStr = baseUrlStr.substring(0, baseUrlStr.length - 1);
    }

    // 大多数供应商（Deepseek, OpenAI, Kimi, GLM）都遵循标准的 /models API
    final uri = Uri.parse('$baseUrlStr/models');

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${provider.apiKey}',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('data') && data['data'] is List) {
          final List<dynamic> modelsList = data['data'];
          final List<String> result = [];
          for (var model in modelsList) {
            if (model is Map && model.containsKey('id')) {
              result.add(model['id'].toString());
            }
          }
          return result;
        } else {
          throw Exception('响应数据格式错误：未找到 "data" 列表字段。');
        }
      } else {
        throw Exception('HTTP 错误 ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('获取模型列表失败: $e');
    }
  }

  // --- 兼容性占位符 (Legacy Support) ---
  // 用于在不破坏现有代码的情况下映射旧的 API 调用

  String get geminiApiKey => getProvider('gemini')?.apiKey ?? '';
  String get openAiApiKey => getProvider('openai')?.apiKey ?? '';

  String get apiKey {
    return getActiveProvider()?.apiKey ?? '';
  }

  String get baseUrl {
    return getActiveProvider()?.baseUrl ?? '';
  }
}

/// Riverpod Provider 定义
final apiConfigServiceProvider = Provider<ApiConfigService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiConfigService(prefs);
});
