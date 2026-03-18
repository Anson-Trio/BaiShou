import 'dart:io';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/summary/domain/services/summary_generator_service.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/presentation/widgets/provider_config_form.dart';
import 'package:baishou/features/settings/presentation/widgets/provider_list_panel.dart';
import 'package:baishou/features/settings/presentation/widgets/provider_model_list.dart';
import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/i18n/strings.g.dart';

/// AI 模型服务配置视图
/// 提供供应商列表选择、API 密钥配置、模型获取以及连接测试等功能。
class AiModelServicesView extends ConsumerStatefulWidget {
  const AiModelServicesView({super.key});

  @override
  ConsumerState<AiModelServicesView> createState() =>
      _AiModelServicesViewState();
}

class _AiModelServicesViewState extends ConsumerState<AiModelServicesView> {
  final _formKey = GlobalKey<FormState>();

  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String _selectedProviderId = 'gemini'; // 当前选中的供应商 ID
  List<AiProviderModel> _providers = []; // 所有供应商模型列表
  bool _isObscure = true; // API Key 是否明文显示
  bool _isTesting = false; // 是否正在进行连接测试
  bool _isFetchingModels = false; // 是否正在从远程获取模型列表

  @override
  void initState() {
    super.initState();
    // 渲染完成后加载配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProviderConfig();
    });
  }

  void _loadProviderConfig() {
    final service = ref.read(apiConfigServiceProvider);
    setState(() {
      _providers = service.getProviders();
      // 如果当前选中的供应商在列表中不存在，才回退到活跃供应商
      if (!_providers.any((p) => p.id == _selectedProviderId)) {
        _selectedProviderId = service.activeProviderId;
      }
    });
    _populateControllersForSelected();
  }

  /// 将选中供应商的配置填入输入框
  void _populateControllersForSelected() {
    final provider = _providers.firstWhere(
      (p) => p.id == _selectedProviderId,
      orElse: () =>
          AiProviderModel(id: '', name: '', type: ProviderType.custom),
    );

    _baseUrlController.text = provider.baseUrl;
    _apiKeyController.text = provider.apiKey;
    setState(() {});
  }

  /// 切换当前选中的供应商，切换前会临时保存当前输入框的内容
  void _switchProvider(String newId) {
    if (_selectedProviderId == newId) return;

    final currentIndex = _providers.indexWhere(
      (p) => p.id == _selectedProviderId,
    );
    if (currentIndex != -1) {
      _providers[currentIndex] = _providers[currentIndex].copyWith(
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text,
      );
    }

    setState(() {
      _selectedProviderId = newId;
    });
    _populateControllersForSelected();
  }

  /// 处理供应商点击事件，支持桌面端切换和移动端跳转
  void _handleProviderTap(String newId, bool isMobile) {
    if (_selectedProviderId != newId) {
      _switchProvider(newId);
    }

    if (isMobile) {
      // 移动端跳转到详细配置页（使用当前 context，确保配置页能读写父级 state）
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => StatefulBuilder(
            builder: (ctx2, setModalState) {
              final colorScheme = Theme.of(ctx2).colorScheme;
              return Scaffold(
                appBar: AppBar(title: Text(t.ai_config.model_config_title)),
                body: _buildConfigFormContainer(
                  colorScheme,
                  setModalState: setModalState,
                ),
              );
            },
          ),
        ),
      ).then((_) {
        // 返回后刷新列表页，确保 isEnabled 状态她同步
        _loadProviderConfig();
      });
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  /// 保存当前供应商的配置到持久化存储
  Future<void> _saveCurrentProviderConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final service = ref.read(apiConfigServiceProvider);

    final currentIdx = _providers.indexWhere(
      (p) => p.id == _selectedProviderId,
    );
    if (currentIdx != -1) {
      final updatedProvider = _providers[currentIdx].copyWith(
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text,
      );
      _providers[currentIdx] = updatedProvider;
      await service.updateProvider(updatedProvider);
      await service.setActiveProviderId(_selectedProviderId);
    }

    if (mounted) {
      AppToast.showSuccess(
        context,
        t.ai_config.save_success(id: _selectedProviderId),
      );
    }
  }

  /// 重置当前供应商的 API 地址为出厂默认值，并清空 API Key
  Future<void> _resetCurrentProvider({StateSetter? setModalState}) async {
    final currentIdx = _providers.indexWhere(
      (p) => p.id == _selectedProviderId,
    );
    if (currentIdx != -1) {
      final provider = _providers[currentIdx];
      String defaultUrl = '';

      // 根据供应商类型获取默认端点
      switch (provider.type) {
        case ProviderType.openai:
          defaultUrl = 'https://api.openai.com/v1';
          break;
        case ProviderType.gemini:
          defaultUrl = 'https://generativelanguage.googleapis.com/v1beta';
          break;
        case ProviderType.anthropic:
          defaultUrl = 'https://api.anthropic.com';
          break;
        case ProviderType.deepseek:
          defaultUrl = 'https://api.deepseek.com';
          break;
        case ProviderType.kimi:
          defaultUrl = 'https://api.moonshot.cn/v1';
          break;
        default:
          defaultUrl = '';
      }

      setState(() {
        _baseUrlController.text = defaultUrl;
        _apiKeyController.text = '';
      });
      setModalState?.call(() {});

      AppToast.showSuccess(context, t.ai_config.reset_success);
    }
  }

  /// 测试当前配置是否能成功连接
  Future<void> _testConnection({StateSetter? setModalState}) async {
    if (_apiKeyController.text.isEmpty) {
      AppToast.showError(context, t.ai_config.fill_api_key_hint);
      return;
    }

    final currentIdx = _providers.indexWhere(
      (p) => p.id == _selectedProviderId,
    );

    if (currentIdx != -1) {
      final p = _providers[currentIdx];
      // 拦截检测：如果模型列表为空，提示先获取模型
      if (p.models.isEmpty) {
        AppToast.showError(context, t.ai_config.fetch_models_first_hint);
        return;
      }
    }

    setState(() => _isTesting = true);
    setModalState?.call(() {});

    try {
      final currentIdx = _providers.indexWhere(
        (p) => p.id == _selectedProviderId,
      );
      if (currentIdx != -1) {
        final testProvider = _providers[currentIdx].copyWith(
          baseUrl: _baseUrlController.text,
          apiKey: _apiKeyController.text,
        );

        // 调用 SummaryGeneratorService 进行实际的打招呼测试
        await ref
            .read(summaryGeneratorServiceProvider)
            .testConnection(testProvider);

        if (mounted) {
          AppToast.showSuccess(context, t.ai_config.test_connection_success);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          t.ai_config.test_connection_failed(e: e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
        setModalState?.call(() {});
      }
    }
  }

  /// 从远程服务器获取模型列表
  Future<void> _fetchModels({StateSetter? setModalState}) async {
    if (_apiKeyController.text.isEmpty) {
      AppToast.showError(context, '请先填写 API Key');
      return;
    }

    setState(() => _isFetchingModels = true);
    setModalState?.call(() {});

    try {
      final currentIdx = _providers.indexWhere(
        (p) => p.id == _selectedProviderId,
      );
      if (currentIdx != -1) {
        final tempProvider = _providers[currentIdx].copyWith(
          baseUrl: _baseUrlController.text,
          apiKey: _apiKeyController.text,
        );

        final service = ref.read(apiConfigServiceProvider);
        final models = await service.fetchAvailableModels(tempProvider);

        if (mounted) {
          setState(() {
            _providers[currentIdx] = _providers[currentIdx].copyWith(
              baseUrl: _baseUrlController.text,
              apiKey: _apiKeyController.text,
              models: models,
            );
          });
          setModalState?.call(() {});

          // 自动保存获取到的模型列表以及当前的地址/Key配置
          await service.updateProvider(_providers[currentIdx]);
          AppToast.showSuccess(context, t.ai_config.fetch_models_success);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          t.ai_config.fetch_models_failed(e: e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingModels = false);
        setModalState?.call(() {});
      }
    }
  }

  /// 获取供应商对应的图标资源
  Widget _getProviderIcon(ProviderType type, {double size = 20}) {
    switch (type) {
      case ProviderType.openai:
        return Image.asset(
          'assets/ai_provider_icon/openai.png',
          width: size,
          height: size,
        );
      case ProviderType.gemini:
        return Image.asset(
          'assets/ai_provider_icon/gemini-color.png',
          width: size,
          height: size,
        );
      case ProviderType.anthropic:
        return Image.asset(
          'assets/ai_provider_icon/claude-color.png',
          width: size,
          height: size,
        );
      case ProviderType.deepseek:
        return Image.asset(
          'assets/ai_provider_icon/deepseek-color.png',
          width: size,
          height: size,
        );
      case ProviderType.kimi:
        return Image.asset(
          'assets/ai_provider_icon/moonshot.png',
          width: size,
          height: size,
        );
      default:
        return Icon(
          Icons.cloud_outlined,
          color: Colors.grey.shade700,
          size: size,
        );
    }
  }

  /// 显示新增供应商对话框
  void _showAddProviderDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    ProviderType selectedType = ProviderType.openai;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(t.agent.provider.add_title),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 类型选择
                    DropdownButtonFormField<ProviderType>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: t.agent.provider.add_type_label,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ProviderType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: _getProviderIcon(type),
                              ),
                              const SizedBox(width: 8),
                              Text(type.name.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedType = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    // 名称
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: t.agent.provider.add_name_label,
                        hintText: t.agent.provider.add_name_hint,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // BaseURL
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.example.com/v1',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.common.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final service = ref.read(apiConfigServiceProvider);
                    final provider = await service.addCustomProvider(
                      name: name,
                      type: selectedType,
                      baseUrl: urlController.text.trim(),
                    );
                    Navigator.pop(ctx);
                    _loadProviderConfig();
                    _switchProvider(provider.id);
                  },
                  child: Text(t.agent.provider.add_button),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 删除当前选中的自定义供应商
  Future<void> _deleteCurrentProvider() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.provider.delete_title),
        content: Text(t.agent.provider.delete_confirm(name: _providers.firstWhere((p) => p.id == _selectedProviderId).name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.agent.provider.delete_button, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(apiConfigServiceProvider);
      await service.deleteProvider(_selectedProviderId);
      _selectedProviderId = service.activeProviderId;
      _loadProviderConfig();
    }
  }

  // --- 已交由 ProviderListPanel 接管 ---

  Widget _buildRightConfigPanel({StateSetter? setModalState}) {
    final activeProvider = _providers.firstWhere(
      (p) => p.id == _selectedProviderId,
      orElse: () => _providers.first,
    );
    final colorScheme = Theme.of(context).colorScheme;

    bool isMobile = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isMobile = true;
      }
    } catch (e) {}

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 40,
        isMobile ? 24 : 40,
        isMobile ? 16 : 40,
        100,
      ), // extra bottom padding for FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _getProviderIcon(activeProvider.type, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeProvider.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.ai_config.manage_services_desc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Switch(
                value: activeProvider.isEnabled,
                onChanged: (val) async {
                  final provider = activeProvider.copyWith(isEnabled: val);
                  await ref
                      .read(apiConfigServiceProvider)
                      .updateProvider(provider);
                  final idx = _providers.indexWhere((p) => p.id == provider.id);
                  if (idx != -1) {
                    setState(() {
                      _providers[idx] = provider;
                    });
                    setModalState?.call(() {});
                  }
                },
                activeThumbColor: colorScheme.primary,
              ),
              // 删除按钮（仅显示于用户自定义供应商）
              if (!activeProvider.isSystem)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  tooltip: t.agent.provider.delete_tooltip,
                  onPressed: _deleteCurrentProvider,
                ),
            ],
          ),

          const SizedBox(height: 32),

          ProviderConfigForm(
            provider: activeProvider,
            baseUrlController: _baseUrlController,
            apiKeyController: _apiKeyController,
            isObscure: _isObscure,
            onObscureToggle: () {
              setState(() => _isObscure = !_isObscure);
              setModalState?.call(() {});
            },
            isTesting: _isTesting,
            onTestRequested: () =>
                _testConnection(setModalState: setModalState),
            onResetRequested: () =>
                _resetCurrentProvider(setModalState: setModalState),
            formKey: _formKey,
          ),

          const SizedBox(height: 32),
          Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
          const SizedBox(height: 32),

          ProviderModelList(
            provider: activeProvider,
            iconBuilder: (type) => _getProviderIcon(type),
            onFetchRequested: () => _fetchModels(setModalState: setModalState),
            isFetching: _isFetchingModels,
            onModelToggled: _loadProviderConfig,
          ),
        ],
      ),
    );
  }

  Widget _buildConfigFormContainer(
    ColorScheme colorScheme, {
    StateSetter? setModalState,
  }) {
    return Container(
      color: colorScheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildRightConfigPanel(setModalState: setModalState),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.9),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _saveCurrentProviderConfig,
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(t.ai_config.save_changes_button),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_providers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;

    bool isMobile = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isMobile = true;
      }
    } catch (e) {}

    final providersList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              t.ai_config.providers_label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ProviderListPanel(
            providers: _providers,
            selectedProviderId: _selectedProviderId,
            isMobile: isMobile,
            iconBuilder: (type) => _getProviderIcon(type),
            onProviderTap: _handleProviderTap,
            onReorder: isMobile ? null : (oldIndex, newIndex) async {
              if (oldIndex < newIndex) newIndex--;
              final item = _providers.removeAt(oldIndex);
              _providers.insert(newIndex, item);
              setState(() {});
              final orderedIds = _providers.map((p) => p.id).toList();
              await ref.read(apiConfigServiceProvider).reorderProviders(orderedIds);
              _loadProviderConfig();
            },
          ),
        ),
        if (!isMobile)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddProviderDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增供应商'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
      ],
    );

    if (isMobile) {
      return providersList;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left pane (Providers list)
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
          child: providersList,
        ),
        // Right pane (Config Form)
        Expanded(child: _buildConfigFormContainer(colorScheme)),
      ],
    );
  }
}
