import 'dart:convert';

import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:baishou/agent/rag/embedding_model_utils.dart';
import 'package:baishou/core/providers/shared_preferences_provider.dart';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baishou/i18n/strings.g.dart';

import 'package:flutter/foundation.dart';

/// AI 服务配置管理类
/// 负责处理 AI 供应商列表、当前激活的供应商以及全局默认模型设置的持久化与读取。
class ApiConfigService extends ChangeNotifier {
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
  static const String _keyAgentContextWindowSize = 'agent_context_window_size';
  static const String _keyAgentPersona = 'agent_persona';
  static const String _keyAgentGuidelines = 'agent_guidelines';
  static const String _keyGlobalEmbeddingProviderId =
      'global_embedding_provider_id';
  static const String _keyGlobalEmbeddingModelId = 'global_embedding_model_id';
  static const String _keyDisabledToolIds = 'disabled_tool_ids';
  static const String _keyToolConfigPrefix = 'tool_config_';
  static const String _keyRagEnabled = 'rag_global_enabled';
  static const String _keyPinnedAssistants = 'agent_pinned_assistants';

  static const String _keySummaryInstructions = 'summary_prompt_instructions';
  static const String _keyRagTopK = 'rag_top_k';
  static const String _keyRagSimilarityThreshold = 'rag_similarity_threshold';

  // MCP Server 配置
  static const String _keyMcpEnabled = 'mcp_server_enabled';
  static const String _keyMcpPort = 'mcp_server_port';

  // 网络搜索配置
  static const String _keyWebSearchEngine = 'web_search_engine';
  static const String _keyWebSearchMaxResults = 'web_search_max_results';
  static const String _keyWebSearchRagEnabled = 'web_search_rag_enabled';
  static const String _keyTavilyApiKey = 'tavily_api_key';
  static const String _keyWebSearchRagMaxChunks = 'web_search_rag_max_chunks';
  static const String _keyWebSearchRagChunksPerSource =
      'web_search_rag_chunks_per_source';
  static const String _keyWebSearchPlainSnippetLength =
      'web_search_plain_snippet_length';

  final SharedPreferences _prefs;

  ApiConfigService(this._prefs) {
    _initializeDefaultProvidersIfEmpty();
    _migrateBuiltInProviders(); // 为老用户自动补充新增的内置供应商
  }

  /// 所有系统内置的默认供应商列表（默认关闭，由用户自行启用配置配置）
  List<AiProviderModel> get _defaultProviders => [
    AiProviderModel(
      id: 'openai',
      name: 'OpenAI',
      type: ProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      models: [],
      isEnabled: false,
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'gemini',
      name: 'Google Gemini',
      type: ProviderType.gemini,
      isEnabled: false,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'anthropic',
      name: 'Anthropic Claude',
      type: ProviderType.anthropic,
      isEnabled: false,
      baseUrl: 'https://api.anthropic.com',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'deepseek',
      name: 'DeepSeek',
      type: ProviderType.deepseek,
      isEnabled: false,
      baseUrl: 'https://api.deepseek.com',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'kimi',
      name: 'Kimi (Moonshot)',
      type: ProviderType.kimi,
      isEnabled: false,
      baseUrl: 'https://api.moonshot.cn/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'ollama',
      name: 'Ollama',
      type: ProviderType.ollama,
      isEnabled: false,
      baseUrl: 'http://localhost:11434/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'siliconflow',
      name: '硅基流动 (SiliconFlow)',
      type: ProviderType.siliconflow,
      isEnabled: false,
      baseUrl: 'https://api.siliconflow.cn/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'openrouter',
      name: 'OpenRouter',
      type: ProviderType.openrouter,
      isEnabled: false,
      baseUrl: 'https://openrouter.ai/api/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'dashscope',
      name: '通义千问 (百炼)',
      type: ProviderType.dashscope,
      isEnabled: false,
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'doubao',
      name: '豆包 (火山引擎)',
      type: ProviderType.doubao,
      isEnabled: false,
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'grok',
      name: 'Grok (xAI)',
      type: ProviderType.grok,
      isEnabled: false,
      baseUrl: 'https://api.x.ai/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'mistral',
      name: 'Mistral',
      type: ProviderType.mistral,
      isEnabled: false,
      baseUrl: 'https://api.mistral.ai/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
    AiProviderModel(
      id: 'lmstudio',
      name: 'LM Studio',
      type: ProviderType.lmstudio,
      isEnabled: false,
      baseUrl: 'http://localhost:1234/v1',
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
    ),
  ];

  /// 如果配置为空，初始化默认的 AI 供应商列表
  void _initializeDefaultProvidersIfEmpty() {
    final providersStr = _prefs.getString(_keyProviders);
    if (providersStr == null || providersStr.isEmpty) {
      _saveProviders(_defaultProviders);
      _prefs.setString(_keyActiveProviderId, 'gemini');
    }
  }

  /// 迁移内置供应商：检查老用户是否缺少新加的内置供应商，若是则补充
  /// 统一处理 v3 迁移：默认关闭所有系统供应商（需要用户手动开启）
  void _migrateBuiltInProviders() {
    final currentProviders = getProviders();
    if (currentProviders.isEmpty) return;

    bool needsSave = false;
    final existingIds = currentProviders.map((e) => e.id).toSet();

    for (final defaultProvider in _defaultProviders) {
      if (!existingIds.contains(defaultProvider.id)) {
        currentProviders.add(defaultProvider);
        needsSave = true;
      }
    }

    // [v3 强制迁移] 老数据默认打开了一堆未配置 APIKey 的供应商，全部打回关闭状态
    final hasMigratedDisabledProviders =
        _prefs.getBool('migrated_disable_empty_providers_v3') ?? false;

    if (!hasMigratedDisabledProviders) {
      for (int i = 0; i < currentProviders.length; i++) {
        final p = currentProviders[i];
        if (p.isSystem && p.isEnabled) {
          currentProviders[i] = p.copyWith(isEnabled: false);
          needsSave = true;
        }
      }
      _prefs.setBool('migrated_disable_empty_providers_v3', true);
    }

    if (needsSave) {
      _saveProviders(currentProviders);
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
    notifyListeners();
  }

  /// 添加用户自定义的供应商
  Future<AiProviderModel> addCustomProvider({
    required String name,
    required ProviderType type,
    String baseUrl = '',
  }) async {
    final providers = getProviders();
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final maxOrder = providers.fold<int>(
      0,
      (max, p) => p.sortOrder > max ? p.sortOrder : max,
    );
    final provider = AiProviderModel(
      id: id,
      name: name,
      type: type,
      baseUrl: baseUrl,
      models: [],
      defaultDialogueModel: '',
      defaultNamingModel: '',
      isSystem: false,
      sortOrder: maxOrder + 1,
    );
    providers.add(provider);
    await _saveProviders(providers);
    return provider;
  }

  /// 删除供应商（仅允许删除非系统内置供应商）
  Future<bool> deleteProvider(String id) async {
    final providers = getProviders();
    final target = providers.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('not found'),
    );
    if (target.isSystem) return false; // 不允许删除系统供应商
    providers.removeWhere((p) => p.id == id);
    await _saveProviders(providers);
    return true;
  }

  /// 按照给定的 ID 列表重新排序供应商
  Future<void> reorderProviders(List<String> orderedIds) async {
    final providers = getProviders();
    final reordered = <AiProviderModel>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final p = providers.firstWhere(
        (p) => p.id == orderedIds[i],
        orElse: () => throw Exception('Provider not found: ${orderedIds[i]}'),
      );
      reordered.add(p.copyWith(sortOrder: i));
    }
    await _saveProviders(reordered);
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
    final val = _prefs.getString(_keyGlobalDialogueModelId);
    if (val != null && val.isNotEmpty) return val;
    final active = getActiveProvider();
    if (active != null && active.apiKey.isNotEmpty) {
      return active.defaultDialogueModel;
    }
    return 'off';
  }

  /// 设置全局默认对话模型
  Future<void> setGlobalDialogueModel(String providerId, String modelId) async {
    if (globalDialogueProviderId == providerId &&
        globalDialogueModelId == modelId)
      return;
    await _prefs.setString(_keyGlobalDialogueProviderId, providerId);
    await _prefs.setString(_keyGlobalDialogueModelId, modelId);
    notifyListeners();
  }

  /// 获取全局默认命名模型的供应商 ID
  String get globalNamingProviderId {
    return _prefs.getString(_keyGlobalNamingProviderId) ?? activeProviderId;
  }

  /// 获取全局默认命名模型的 ID
  String get globalNamingModelId {
    final val = _prefs.getString(_keyGlobalNamingModelId);
    if (val != null && val.isNotEmpty) return val;
    final active = getActiveProvider();
    if (active != null && active.apiKey.isNotEmpty) {
      return active.defaultNamingModel;
    }
    return 'off';
  }

  /// 设置全局默认命名模型
  Future<void> setGlobalNamingModel(String providerId, String modelId) async {
    if (globalNamingProviderId == providerId && globalNamingModelId == modelId)
      return;
    await _prefs.setString(_keyGlobalNamingProviderId, providerId);
    await _prefs.setString(_keyGlobalNamingModelId, modelId);
    notifyListeners();
  }

  /// 获取全局记忆总结模型的供应商 ID
  String get globalSummaryProviderId {
    return _prefs.getString(_keyGlobalSummaryProviderId) ?? activeProviderId;
  }

  /// 获取全局记忆总结模型的 ID
  String get globalSummaryModelId {
    final val = _prefs.getString(_keyGlobalSummaryModelId);
    if (val != null && val.isNotEmpty) return val;
    final active = getActiveProvider();
    if (active != null && active.apiKey.isNotEmpty) {
      return active.defaultNamingModel; // 这里复用 naming 或者是 dialogue，因为原来这里只是空字符串
    }
    return 'off';
  }

  /// 设置全局记忆总结模型
  Future<void> setGlobalSummaryModel(String providerId, String modelId) async {
    if (globalSummaryProviderId == providerId &&
        globalSummaryModelId == modelId)
      return;
    await _prefs.setString(_keyGlobalSummaryProviderId, providerId);
    await _prefs.setString(_keyGlobalSummaryModelId, modelId);
    notifyListeners();
  }

  /// 获取月度总结的数据源：'weeklies'（仅周记） 或 'diaries'（全量日记）
  String get monthlySummarySource {
    return _prefs.getString(_keyMonthlySummarySource) ?? 'weeklies';
  }

  /// 设置月度总结的数据源
  Future<void> setMonthlySummarySource(String source) async {
    await _prefs.setString(_keyMonthlySummarySource, source);
  }

  // --- 侧边栏置顶助手配置 ---

  /// 获取在侧边栏置顶（固定）显示的助手 ID 列表
  List<String> get pinnedAssistantIds {
    return _prefs.getStringList(_keyPinnedAssistants) ?? [];
  }

  /// 批量覆盖置顶助手列表
  Future<void> setPinnedAssistantIds(List<String> ids) async {
    // 简单去重
    final uniqueIds = ids.toSet().toList();
    await _prefs.setStringList(_keyPinnedAssistants, uniqueIds);
    notifyListeners();
  }

  /// 切换某助手的置顶状态
  Future<void> togglePinnedAssistant(String assistantId) async {
    final ids = List<String>.from(pinnedAssistantIds);
    if (ids.contains(assistantId)) {
      ids.remove(assistantId);
    } else {
      if (ids.length >= 3) {
        ids.removeAt(0); // 挤掉最早固定的一个
      }
      ids.add(assistantId);
    }
    await setPinnedAssistantIds(ids);
  }

  // --- Agent 行为参数 ---

  /// Agent 上下文窗口大小（最近 N 条消息，默认 20）
  int get agentContextWindowSize {
    return _prefs.getInt(_keyAgentContextWindowSize) ?? 20;
  }

  /// 设置 Agent 上下文窗口大小（最小 5，无上限）
  Future<void> setAgentContextWindowSize(int size) async {
    final clamped = size < 5 ? 5 : size;
    await _prefs.setInt(_keyAgentContextWindowSize, clamped);
  }

  /// 深度陪伴模式：达到此 token 数时触发压缩（默认 8000）
  int get companionCompressTokens {
    return _prefs.getInt('companion_compress_tokens') ?? 8000;
  }

  Future<void> setCompanionCompressTokens(int value) async {
    await _prefs.setInt('companion_compress_tokens', value);
  }

  /// 深度陪伴模式：压缩时截断多少 token 以前的对话（默认 4000）
  int get companionTruncateTokens {
    return _prefs.getInt('companion_truncate_tokens') ?? 4000;
  }

  Future<void> setCompanionTruncateTokens(int value) async {
    await _prefs.setInt('companion_truncate_tokens', value);
  }

  /// Agent 角色人设描述
  String get agentPersona {
    return _prefs.getString(_keyAgentPersona) ?? '你是 AI 伙伴，帮助用户回顾日记和生活记录。';
  }

  /// 设置 Agent 角色人设
  Future<void> setAgentPersona(String persona) async {
    await _prefs.setString(_keyAgentPersona, persona.trim());
  }

  /// Agent 行为准则
  String get agentGuidelines {
    return _prefs.getString(_keyAgentGuidelines) ?? '请使用工具查阅日记内容，不要编造。引用时注明日期。';
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
    notifyListeners();
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

  Future<void> setGlobalEmbeddingDimension(int dimension) async {
    await _prefs.setInt('global_embedding_dimension', dimension);
    notifyListeners();
  }

  // --- RAG 全局记忆开关 ---

  /// 是否启用全局记忆（RAG检索），默认启用
  bool get ragEnabled {
    return _prefs.getBool(_keyRagEnabled) ?? true;
  }

  Future<void> setRagEnabled(bool enabled) async {
    await _prefs.setBool(_keyRagEnabled, enabled);
    notifyListeners();
  }

  /// RAG 检索 topK（返回前 K 个最相似的结果，默认 20）
  int get ragTopK {
    return _prefs.getInt(_keyRagTopK) ?? 20;
  }

  /// 设置 RAG topK
  void setRagTopK(int topK) {
    _prefs.setInt(_keyRagTopK, topK.clamp(1, 100));
    notifyListeners();
  }

  /// RAG 相似度阈值（低于此值的结果会被过滤，默认 0.4 不过滤）
  double get ragSimilarityThreshold {
    return _prefs.getDouble(_keyRagSimilarityThreshold) ?? 0.4;
  }

  /// 设置 RAG 相似度阈值
  void setRagSimilarityThreshold(double threshold) {
    _prefs.setDouble(_keyRagSimilarityThreshold, threshold.clamp(0.0, 1.0));
    notifyListeners();
  }

  // --- 总结提示词自定义（按类型独立配置） ---

  /// 获取指定类型的总结自定义指令（null 表示使用默认）
  String? getSummaryInstructions(String type) {
    return _prefs.getString('${_keySummaryInstructions}_$type');
  }

  /// 设置指定类型的总结指令
  Future<void> setSummaryInstructions(String type, String instructions) async {
    await _prefs.setString('${_keySummaryInstructions}_$type', instructions);
  }

  /// 向后兼容：获取旧的统一提示词（用于迁移）
  String? get summaryInstructions {
    return _prefs.getString(_keySummaryInstructions);
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
    await _prefs.setString('$_keyToolConfigPrefix$toolId', json.encode(config));
  }

  /// 获取某工具某配置项的当前值（无则返回 null）
  dynamic getToolConfigValue(String toolId, String key) {
    return getToolConfig(toolId)[key];
  }

  /// 导出所有自定义类型的总结指令
  Map<String, String> exportAllSummaryInstructions() {
    final result = <String, String>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('${_keySummaryInstructions}_')) {
        final type = key.substring('${_keySummaryInstructions}_'.length);
        result[type] = _prefs.getString(key)!;
      }
    }
    return result;
  }

  /// 批量导入自定义类型的总结指令
  Future<void> importAllSummaryInstructions(
    Map<String, String> instructions,
  ) async {
    for (final entry in instructions.entries) {
      await _prefs.setString(
        '${_keySummaryInstructions}_${entry.key}',
        entry.value,
      );
    }
  }

  /// 导出所有工具的独立配置
  Map<String, dynamic> exportAllToolConfigs() {
    final result = <String, dynamic>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_keyToolConfigPrefix)) {
        final toolId = key.substring(_keyToolConfigPrefix.length);
        try {
          result[toolId] = json.decode(_prefs.getString(key)!);
        } catch (_) {}
      }
    }
    return result;
  }

  /// 批量导入所有工具的独立配置
  Future<void> importAllToolConfigs(Map<String, dynamic> configs) async {
    for (final entry in configs.entries) {
      await _prefs.setString(
        '$_keyToolConfigPrefix${entry.key}',
        json.encode(entry.value),
      );
    }
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
    final list = getAllAvailableModels()
        .where((m) => !isEmbeddingModel(m['model_id'] ?? ''))
        .toList();
    list.insert(0, {'provider_id': 'off', 'provider_name': 'OFF', 'model_id': 'off'});
    return list;
  }

  /// 获取所有 Embedding 模型（用于 Embedding 选择器）
  List<Map<String, String>> getAllEmbeddingModels() {
    final list = getAllAvailableModels()
        .where((m) => isEmbeddingModel(m['model_id'] ?? ''))
        .toList();
    list.insert(0, {'provider_id': 'off', 'provider_name': 'OFF', 'model_id': 'off'});
    return list;
  }

  Future<List<String>> fetchAvailableModels(AiProviderModel provider) async {
    try {
      final client = AiClientFactory.createClient(provider);
      return await client.fetchAvailableModels();
    } catch (e) {
      throw Exception(t.ai_config.fetch_models_failed(e: e.toString()));
    }
  }

  // --- MCP Server 配置 ---

  /// MCP Server 是否启用（默认关闭）
  bool get mcpEnabled {
    return _prefs.getBool(_keyMcpEnabled) ?? false;
  }

  /// 设置 MCP Server 启用状态
  Future<void> setMcpEnabled(bool enabled) async {
    await _prefs.setBool(_keyMcpEnabled, enabled);
  }

  /// MCP Server 端口（默认 31004）
  int get mcpPort {
    return _prefs.getInt(_keyMcpPort) ?? 31004;
  }

  /// 设置 MCP Server 端口
  Future<void> setMcpPort(int port) async {
    await _prefs.setInt(_keyMcpPort, port.clamp(1024, 65535));
  }

  // --- 网络搜索专门配置 (Web Search) ---

  /// 使用的搜索引擎：'duckduckgo' 或 'tavily'
  String get webSearchEngine {
    return _prefs.getString(_keyWebSearchEngine) ?? 'duckduckgo';
  }

  Future<void> setWebSearchEngine(String engine) async {
    if (webSearchEngine == engine) return;
    await _prefs.setString(_keyWebSearchEngine, engine);
    notifyListeners();
  }

  /// 搜索返回的最大结果数 (1-30)
  int get webSearchMaxResults {
    return _prefs.getInt(_keyWebSearchMaxResults) ?? 5;
  }

  Future<void> setWebSearchMaxResults(int results) async {
    final clamped = results.clamp(1, 30);
    if (webSearchMaxResults == clamped) return;
    await _prefs.setInt(_keyWebSearchMaxResults, clamped);
    notifyListeners();
  }

  /// 是否启用了 Web-RAG (网页压缩读取)
  bool get webSearchRagEnabled {
    return _prefs.getBool(_keyWebSearchRagEnabled) ?? false;
  }

  Future<void> setWebSearchRagEnabled(bool enabled) async {
    if (webSearchRagEnabled == enabled) return;
    await _prefs.setBool(_keyWebSearchRagEnabled, enabled);
    notifyListeners();
  }

  /// Tavily API Key
  String get tavilyApiKey {
    return _prefs.getString(_keyTavilyApiKey) ?? '';
  }

  Future<void> setTavilyApiKey(String key) async {
    final sanitized = key.trim();
    if (tavilyApiKey == sanitized) return;
    await _prefs.setString(_keyTavilyApiKey, sanitized);
    notifyListeners();
  }

  /// 引用片段总数上限 (默认 12)
  int get webSearchRagMaxChunks {
    return _prefs.getInt(_keyWebSearchRagMaxChunks) ?? 12;
  }

  Future<void> setWebSearchRagMaxChunks(int chunks) async {
    final clamped = chunks.clamp(1, 50);
    if (webSearchRagMaxChunks == clamped) return;
    await _prefs.setInt(_keyWebSearchRagMaxChunks, clamped);
    notifyListeners();
  }

  /// 单来源最大片段数 (默认 4)
  int get webSearchRagChunksPerSource {
    return _prefs.getInt(_keyWebSearchRagChunksPerSource) ?? 4;
  }

  Future<void> setWebSearchRagChunksPerSource(int chunks) async {
    final clamped = chunks.clamp(1, 20);
    if (webSearchRagChunksPerSource == clamped) return;
    await _prefs.setInt(_keyWebSearchRagChunksPerSource, clamped);
    notifyListeners();
  }

  /// 未配置 Embedding 时的直接纯文本截取上限 (默认 3000)
  int get webSearchPlainSnippetLength {
    return _prefs.getInt(_keyWebSearchPlainSnippetLength) ?? 3000;
  }

  Future<void> setWebSearchPlainSnippetLength(int length) async {
    final clamped = length.clamp(100, 30000);
    if (webSearchPlainSnippetLength == clamped) return;
    await _prefs.setInt(_keyWebSearchPlainSnippetLength, clamped);
    notifyListeners();
  }

  // --- UI Preferences ---
  static const String _keyShowChatToolbar = 'show_chat_toolbar';

  bool get showChatToolbar {
    return _prefs.getBool(_keyShowChatToolbar) ?? true;
  }

  Future<void> setShowChatToolbar(bool show) async {
    if (showChatToolbar == show) return;
    await _prefs.setBool(_keyShowChatToolbar, show);
    notifyListeners();
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
