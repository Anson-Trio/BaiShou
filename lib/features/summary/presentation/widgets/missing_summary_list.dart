import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/features/summary/domain/services/summary_generator_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/presentation/providers/generation_state_service.dart'; // Import service
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                            (status.startsWith('错误') ||
                                status.startsWith('生成内容为空'));
                        // Loading: status is set and not an error
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

  Future<void> _batchGenerate(List<MissingSummary> items) async {
    for (final item in items) {
      _generate(item);
    }
  }

  Future<void> _generate(MissingSummary item) async {
    final key = item.label;
    final service = GenerationStateService();
    // 提前获取 necessary services，避免跨 async gap 使用 ref
    final generator = ref.read(summaryGeneratorServiceProvider);
    final repository = ref.read(summaryRepositoryProvider);

    // Check if already generating (but allow retry if error or empty)
    final currentStatus = service.getStatus(key);
    if (currentStatus != null &&
        !currentStatus.startsWith('错误') &&
        !currentStatus.startsWith('生成内容为空')) {
      return;
    }

    service.setStatus(key, '准备中...');

    try {
      final stream = generator.generate(item);
      String finalContent = '';

      await for (final status in stream) {
        // 使用明确的前缀判断
        if (status.startsWith('STATUS:')) {
          service.setStatus(key, status.substring(7)); // remove 'STATUS:'
        } else {
          // 没有前缀的被视为最终内容
          finalContent = status;
        }
      }

      if (finalContent.isNotEmpty) {
        // Save to DB
        await repository.addSummary(
          type: item.type,
          startDate: item.startDate,
          endDate: item.endDate,
          content: finalContent,
        );

        service.removeStatus(key);
        if (mounted) setState(() {}); // 触发 FutureBuilder 刷新列表
      } else {
        service.setStatus(key, '生成内容为空');
      }
    } catch (e) {
      service.setStatus(key, '错误: $e');
    }
  }
}
