import 'package:flutter/material.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 自定义模型选择器组件
/// 用于在全局设置中，以弹窗形式让用户从启用的供应商和模型列表中进行选择。
class CustomModelSelector extends StatelessWidget {
  final String title; // 选择器的标题（如：对话、命名）
  final String? selectedModelId; // 当前选中的模型标识符 (providerId:modelId)
  final List<Map<String, String>> availableModels; // 所有可用的模型列表
  final ValueChanged<String?> onModelSelected; // 选中后的回调

  const CustomModelSelector({
    super.key,
    required this.title,
    required this.selectedModelId,
    required this.availableModels,
    required this.onModelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String displayTitle = t.settings.select_model_title; // 按钮显示的标题
    String displaySubtitle = ''; // 按钮显示的副标题（供应商名称）

    if (selectedModelId != null && selectedModelId!.isNotEmpty) {
      final parts = selectedModelId!.split(':');
      if (parts.length >= 2) {
        displayTitle = parts.sublist(1).join(':'); // The specific model name

        // Find provider name
        final matchedItem = availableModels.firstWhere(
          (m) => '${m['provider_id']}:${m['model_id']}' == selectedModelId,
          orElse: () => {},
        );

        displaySubtitle = matchedItem.isNotEmpty
            ? matchedItem['provider_name'] ?? parts[0]
            : parts[0];
      }
    }

    return InkWell(
      onTap: availableModels.isEmpty
          ? null
          : () => _showSelectorDialog(context, colorScheme),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selectedModelId != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: selectedModelId != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displaySubtitle.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        displaySubtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.unfold_more_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示模型选择弹窗
  void _showSelectorDialog(BuildContext context, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Text(
                        t.settings.select_title(title: title),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: availableModels.length,
                    itemBuilder: (context, index) {
                      final item = availableModels[index];
                      final uniqueId =
                          '${item['provider_id']}:${item['model_id']}';
                      final isSelected = uniqueId == selectedModelId;

                      Widget providerIconWidget;

                      // 根据供应商 ID 匹配对应的图标
                      final providerIdLower =
                          item['provider_id']?.toLowerCase() ?? '';
                      if (providerIdLower.contains('openai')) {
                        providerIconWidget = Image.asset(
                          'assets/ai_provider_icon/openai.png',
                          width: 20,
                          height: 20,
                        );
                      } else if (providerIdLower.contains('gemini')) {
                        providerIconWidget = Image.asset(
                          'assets/ai_provider_icon/gemini-color.png',
                          width: 20,
                          height: 20,
                        );
                      } else if (providerIdLower.contains('anthropic') ||
                          providerIdLower.contains('claude')) {
                        providerIconWidget = Image.asset(
                          'assets/ai_provider_icon/claude-color.png',
                          width: 20,
                          height: 20,
                        );
                      } else if (providerIdLower.contains('deepseek')) {
                        providerIconWidget = Image.asset(
                          'assets/ai_provider_icon/deepseek-color.png',
                          width: 20,
                          height: 20,
                        );
                      } else if (providerIdLower.contains('kimi') ||
                          providerIdLower.contains('moonshot')) {
                        providerIconWidget = Image.asset(
                          'assets/ai_provider_icon/moonshot.png',
                          width: 20,
                          height: 20,
                        );
                      } else {
                        providerIconWidget = Icon(
                          Icons.cloud_outlined,
                          color: Colors.grey.shade700,
                          size: 20,
                        );
                      }

                      return InkWell(
                        onTap: () {
                          onModelSelected(uniqueId);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          color: isSelected
                              ? colorScheme.primaryContainer.withOpacity(0.3)
                              : null,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: providerIconWidget,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['model_id'] ?? '',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['provider_name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
