import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/services/data_refresh_notifier.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/features/summary/domain/services/summary_generator_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/presentation/providers/generation_state_service.dart';
import 'package:baishou/i18n/strings.g.dart';
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
          future: ref
              .read(missingSummaryDetectorProvider)
              .getAllMissing(LocaleSettings.currentLocale),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t.summary.ai_suggestions,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // 批量生成按钮
                        FilledButton.tonal(
                          onPressed: () => _batchGenerate(missing),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(t.summary.generate_all),
                        ),
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
                            t.common.count_items(count: missing.length),
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
                            (status.startsWith(t.summary.generation_failed) ||
                                status.startsWith(t.summary.content_empty) ||
                                status == t.summary.tap_to_retry);
                        // 加载中：状态已设置且不是错误
                        final isLoading = status != null && !isError;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            item.label,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            status ??
                                '${item.startDate.year}/${item.startDate.month}/${item.startDate.day} - ${item.endDate.month}/${item.endDate.day}',
                            style: TextStyle(
                              color: status != null
                                  ? (isError ? Colors.red : AppTheme.primary)
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 70,
                                  ),
                                  child: FilledButton.tonal(
                                    onPressed: () => _generate(item),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      backgroundColor: isError
                                          ? Colors.red.withOpacity(0.1)
                                          : null,
                                      foregroundColor: isError
                                          ? Colors.red
                                          : null,
                                    ),
                                    child: Text(
                                      isError
                                          ? t.common.retry
                                          : t.common.generate,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
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
      _showGoToSettingsDialog(
        t.summary.model_not_configured,
        t.summary.model_not_configured_desc,
      );
      return false;
    }

    // 检查供应商是否已启用
    final provider = apiConfig.getProvider(providerId);
    if (provider == null || !provider.isEnabled) {
      _showGoToSettingsDialog(
        t.summary.service_disabled,
        t.summary.service_disabled_desc,
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
            child: Text(t.common.cancel),
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
            child: Text(t.settings.go_to_settings),
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
        !currentStatus.startsWith(t.summary.generation_failed) &&
        !currentStatus.startsWith(t.summary.content_empty)) {
      return;
    }

    service.setStatus(key, t.summary.preparing);

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
        service.setStatus(key, t.summary.tap_to_retry);
        if (mounted) {
          AppToast.showError(
            context,
            t.summary.empty_content_error(label: item.label),
          );
        }
      }
    } catch (e) {
      service.setStatus(key, t.summary.tap_to_retry);
      if (mounted) {
        AppToast.showError(
          context,
          t.summary.generation_failed_error(label: item.label, e: e.toString()),
        );
      }
    }
  }
}
