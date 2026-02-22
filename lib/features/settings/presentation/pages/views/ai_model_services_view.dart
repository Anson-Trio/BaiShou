import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/summary/domain/services/summary_generator_service.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// 从 ApiConfigService 加载所有供应商配置
  void _loadProviderConfig() {
    final service = ref.read(apiConfigServiceProvider);
    setState(() {
      _providers = service.getProviders();
      _selectedProviderId = service.activeProviderId;
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
                appBar: AppBar(title: const Text('模型配置')),
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
      AppToast.showSuccess(context, '$_selectedProviderId 配置已保存');
    }
  }

  /// 重置当前供应商的 API 地址为出厂默认值，并清空 API Key
  Future<void> _resetCurrentProvider() async {
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
          defaultUrl = 'https://generativelanguage.googleapis.com';
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
        case ProviderType.glm:
          defaultUrl = 'https://open.bigmodel.cn/api/paas/v4';
          break;
        default:
          defaultUrl = '';
      }

      setState(() {
        _baseUrlController.text = defaultUrl;
        _apiKeyController.text = '';
      });

      AppToast.showSuccess(context, '已恢复默认地址并清空 API Key，请点击保存');
    }
  }

  /// 测试当前配置是否能成功连接
  Future<void> _testConnection() async {
    if (_apiKeyController.text.isEmpty) {
      AppToast.showError(context, '请先填写 API Key 并保存');
      return;
    }

    final currentIdx = _providers.indexWhere(
      (p) => p.id == _selectedProviderId,
    );

    if (currentIdx != -1) {
      final p = _providers[currentIdx];
      // 拦截检测：如果模型列表为空，提示先获取模型
      if (p.models.isEmpty) {
        AppToast.showError(context, '请先点击右下角的「获取模型」按钮');
        return;
      }
    }

    setState(() => _isTesting = true);

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
          AppToast.showSuccess(context, '连接测试成功！🎉');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, '连接失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  /// 从远程服务器获取模型列表
  Future<void> _fetchModels() async {
    if (_apiKeyController.text.isEmpty) {
      AppToast.showError(context, '请先填写 API Key');
      return;
    }

    setState(() => _isFetchingModels = true);

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
              models: models,
            );
          });
          // 自动保存获取到的模型列表
          await service.updateProvider(_providers[currentIdx]);
          AppToast.showSuccess(context, '成功获取并保存模型列表');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, '获取模型失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isFetchingModels = false);
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
      case ProviderType.glm:
        return Image.asset(
          'assets/ai_provider_icon/zai.png',
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

  /// 通用文本输入框构建器
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? trailing,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: trailing,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  /// 构建左侧供应商列表项
  Widget _buildProviderListItem(AiProviderModel p, bool isMobile) {
    final isSelected = _selectedProviderId == p.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _handleProviderTap(p.id, isMobile),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 32, height: 32, child: _getProviderIcon(p.type)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              // 启用状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isEnabled
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p.isEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: p.isEnabled
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightConfigPanel({StateSetter? setModalState}) {
    final activeProvider = _providers.firstWhere(
      (p) => p.id == _selectedProviderId,
      orElse: () => _providers.first,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        40,
        40,
        40,
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
                      '配置并管理大语言模型服务',
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
                    // 如果在通用的移动端详情页打开，同步刷新该页面的 state
                    setModalState?.call(() {});
                  }
                },
                activeColor: colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Connection Settings Section
          Row(
            children: [
              Icon(Icons.link, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '连接设置',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // API Key
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'API 密钥',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering, size: 16),
                    label: const Text('验证'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _apiKeyController,
            hint: '输入您的 API Key',
            icon: Icons.vpn_key_outlined,
            obscureText: _isObscure,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '密钥用于验证您的账户请求。全部配置仅保存在本地。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          // Base URL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'API 地址 (Base URL)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: _resetCurrentProvider,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('恢复默认', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _baseUrlController,
            hint: 'https://...',
            icon: Icons.dns_outlined,
          ),

          const SizedBox(height: 32),
          Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
          const SizedBox(height: 32),

          // Models Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_list_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '模型列表 (${activeProvider.models.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _isFetchingModels ? null : _fetchModels,
                icon: _isFetchingModels
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('获取模型'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  side: BorderSide(color: colorScheme.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (activeProvider.models.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.model_training_rounded,
                    size: 32,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无模型，点击右上角按钮获取',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: activeProvider.models.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _getProviderIcon(activeProvider.type),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  activeProvider.models[index],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '可用',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
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
            child: Form(
              key: _formKey,
              child: _buildRightConfigPanel(setModalState: setModalState),
            ),
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
                    label: const Text('保存修改'),
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    final providersList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              '服务提供商',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: isMobile ? const EdgeInsets.only(top: 8) : EdgeInsets.zero,
            itemCount: _providers.length,
            itemBuilder: (context, index) {
              return _buildProviderListItem(_providers[index], isMobile);
            },
          ),
        ),
        if (!isMobile)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
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
