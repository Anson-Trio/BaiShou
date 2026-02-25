import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/presentation/widgets/custom_model_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 全局默认模型配置视图
/// 允许用户为对话、命名和总结任务指定默认使用的供应商和模型。
class AiGlobalModelsView extends ConsumerStatefulWidget {
  const AiGlobalModelsView({super.key});

  @override
  ConsumerState<AiGlobalModelsView> createState() => _AiGlobalModelsViewState();
}

class _AiGlobalModelsViewState extends ConsumerState<AiGlobalModelsView> {
  // 选中的模型标识符 (格式: providerId:modelId)
  String? _globalDialogueModel;
  String? _globalNamingModel;
  String? _globalSummaryModel;

  @override
  void initState() {
    super.initState();
    // 渲染完成后加载配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProviderConfig();
    });
  }

  /// 从 ApiConfigService 加载当前的全局选型配置
  void _loadProviderConfig() {
    final service = ref.read(apiConfigServiceProvider);
    setState(() {
      _globalDialogueModel = _buildGlobalIdentifier(
        service.globalDialogueProviderId,
        service.globalDialogueModelId,
      );

      _globalNamingModel = _buildGlobalIdentifier(
        service.globalNamingProviderId,
        service.globalNamingModelId,
      );

      _globalSummaryModel = _buildGlobalIdentifier(
        service.globalSummaryProviderId,
        service.globalSummaryModelId,
      );
    });
  }

  /// 构建统一的模型标识符
  String _buildGlobalIdentifier(String providerId, String modelId) {
    if (providerId.isEmpty || modelId.isEmpty) return '';
    return '$providerId:$modelId';
  }

  /// 将当前的全局配置保存到持久化存储
  Future<void> _saveGlobalDefaults() async {
    final service = ref.read(apiConfigServiceProvider);

    // 解析并保存对话模型
    if (_globalDialogueModel != null && _globalDialogueModel!.isNotEmpty) {
      final parts = _globalDialogueModel!.split(':');
      if (parts.length >= 2) {
        await service.setGlobalDialogueModel(
          parts[0],
          parts.sublist(1).join(':'),
        );
      }
    }

    // 解析并保存命名模型
    if (_globalNamingModel != null && _globalNamingModel!.isNotEmpty) {
      final parts = _globalNamingModel!.split(':');
      if (parts.length >= 2) {
        await service.setGlobalNamingModel(
          parts[0],
          parts.sublist(1).join(':'),
        );
      }
    }

    // 解析并保存总结模型
    if (_globalSummaryModel != null && _globalSummaryModel!.isNotEmpty) {
      final parts = _globalSummaryModel!.split(':');
      if (parts.length >= 2) {
        await service.setGlobalSummaryModel(
          parts[0],
          parts.sublist(1).join(':'),
        );
      }
    }

    if (mounted) {
      AppToast.showSuccess(context, t.ai_config.global_models_updated);
    }
  }

  /// 构建模型选择区块
  Widget _buildDefaultModelSection({
    required String title,
    required IconData icon,
    required String description,
    required String? value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          // 如果列表为空，点击显示错误提示
          GestureDetector(
            onTap: items.isEmpty
                ? () {
                    AppToast.showError(context, t.ai_config.no_models_error);
                  }
                : null,
            child: AbsorbPointer(
              absorbing: items.isEmpty,
              child: CustomModelSelector(
                title: title.replaceAll('默认', ''),
                selectedModelId: items.isEmpty || value == null || value.isEmpty
                    ? null
                    : value,
                availableModels: items,
                onModelSelected: onChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(apiConfigServiceProvider);
    final allModels = service.getAllAvailableModels();

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.ai_config.global_models_title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _saveGlobalDefaults,
                  child: Text(t.ai_config.save_global_button),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildDefaultModelSection(
              title: t.ai_config.summary_model_title,
              icon: Icons.compress_rounded,
              description: t.ai_config.summary_model_desc,
              value: _globalSummaryModel,
              items: allModels,
              onChanged: (val) {
                setState(() => _globalSummaryModel = val);
              },
            ),

            const SizedBox(height: 32),

            _buildDefaultModelSection(
              title: t.ai_config.dialogue_model_title,
              icon: Icons.chat_bubble_outline,
              description: t.ai_config.dialogue_model_desc,
              value: _globalDialogueModel,
              items: allModels,
              onChanged: (val) {
                setState(() => _globalDialogueModel = val);
              },
            ),

            const SizedBox(height: 24),

            _buildDefaultModelSection(
              title: t.ai_config.naming_model_title,
              icon: Icons.edit_outlined,
              description: t.ai_config.naming_model_desc,
              value: _globalNamingModel,
              items: allModels,
              onChanged: (val) {
                setState(() => _globalNamingModel = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
