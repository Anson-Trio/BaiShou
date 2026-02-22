import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 负责渲染供应商可用模型列表、启用状态 toggle 以及列表排序
class ProviderModelList extends ConsumerWidget {
  final AiProviderModel provider;
  final Widget Function(ProviderType) iconBuilder;

  /// 当模型列表为空时展示的回调（外部可借此触发获取逻辑）
  final VoidCallback onFetchRequested;

  /// 是否正在从网络获取模型中
  final bool isFetching;

  /// 当某个模型的开关被切换后通知父组件刷新
  final VoidCallback? onModelToggled;

  const ProviderModelList({
    super.key,
    required this.provider,
    required this.iconBuilder,
    required this.onFetchRequested,
    this.isFetching = false,
    this.onModelToggled,
  });

  /// 对模型列表进行排序：已开启的在最上面，其余按字母排序
  List<String> _getSortedModels() {
    final list = List<String>.from(provider.models);
    list.sort((a, b) {
      final aEnabled = provider.enabledModels.contains(a);
      final bEnabled = provider.enabledModels.contains(b);
      if (aEnabled == bEnabled) {
        return a.compareTo(b);
      }
      return aEnabled ? -1 : 1;
    });
    return list;
  }

  /// 切换指定模型的开启状态
  Future<void> _toggleModel(WidgetRef ref, String modelId, bool enable) async {
    final enabledList = List<String>.from(provider.enabledModels);
    if (enable) {
      if (!enabledList.contains(modelId)) enabledList.add(modelId);
    } else {
      enabledList.remove(modelId);
    }

    final updatedProvider = provider.copyWith(enabledModels: enabledList);
    await ref.read(apiConfigServiceProvider).updateProvider(updatedProvider);
    onModelToggled?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  '模型列表 (${provider.enabledModels.length} / ${provider.models.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: isFetching ? null : onFetchRequested,
              icon: isFetching
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

        if (provider.models.isEmpty)
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
              itemCount: provider.models.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
              itemBuilder: (context, index) {
                final sortedModels = _getSortedModels();
                final model = sortedModels[index];
                final isEnabled = provider.enabledModels.contains(model);

                return InkWell(
                  onTap: () => _toggleModel(ref, model, !isEnabled),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12, // Adjusted padding
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              iconBuilder(provider.type),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  model,
                                  style: TextStyle(
                                    fontWeight: isEnabled
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isEnabled
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isEnabled,
                          onChanged: (val) => _toggleModel(ref, model, val),
                          activeThumbColor: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
