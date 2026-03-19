import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
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
  String? _globalEmbeddingModel;
  String _monthlySummarySource = 'weeklies'; // 月度总结数据源

  @override
  void initState() {
    super.initState();
    // 渲染完成后加载配置 + 检查挂起迁移
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProviderConfig();
      _checkPendingMigration();
    });
  }

  /// 检查是否有上次未完成的嵌入迁移（崩溃恢复）
  Future<void> _checkPendingMigration() async {
    final embeddingService = ref.read(embeddingServiceProvider);
    final hasPending = await embeddingService.hasPendingMigration();
    if (!hasPending || !mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('检测到未完成的迁移'),
        content: const Text(
          '上次嵌入模型迁移未完成（可能是应用异常退出）。\n\n'
          '是否继续迁移？备份数据仍然安全。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _continuePendingMigration();
            },
            child: const Text('继续迁移'),
          ),
        ],
      ),
    );
  }

  /// 继续上次未完成的迁移
  void _continuePendingMigration() {
    final embeddingService = ref.read(embeddingServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    embeddingService.continueMigration().listen(
      (progress) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(progress.status),
            duration: progress.isDone
                ? const Duration(seconds: 3)
                : const Duration(seconds: 30),
          ),
        );
      },
      onError: (e) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('迁移出错: $e')),
        );
      },
    );
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
      _globalEmbeddingModel = _buildGlobalIdentifier(
        service.globalEmbeddingProviderId,
        service.globalEmbeddingModelId,
      );
      _monthlySummarySource = service.monthlySummarySource;
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

    // 解析并保存 Embedding 模型（检测模型是否变化）
    if (_globalEmbeddingModel != null && _globalEmbeddingModel!.isNotEmpty) {
      final parts = _globalEmbeddingModel!.split(':');
      if (parts.length >= 2) {
        final newProviderId = parts[0];
        final newModelId = parts.sublist(1).join(':');
        final oldModelId = service.globalEmbeddingModelId;

        await service.setGlobalEmbeddingModel(newProviderId, newModelId);

        // 模型变化且旧模型非空 → 询问是否重新嵌入
        if (oldModelId.isNotEmpty && oldModelId != newModelId) {
          _promptMigration(service);
        }
      }
    }

    if (mounted) {
      AppToast.showSuccess(context, t.ai_config.global_models_updated);
    }
  }

  /// 弹出确认框，询问是否重新嵌入全量向量
  void _promptMigration(ApiConfigService service) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('嵌入模型已更换'),
        content: const Text(
          '检测到您更换了嵌入模型。\n\n'
          '旧的向量数据与新模型维度不兼容，需要重新嵌入所有数据。\n\n'
          '此操作会：\n'
          '• 备份现有文本元数据\n'
          '• 清空旧向量并用新模型重新嵌入\n'
          '• 完成后自动校验数据完整性\n\n'
          '过程在后台异步执行，不影响正常使用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startMigration();
            },
            child: const Text('立即重新嵌入'),
          ),
        ],
      ),
    );
  }

  /// 启动异步迁移并显示进度
  void _startMigration() {
    final embeddingService = ref.read(embeddingServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在准备重新嵌入...'),
        duration: Duration(seconds: 2),
      ),
    );

    embeddingService.migrateEmbeddings().listen(
      (progress) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(progress.status),
            duration: progress.isDone
                ? const Duration(seconds: 3)
                : const Duration(seconds: 30),
          ),
        );
      },
      onError: (e) {
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('迁移出错: $e')),
        );
      },
    );
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
    final nonEmbeddingModels = service.getAllNonEmbeddingModels();
    final embeddingModels = service.getAllEmbeddingModels();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
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
              items: nonEmbeddingModels,
              onChanged: (val) {
                setState(() => _globalSummaryModel = val);
              },
            ),

            const SizedBox(height: 16),

            // 月度总结数据源选项
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.35),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.source_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t.settings.monthly_summary_data_source,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.settings.monthly_summary_data_source_desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'weeklies',
                        label: Text(t.settings.read_only_weeklies),
                        icon: const Icon(
                          Icons.calendar_view_week_rounded,
                          size: 16,
                        ),
                      ),
                      ButtonSegment(
                        value: 'diaries',
                        label: Text(t.settings.read_all_diaries),
                        icon: const Icon(Icons.article_outlined, size: 16),
                      ),
                    ],
                    selected: {_monthlySummarySource},
                    onSelectionChanged: (sel) async {
                      final chosen = sel.first;
                      setState(() => _monthlySummarySource = chosen);
                      await ref
                          .read(apiConfigServiceProvider)
                          .setMonthlySummarySource(chosen);
                    },
                    style: ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildDefaultModelSection(
              title: t.ai_config.dialogue_model_title,
              icon: Icons.chat_bubble_outline,
              description: t.ai_config.dialogue_model_desc,
              value: _globalDialogueModel,
              items: nonEmbeddingModels,
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
              items: nonEmbeddingModels,
              onChanged: (val) {
                setState(() => _globalNamingModel = val);
              },
            ),

            const SizedBox(height: 32),

            _buildDefaultModelSection(
              title: t.ai_config.embedding_model_title,
              icon: Icons.hub_outlined,
              description: t.ai_config.embedding_model_desc,
              value: _globalEmbeddingModel,
              items: embeddingModels,
              onChanged: (val) {
                setState(() => _globalEmbeddingModel = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
