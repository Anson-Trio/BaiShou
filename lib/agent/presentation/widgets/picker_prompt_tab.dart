/// 伙伴选择器 - 提示词 Tab（可编辑）
///
/// 系统提示词编辑 + 模型绑定选择

import 'package:baishou/agent/presentation/widgets/picker_shared_widgets.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PickerPromptTab extends ConsumerWidget {
  final TextEditingController promptController;
  final String? selectedProviderId;
  final String? selectedModelId;
  final VoidCallback onSave;
  final void Function(String? providerId, String? modelId) onModelSelected;
  final VoidCallback onModelCleared;

  const PickerPromptTab({
    super.key,
    required this.promptController,
    required this.selectedProviderId,
    required this.selectedModelId,
    required this.onSave,
    required this.onModelSelected,
    required this.onModelCleared,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 系统提示词（可编辑）
          PickerSectionHeader(
            icon: Icons.description_outlined,
            title: t.agent.assistant.prompt_label,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: promptController,
            maxLines: 8,
            onChanged: (_) => onSave(),
            decoration: InputDecoration(
              hintText: t.agent.assistant.prompt_hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.2),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),

          const SizedBox(height: 20),

          // 模型绑定（可编辑）
          PickerSectionHeader(
            icon: Icons.auto_awesome_outlined,
            title: t.agent.assistant.bind_model_label,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showModelPicker(context, ref),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedProviderId != null
                        ? Icons.link_rounded
                        : Icons.public_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: selectedProviderId != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedProviderId!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                selectedModelId ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            t.agent.assistant.use_global_model,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (selectedProviderId != null)
                    IconButton(
                      icon: Icon(Icons.close, size: 16,
                          color: colorScheme.outline),
                      onPressed: onModelCleared,
                      visualDensity: VisualDensity.compact,
                      tooltip: t.agent.assistant.use_global_model,
                    )
                  else
                    Icon(Icons.chevron_right,
                        color: colorScheme.outline, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showModelPicker(BuildContext context, WidgetRef ref) {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final providers =
        apiConfig.getProviders().where((p) => p.isEnabled).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        t.agent.assistant.select_model_title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                // 供应商 + 模型列表
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: providers.length,
                    itemBuilder: (ctx, i) {
                      final provider = providers[i];
                      final modelList = provider.enabledModels.isNotEmpty
                          ? provider.enabledModels
                          : provider.models;

                      return ExpansionTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _getProviderIcon(provider.id),
                        ),
                        title: Text(
                          provider.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${modelList.length} 模型',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: modelList.map((modelId) {
                          final isSelected =
                              selectedProviderId == provider.id &&
                              selectedModelId == modelId;
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            title: Text(
                              modelId,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.primary
                                    : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: colorScheme.primary, size: 18)
                                : null,
                            onTap: () {
                              onModelSelected(provider.id, modelId);
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                // 使用全局模型按钮
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        onModelCleared();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.public_rounded, size: 16),
                      label: Text(t.agent.assistant.use_global_model),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 根据供应商 ID 返回对应图标
  Widget _getProviderIcon(String providerId) {
    final id = providerId.toLowerCase();
    if (id.contains('openai')) {
      return Image.asset('assets/ai_provider_icon/openai.png',
          width: 24, height: 24);
    } else if (id.contains('gemini') || id.contains('google')) {
      return Image.asset('assets/ai_provider_icon/gemini-color.png',
          width: 24, height: 24);
    } else if (id.contains('anthropic') || id.contains('claude')) {
      return Image.asset('assets/ai_provider_icon/claude-color.png',
          width: 24, height: 24);
    } else if (id.contains('deepseek')) {
      return Image.asset('assets/ai_provider_icon/deepseek-color.png',
          width: 24, height: 24);
    } else if (id.contains('kimi') || id.contains('moonshot')) {
      return Image.asset('assets/ai_provider_icon/moonshot.png',
          width: 24, height: 24);
    }
    return const Icon(Icons.cloud_outlined, size: 24, color: Colors.grey);
  }
}
