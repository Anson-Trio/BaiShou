import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/features/summary/domain/services/summary_generator_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MissingSummaryList extends ConsumerStatefulWidget {
  const MissingSummaryList({super.key});

  @override
  ConsumerState<MissingSummaryList> createState() => _MissingSummaryListState();
}

class _MissingSummaryListState extends ConsumerState<MissingSummaryList> {
  final Map<String, String> _generationStatus = {}; // key -> 状态消息

  @override
  Widget build(BuildContext context) {
    // 1. 获取缺失的总结
    // 我们使用 FutureBuilder/StreamBuilder 或者在 initState/didChangeDependencies 中调用 detector?
    // 更好方式: Helper provider.
    // 但 detector 是一个 service，不是状态 provider。
    // 暂时使用 FutureBuilder。

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
                    Icon(Icons.auto_awesome, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'AI 建议补全',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
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
                        '${missing.length}个待生成',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary),
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
                    final key = item.label; // Simple key
                    final status = _generationStatus[key];

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
                          color: status != null ? AppTheme.primary : null,
                        ),
                      ),
                      trailing: status != null
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.tonal(
                              onPressed: () => _generate(item),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: const Text('生成'),
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
  }

  Future<void> _generate(MissingSummary item) async {
    final key = item.label;
    setState(() {
      _generationStatus[key] = '准备中...';
    });

    try {
      final stream = ref.read(summaryGeneratorServiceProvider).generate(item);
      String finalContent = '';

      await for (final status in stream) {
        // 检查 status 是像内容（长文本）还是仅仅是消息
        // 我们的 service yield 消息，最后 yield 内容。
        // 但“内容”通常是长逻辑。
        // 假设内容以已知的 markdown 标题开头或长度 > 100？
        // 目前看 service，它 yield 'Reading...', 'Thinking...', 然后 'Content...'。
        // 我们可以通过流关闭来检测是否是最终内容？
        // 实际上 await for 循环直到流关闭。
        // 但我们需要区分中间状态和最终结果。

        // 临时处理: 如果长度 > 50 且包含 '#'，则认为是内容。
        if (status.length > 50 && status.contains('#')) {
          finalContent = status;
        } else {
          if (mounted) {
            setState(() {
              _generationStatus[key] = status;
            });
          }
        }
      }

      if (finalContent.isNotEmpty) {
        // Save to DB
        await ref
            .read(summaryRepositoryProvider)
            .addSummary(
              type: item.type,
              startDate: item.startDate,
              endDate: item.endDate,
              content: finalContent,
            );

        if (mounted) {
          setState(() {
            _generationStatus.remove(key);
            // 决定是否刷新列表？
            // FutureBuilder 不会自动刷新，除非我们要么调用 setState 触发重建
            // 并且 future provider 被重新调用。
            // 但逻辑匹配：setState 触发 build，build 调用 getAllMissing()。
            // getAllMissing 检查数据库。
            // 我们刚刚写入了数据库。所以 getAllMissing 应该不会再返回这个项目了。
          });
        }
      } else {
        if (mounted) {
          setState(() => _generationStatus[key] = '生成内容为空');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generationStatus[key] = '错误: $e');
      }
    }
  }
}
