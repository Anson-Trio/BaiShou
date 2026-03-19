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
import 'package:baishou/features/index/data/shadow_index_database.dart';

class MissingSummaryList extends ConsumerStatefulWidget {
  const MissingSummaryList({super.key});

  @override
  ConsumerState<MissingSummaryList> createState() => _MissingSummaryListState();
}

class _MissingSummaryListState extends ConsumerState<MissingSummaryList> {
  int _concurrencyLimit = 3;
  bool _isBatchProcessing = false;
  bool _cancelRequested = false;

  @override
  Widget build(BuildContext context) {
    // 检查影子索引库是否初始化完成，未就绪时不查询
    final dbState = ref.watch(shadowIndexDatabaseProvider);
    if (dbState is! AsyncData) return const SizedBox.shrink();

    // 监听 dataRefreshProvider 以在数据变更后触发 rebuild
    ref.watch(dataRefreshProvider);

    // FutureBuilder 放在最外层，实时查询数据库
    return FutureBuilder<List<MissingSummary>>(
      future: _safeGetAllMissing(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final missing = snapshot.data!;
        if (missing.isEmpty) return const SizedBox.shrink();

        // ValueListenableBuilder 只负责渲染生成进度，不触发重查
        return ValueListenableBuilder<Map<String, String>>(
          valueListenable: GenerationStateService().statusNotifier,
          builder: (context, generationStatus, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high_rounded,
                      size: 20,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.summary.ai_suggestions,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 批量生成按钮
                    FilledButton.tonal(
                      onPressed: _isBatchProcessing
                          ? () => setState(() => _cancelRequested = true)
                          : () => _batchGenerate(missing),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: _isBatchProcessing
                            ? Colors.red.withValues(alpha: 0.1)
                            : AppTheme.primary.withValues(alpha: 0.1),
                        foregroundColor: _isBatchProcessing
                            ? Colors.red
                            : AppTheme.primary,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isBatchProcessing) ...[
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _isBatchProcessing
                                ? (_cancelRequested
                                    ? t.summary.stopping
                                    : t.summary.stop_generating)
                                : t.summary.generate_all,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 并发设置
                    PopupMenuButton<int>(
                      initialValue: _concurrencyLimit,
                      tooltip: t.summary.concurrency_limit,
                      onSelected: (val) {
                        setState(() => _concurrencyLimit = val);
                      },
                      itemBuilder: (context) => [1, 2, 3, 4, 5].map((e) => PopupMenuItem(
                        value: e,
                        child: Text(t.summary.concurrency_count(count: e)),
                      )).toList(),
                      position: PopupMenuPosition.under,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.speed_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              t.summary.concurrency_count(count: _concurrencyLimit),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 数量标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t.common.count_items(count: missing.length),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 2 : 1,
                        mainAxisExtent: 96,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                      ),
                  itemCount: missing.length,
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
                    final theme = Theme.of(context);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // 1. 图标区域
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E5), // 浅橘色背景
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: Color(0xFFF28B50), // 橘色图标
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // 2. 文本区域
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${item.startDate.month}月${item.startDate.day}日 - ${item.endDate.month}月${item.endDate.day}日',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF4E5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        t.summary.suggestion_generate,
                                        style: const TextStyle(
                                          color: Color(0xFFF28B50),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (status != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isError
                                          ? Colors.red
                                          : AppTheme.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 3. 按钮区域
                          if (isLoading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Material(
                              color: isError
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : const Color(0xFFF2EFFF),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _generate(item),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    isError
                                        ? Icons.refresh_rounded
                                        : Icons.auto_fix_high_rounded,
                                    color: isError
                                        ? Colors.red
                                        : const Color(0xFF6C5CE7),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
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
    if (_isBatchProcessing) return;
    if (!_checkModelConfigured()) return;
    
    if (mounted) {
      setState(() {
        _isBatchProcessing = true;
        _cancelRequested = false;
      });
    }
    
    final queue = List<MissingSummary>.from(items);
    final List<Future<void>> workers = [];
    
    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancelRequested) {
        final item = queue.removeAt(0);
        await _generate(item, cancelCheck: () => _cancelRequested, isBatch: true);
      }
    }
    
    for (int i = 0; i < _concurrencyLimit; i++) {
       workers.add(worker());
    }
    
    await Future.wait(workers);
    
    // 批量全部完成后，统一刷新一次
    if (mounted) {
      ref.read(dataRefreshProvider.notifier).refresh();
      setState(() {
        _isBatchProcessing = false;
        _cancelRequested = false;
      });
    }
  }

  /// 安全查询缺失列表，数据库未就绪时返回空列表而不崩溃
  Future<List<MissingSummary>> _safeGetAllMissing() async {
    try {
      return await ref
          .read(missingSummaryDetectorProvider)
          .getAllMissing(LocaleSettings.currentLocale);
    } catch (_) {
      return [];
    }
  }

  Future<void> _generate(MissingSummary item, {bool Function()? cancelCheck, bool isBatch = false}) async {
    if (!_checkModelConfigured()) return;
    final key = item.label;
    final service = GenerationStateService();
    // 提前获取必要服务，避免跨 async gap 使用 ref
    final generator = ref.read(summaryGeneratorServiceProvider);
    final repository = ref.read(summaryRepositoryProvider);

    // 可以重新生成的"终态"状态集合（失败 / 空内容 / 等待重试）
    final retryableStatuses = {t.summary.tap_to_retry};
    final retryablePrefix = [
      t.summary.generation_failed,
      t.summary.content_empty,
    ];

    // 检查是否正在生成（允许在失败状态时重试）
    final currentStatus = service.getStatus(key);
    final isRetryable =
        currentStatus == null ||
        retryableStatuses.contains(currentStatus) ||
        retryablePrefix.any((p) => currentStatus.startsWith(p));
    if (!isRetryable) return;

    service.setStatus(key, t.summary.preparing);

    try {
      final stream = generator.generate(item);
      String finalContent = '';

      await for (final status in stream) {
        if (cancelCheck?.call() == true) {
          service.setStatus(key, t.summary.tap_to_retry);
          break;
        }
        // 使用明确的前缀判断
        if (status.startsWith('STATUS:')) {
          service.setStatus(key, status.substring(7)); // 移除 'STATUS:'
        } else {
          // 没有前缀的被视为最终内容
          finalContent = status;
        }
      }

      if (cancelCheck?.call() == true) {
        return; // 被手动取消，终止入库
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
        // 单条生成时立即刷新；批量生成时由 _batchGenerate 统一刷新
        if (!isBatch && mounted) {
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
