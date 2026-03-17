import 'dart:convert';

import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:baishou/agent/rag/embedding_model_utils.dart';
import 'package:baishou/core/providers/shared_preferences_provider.dart';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baishou/i18n/strings.g.dart';

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
  static const String _keyMonthlySummarySource = 'monthly_summary_source';
  static const String _keyAgentContextWindowSize =
      'agent_context_window_size';
  static const String _keyAgentCompanionMode = 'agent_companion_mode';
  static const String _keyAgentPersona = 'agent_persona';
  static const String _keyAgentGuidelines = 'agent_guidelines';
  static const String _keyGlobalEmbeddingProviderId =
      'global_embedding_provider_id';
  static const String _keyGlobalEmbeddingModelId =
      'global_embedding_model_id';
  static const String _keyDisabledToolIds = 'disabled_tool_ids';
  static const String _keyToolConfigPrefix = 'tool_config_';

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
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
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

  /// 获取月度总结的数据源：'weeklies'（仅周记） 或 'diaries'（全量日记）
  String get monthlySummarySource {
    return _prefs.getString(_keyMonthlySummarySource) ?? 'weeklies';
  }

  /// 设置月度总结的数据源
  Future<void> setMonthlySummarySource(String source) async {
    await _prefs.setString(_keyMonthlySummarySource, source);
  }

  /// Agent 上下文窗口大小（最近 N 条消息，默认 20）
  int get agentContextWindowSize {
    return _prefs.getInt(_keyAgentContextWindowSize) ?? 20;
  }

  /// 设置 Agent 上下文窗口大小（最小 5，无上限）
  Future<void> setAgentContextWindowSize(int size) async {
    final clamped = size < 5 ? 5 : size;
    await _prefs.setInt(_keyAgentContextWindowSize, clamped);
  }

  /// 是否启用伴侣模式
  /// 伴侣模式：无会话概念，持续交互，自动管理上下文窗口
  /// 会话模式（默认）：传统多会话，每个会话独立
  bool get agentCompanionMode {
    return _prefs.getBool(_keyAgentCompanionMode) ?? false;
  }

  /// 设置伴侣模式开关
  Future<void> setAgentCompanionMode(bool enabled) async {
    await _prefs.setBool(_keyAgentCompanionMode, enabled);
  }

  /// Agent 角色人设描述
  String get agentPersona {
    return _prefs.getString(_keyAgentPersona) ??
        '你是白守的 AI 助手，帮助用户回顾日记和生活记录。';
  }

  /// 设置 Agent 角色人设
  Future<void> setAgentPersona(String persona) async {
    await _prefs.setString(_keyAgentPersona, persona.trim());
  }

  /// Agent 行为准则
  String get agentGuidelines {
    return _prefs.getString(_keyAgentGuidelines) ??
        '请使用工具查阅日记内容，不要编造。引用时注明日期。';
  }

  /// 设置 Agent 行为准则
  Future<void> setAgentGuidelines(String guidelines) async {
    await _prefs.setString(_keyAgentGuidelines, guidelines.trim());
  }

  // --- 全局 Embedding 模型设置 ---

  /// 获取全局 Embedding 模型的供应商 ID
  String get globalEmbeddingProviderId {
    return _prefs.getString(_keyGlobalEmbeddingProviderId) ?? '';
  }

  /// 获取全局 Embedding 模型的 ID
  String get globalEmbeddingModelId {
    return _prefs.getString(_keyGlobalEmbeddingModelId) ?? '';
  }

  /// 设置全局 Embedding 模型
  Future<void> setGlobalEmbeddingModel(
    String providerId,
    String modelId,
  ) async {
    // 换模型时清除维度缓存，让下次嵌入时重新检测
    final oldModelId = globalEmbeddingModelId;
    await _prefs.setString(_keyGlobalEmbeddingProviderId, providerId);
    await _prefs.setString(_keyGlobalEmbeddingModelId, modelId);
    if (oldModelId != modelId) {
      await _prefs.remove('global_embedding_dimension');
    }
  }

  /// 当前是否已配置 Embedding 模型
  bool get hasEmbeddingModel {
    return globalEmbeddingProviderId.isNotEmpty &&
        globalEmbeddingModelId.isNotEmpty;
  }

  /// 获取缓存的嵌入维度（0 表示未检测）
  int get globalEmbeddingDimension {
    return _prefs.getInt('global_embedding_dimension') ?? 0;
  }

  /// 缓存嵌入维度
  Future<void> setGlobalEmbeddingDimension(int dimension) async {
    await _prefs.setInt('global_embedding_dimension', dimension);
  }

  // --- 工具配置管理 ---

  /// 获取被禁用的工具 ID 列表
  List<String> get disabledToolIds {
    return _prefs.getStringList(_keyDisabledToolIds) ?? [];
  }

  /// 设置被禁用的工具 ID 列表
  Future<void> setDisabledToolIds(List<String> ids) async {
    await _prefs.setStringList(_keyDisabledToolIds, ids);
  }

  /// 切换工具启用/禁用状态
  Future<void> toggleToolEnabled(String toolId, bool enabled) async {
    final ids = List<String>.from(disabledToolIds);
    if (enabled) {
      ids.remove(toolId);
    } else {
      if (!ids.contains(toolId)) ids.add(toolId);
    }
    await setDisabledToolIds(ids);
  }

  /// 工具是否启用
  bool isToolEnabled(String toolId) {
    return !disabledToolIds.contains(toolId);
  }

  /// 获取某工具的用户自定义配置（key-value Map）
  Map<String, dynamic> getToolConfig(String toolId) {
    final raw = _prefs.getString('$_keyToolConfigPrefix$toolId');
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(json.decode(raw));
    } catch (_) {
      return {};
    }
  }

  /// 设置某工具的单个配置项
  Future<void> setToolConfigValue(
    String toolId,
    String key,
    dynamic value,
  ) async {
    final config = getToolConfig(toolId);
    config[key] = value;
    await _prefs.setString(
      '$_keyToolConfigPrefix$toolId',
      json.encode(config),
    );
  }

  /// 获取某工具某配置项的当前值（无则返回 null）
  dynamic getToolConfigValue(String toolId, String key) {
    return getToolConfig(toolId)[key];
  }

  /// 获取所有可用的模型列表，返回一个 Map 列表，方便 UI 渲染下拉框
  /// 每个 Map 包含 provider_id, provider_name, model_id
  List<Map<String, String>> getAllAvailableModels() {
    final providers = getProviders();
    final result = <Map<String, String>>[];
    for (var p in providers) {
      if (!p.isEnabled) continue; // 仅返回已启用的供应商模型
      for (var m in p.models) {
        if (!p.enabledModels.contains(m)) continue; // 仅返回用户已主动开启的模型
        result.add({
          'provider_id': p.id,
          'provider_name': p.name,
          'model_id': m,
        });
      }
    }
    return result;
  }

  /// 获取所有非 Embedding 模型（用于对话/总结/命名选择器）
  List<Map<String, String>> getAllNonEmbeddingModels() {
    return getAllAvailableModels()
        .where((m) => !isEmbeddingModel(m['model_id'] ?? ''))
        .toList();
  }

  /// 获取所有 Embedding 模型（用于 Embedding 选择器）
  List<Map<String, String>> getAllEmbeddingModels() {
    return getAllAvailableModels()
        .where((m) => isEmbeddingModel(m['model_id'] ?? ''))
        .toList();
  }

  /// 从远程 API 自动获取供应商支持的模型列表 (类似于 Cherry Studio)
  Future<List<String>> fetchAvailableModels(AiProviderModel provider) async {
    try {
      final client = AiClientFactory.createClient(provider);
      return await client.fetchAvailableModels();
    } catch (e) {
      throw Exception(t.ai_config.fetch_models_failed(e: e.toString()));
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
