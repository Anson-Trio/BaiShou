// RAG 记忆管理页面
//
// 展示所有已嵌入的向量条目，支持搜索、删除、统计

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class RagMemoryView extends ConsumerStatefulWidget {
  const RagMemoryView({super.key});

  @override
  ConsumerState<RagMemoryView> createState() => _RagMemoryViewState();
}

class _RagMemoryViewState extends ConsumerState<RagMemoryView> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isDetectingDimension = false;
  bool _isBatchEmbedding = false;
  int _batchProgress = 0;
  int _batchTotal = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(agentDatabaseProvider);
      final stats = await db.getEmbeddingStats();
      final entries = await db.getAllEmbeddingChunks();
      setState(() {
        _stats = stats;
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.rag.clear_all_title),
        content: Text(t.agent.rag.clear_all_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.agent.rag.clear_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final embeddingService = ref.read(embeddingServiceProvider);
      await embeddingService.clearAllEmbeddings();
      await _loadData();
    }
  }

  Future<void> _deleteEntry(String embeddingId) async {
    final db = ref.read(agentDatabaseProvider);
    await db.deleteEmbeddingById(embeddingId);
    await _loadData();
  }

  List<Map<String, dynamic>> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries.where((e) {
      final text = (e['chunk_text'] as String?)?.toLowerCase() ?? '';
      final model = (e['model_id'] as String?)?.toLowerCase() ?? '';
      return text.contains(q) || model.contains(q);
    }).toList();
  }

  /// 手动触发维度检测
  Future<void> _detectDimension() async {
    setState(() => _isDetectingDimension = true);
    try {
      final embeddingService = ref.read(embeddingServiceProvider);
      await ref.read(apiConfigServiceProvider).setGlobalEmbeddingDimension(0);
      final dimension = await embeddingService.detectDimension();
      if (mounted) {
        if (dimension > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检测成功：${dimension}维'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('检测失败，请检查模型配置'), backgroundColor: Colors.red),
          );
        }
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检测失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingDimension = false);
    }
  }

  /// 清空当前维度的向量
  Future<void> _clearCurrentDimension() async {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final dimension = apiConfig.globalEmbeddingDimension;
    if (dimension <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前未配置维度，无法清空')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空当前维度向量'),
        content: Text('确定要删除所有 ${dimension} 维的向量数据吗？\n其他维度的数据不受影响。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.common.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(agentDatabaseProvider);
      final deleted = await db.clearEmbeddingsByDimension(dimension);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 $deleted 条 ${dimension}维 向量数据')),
        );
        await _loadData();
      }
    }
  }

  /// 批量嵌入所有日记
  Future<void> _batchEmbedDiaries() async {
    final embeddingService = ref.read(embeddingServiceProvider);
    if (!embeddingService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 Embedding 模型'), backgroundColor: Colors.orange),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('全量嵌入日记'),
        content: const Text('将读取所有日记内容并生成向量嵌入。\n已存在的日记不会重复嵌入。\n过程可能需要一些时间。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.common.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('开始嵌入')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isBatchEmbedding = true;
      _batchProgress = 0;
    });

    try {
      final diaryRepo = ref.read(diaryRepositoryProvider);
      final diaries = await diaryRepo.getAllDiaries();
      setState(() => _batchTotal = diaries.length);

      int embedded = 0;
      for (final diary in diaries) {
        if (!mounted) break;
        if (diary.content.trim().isEmpty) {
          setState(() => _batchProgress++);
          continue;
        }
        await embeddingService.embedText(
          text: '${diary.date}: ${diary.content}',
          sessionId: 'diary_batch',
          customId: 'diary_${diary.id}',
        );
        embedded++;
        if (mounted) setState(() => _batchProgress++);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('完成！已嵌入 $embedded 篇日记'), backgroundColor: Colors.green),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量嵌入出错: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBatchEmbedding = false;
          _batchProgress = 0;
          _batchTotal = 0;
        });
      }
    }
  }

  /// 手动添加记忆
  Future<void> _addManualMemory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加记忆'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '输入要记住的内容...\n例如：Anson喜欢喝危地马拉咖啡',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.common.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final embeddingService = ref.read(embeddingServiceProvider);
      if (!embeddingService.isConfigured) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先配置 Embedding 模型'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await embeddingService.embedText(
        text: result.trim(),
        sessionId: 'manual_memory',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记忆已保存并嵌入'), backgroundColor: Colors.green),
        );
        await _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalCount = _stats['total_count'] as int? ?? 0;

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 全局开关
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 8),
            child: Row(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 28,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  t.agent.rag.title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                // 全局记忆开关
                Switch(
                  value: ref.read(apiConfigServiceProvider).ragEnabled,
                  onChanged: (v) async {
                    await ref.read(apiConfigServiceProvider).setRagEnabled(v);
                    setState(() {});
                  },
                ),
                const Spacer(),
                if (totalCount > 0)
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: Icon(Icons.delete_sweep_outlined,
                        size: 18, color: colorScheme.error),
                    label: Text(t.agent.rag.clear_all,
                        style: TextStyle(color: colorScheme.error)),
                  ),
              ],
            ),
          ),

          // RAG 关闭提示
          if (!ref.read(apiConfigServiceProvider).ragEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      '全局记忆已关闭，Agent将不会使用RAG检索',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 统计信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildStatsRow(colorScheme, textTheme, totalCount),
          ),

          const SizedBox(height: 12),

          // 操作按钮行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 清空当前维度
                _ActionChip(
                  icon: Icons.layers_clear,
                  label: '清空当前维度',
                  color: colorScheme.error,
                  onTap: _clearCurrentDimension,
                ),
                // 全量嵌入日记
                _ActionChip(
                  icon: Icons.auto_stories,
                  label: _isBatchEmbedding
                      ? '嵌入中 $_batchProgress/$_batchTotal'
                      : '全量嵌入日记',
                  color: colorScheme.primary,
                  onTap: _isBatchEmbedding ? null : _batchEmbedDiaries,
                  isLoading: _isBatchEmbedding,
                ),
                // 手动添加记忆
                _ActionChip(
                  icon: Icons.add_comment_outlined,
                  label: '手动添加记忆',
                  color: colorScheme.tertiary,
                  onTap: _addManualMemory,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t.agent.rag.search_hint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          const SizedBox(height: 12),

          // 条目列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? _buildEmptyState(colorScheme, textTheme)
                    : _buildEntryList(colorScheme, textTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
      ColorScheme colorScheme, TextTheme textTheme, int totalCount) {
    // 从 DB 统计读取模型，空时回退到全局配置
    var modelDisplay = (_stats['models'] as List?)
            ?.map((m) => (m as Map)['model_id'] ?? '')
            .where((s) => (s as String).isNotEmpty)
            .toSet()
            .join(', ') ??
        '';
    if (modelDisplay.isEmpty) {
      final apiConfig = ref.read(apiConfigServiceProvider);
      final configuredModel = apiConfig.globalEmbeddingModelId;
      modelDisplay = configuredModel.isNotEmpty ? configuredModel : t.common.not_configured;
    }
    final dimension = _stats['dimension_count'] as int? ?? 0;
    // 也从配置读维度
    final configDimension = ref.read(apiConfigServiceProvider).globalEmbeddingDimension;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _StatChip(
          icon: Icons.layers_outlined,
          label: t.agent.rag.stat_total,
          value: '$totalCount',
          color: colorScheme.primary,
        ),
        _StatChip(
          icon: Icons.model_training_outlined,
          label: t.agent.rag.stat_model,
          value: modelDisplay,
          color: colorScheme.tertiary,
        ),
        if (dimension > 0 || configDimension > 0)
          _StatChip(
            icon: Icons.straighten_outlined,
            label: t.agent.rag.stat_dimension,
            value: '${dimension > 0 ? dimension : configDimension}',
            color: colorScheme.secondary,
          ),
        // 维度自动检测状态
        _buildDimensionStatusChip(colorScheme, configDimension),
      ],
    );
  }

  /// 构建维度自动检测状态芯片
  Widget _buildDimensionStatusChip(ColorScheme colorScheme, int configDimension) {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final hasModel = apiConfig.hasEmbeddingModel;

    if (configDimension > 0) {
      // 已检测到维度
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              '自动检测: ${configDimension}维',
              style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    } else if (hasModel) {
      // 已配置模型但未检测 — 可点击手动检测
      return GestureDetector(
        onTap: _isDetectingDimension ? null : _detectDimension,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isDetectingDimension)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange.shade700,
                    ),
                  )
                else
                  Icon(Icons.play_circle_outline, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  _isDetectingDimension ? '正在检测...' : '点击检测维度',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // 未配置Embedding模型
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_outlined, size: 14, color: Colors.red.shade700),
            const SizedBox(width: 4),
            Text(
              '未配置Embedding模型',
              style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.memory_outlined,
            size: 64,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '还没有记忆数据' : '未找到匹配的记忆',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '与 Agent 对话后，记忆会自动存储到这里',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(ColorScheme colorScheme, TextTheme textTheme) {
    final entries = _filteredEntries;
    final dateFormat = DateFormat('MM/dd HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final text = entry['chunk_text'] as String? ?? '';
        final model = entry['model_id'] as String? ?? '';
        final embeddingId = entry['embedding_id'] as String? ?? '';
        final createdAt = entry['created_at'] as String?;
        final timeStr =
            createdAt != null ? dateFormat.format(DateTime.parse(createdAt)) : '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          color: colorScheme.surfaceContainerLow,
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Icon(
              Icons.data_object_rounded,
              size: 18,
              color: colorScheme.primary.withValues(alpha: 0.6),
            ),
            title: Text(
              text.length > 80 ? '${text.substring(0, 80)}...' : text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                height: 1.4,
              ),
            ),
            subtitle: Text(
              '$model · $timeStr',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
              onPressed: () => _deleteEntry(embeddingId),
              tooltip: t.agent.rag.delete_tooltip,
            ),
          ),
        );
      },
    );
  }
}

// ─── 统计指标 chip ──────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作按钮 Chip
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
