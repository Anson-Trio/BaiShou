import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/features/summary/domain/services/summary_generator_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/presentation/providers/generation_state_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MissingSummaryList extends ConsumerStatefulWidget {
  const MissingSummaryList({super.key});

  @override
  ConsumerState<MissingSummaryList> createState() => _MissingSummaryListState();
}

class _MissingSummaryListState extends ConsumerState<MissingSummaryList> {
  // 移除本地状态: AI生成状态
  // final Map<String, String> _generationStatus = {};

  @override
  Widget build(BuildContext context) {
    // 监听全局状态 (不再依赖 ref.watch)
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: GenerationStateService().statusNotifier,
      builder: (context, generationStatus, _) {
        return FutureBuilder<List<MissingSummary>>(
          future: ref.read(missingSummaryDetectorProvider).getAllMissing(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final missing = snapshot.data!;
            if (missing.isEmpty) return const SizedBox.shrink();

            return Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 20,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI 建议补全',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // 批量生成按钮
                        FilledButton.tonal(
                          onPressed: () => _batchGenerate(missing),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('全部生成'),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${missing.length}个',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: missing.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = missing[index];
                        final key = item.label;
                        final status = generationStatus[key];
                        final isError =
                            status != null &&
                            (status.startsWith('生成失败') ||
                                status.startsWith('内容为空'));
                        // 加载中：状态已设置且不是错误
                        final isLoading = status != null && !isError;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            item.label,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            status ??
                                '${item.startDate.month}月${item.startDate.day}日 - ${item.endDate.month}月${item.endDate.day}日',
                            style: TextStyle(
                              color: status != null
                                  ? (isError ? Colors.red : AppTheme.primary)
                                  : null,
                            ),
                          ),
                          trailing: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : FilledButton.tonal(
                                  onPressed: () => _generate(item),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    backgroundColor: isError
                                        ? Colors.red.withOpacity(0.1)
                                        : null,
                                    foregroundColor: isError
                                        ? Colors.red
                                        : null,
                                  ),
                                  child: Text(isError ? '重试' : '生成'),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 检查模型是否已配置且已启用，否则弹窗引导用户跳转设置
  bool _checkModelConfigured() {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final providerId = apiConfig.globalSummaryProviderId;
    final modelId = apiConfig.globalSummaryModelId;

    // 检查是否已配置
    if (providerId.isEmpty || modelId.isEmpty) {
      _showGoToSettingsDialog('模型未配置', '你还没有配置 AI 模型，无法生成总结。\n是否跳转到设置页面进行配置？');
      return false;
    }

    // 检查供应商是否已启用
    final provider = apiConfig.getProvider(providerId);
    if (provider == null || !provider.isEnabled) {
      _showGoToSettingsDialog(
        '模型服务已禁用',
        '当前配置的总结模型所属服务已被关闭（OFF）。\n请在设置中重新启用该服务，或更换一个可用的模型。',
      );
      return false;
    }

    return true;
  }

  /// 显示引导跳转到设置页的通用弹窗
  void _showGoToSettingsDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 根据设备类型选择正确的跳转方式：
              // 移动端：go 到 Shell 内的 /settings-mobile 路由，保留底边栏
              // 桌面端：push 到独立的 /settings 全屏页
              final isMobile = MediaQuery.of(context).size.width < 600;
              if (isMobile) {
                context.go('/settings-mobile');
              } else {
                context.push('/settings');
              }
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  Future<void> _batchGenerate(List<MissingSummary> items) async {
    if (!_checkModelConfigured()) return;
    for (final item in items) {
      _generate(item);
    }
  }

  Future<void> _generate(MissingSummary item) async {
    if (!_checkModelConfigured()) return;
    final key = item.label;
    final service = GenerationStateService();
    // 提前获取必要服务，避免跨 async gap 使用 ref
    final generator = ref.read(summaryGeneratorServiceProvider);
    final repository = ref.read(summaryRepositoryProvider);

    // 检查是否正在生成（允许在失败状态时重试）
    final currentStatus = service.getStatus(key);
    if (currentStatus != null &&
        !currentStatus.startsWith('生成失败') &&
        !currentStatus.startsWith('内容为空')) {
      return;
    }

    service.setStatus(key, '准备中...');

    try {
      final stream = generator.generate(item);
      String finalContent = '';

      await for (final status in stream) {
        // 使用明确的前缀判断
        if (status.startsWith('STATUS:')) {
          service.setStatus(key, status.substring(7)); // 移除 'STATUS:'
        } else {
          // 没有前缀的被视为最终内容
          finalContent = status;
        }
      }

      if (finalContent.isNotEmpty) {
        // 保存到数据库
        await repository.addSummary(
          type: item.type,
          startDate: item.startDate,
          endDate: item.endDate,
          content: finalContent,
        );

        service.removeStatus(key);
        // 触发全局刷新，更新付表板数量统计
        if (mounted) {
          ref.read(dataRefreshProvider.notifier).refresh();
        }
      } else {
        service.setStatus(key, '内容为空，点击重试');
        if (mounted) {
          AppToast.showError(context, '「${item.label}」生成内容为空，请重试');
        }
      }
    } catch (e) {
      service.setStatus(key, '生成失败，点击重试');
      if (mounted) {
        AppToast.showError(context, '「${item.label}」生成失败：$e');
      }
    }
  }
}
