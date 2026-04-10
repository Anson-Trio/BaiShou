import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/rag/batch_embedding_progress.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:baishou/features/settings/presentation/pages/views/rag_memory_dialogs.dart';
import 'package:baishou/features/settings/presentation/pages/views/rag_memory_widgets.dart';
import 'package:baishou/core/widgets/app_toast.dart';

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
  bool _hasMismatchModel = false;
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
      final embeddingService = ref.read(embeddingServiceProvider);
      final stats = await db.getEmbeddingStats();
      final entries = await db.getAllEmbeddingChunks();

      _stats = stats;
      _entries = entries;
      _hasMismatchModel = await embeddingService.hasHeterogeneousEmbeddings();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading RAG stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearAll() async {
    final success = await RagMemoryDialogs.clearAll(context, ref);
    if (success) await _loadData();
  }

  Future<void> _deleteEntry(String embeddingId) async {
    final db = ref.read(agentDatabaseProvider);
    await db.deleteEmbeddingById(embeddingId);
    await _loadData();
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final success = await RagMemoryDialogs.editMemory(context, ref, entry);
    if (success && mounted) await _loadData();
  }

  void _showFullContent(String text, String model, String timeStr) {
    RagMemoryDialogs.showFullContent(context, text, model, timeStr);
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

  Future<void> _detectDimension() async {
    setState(() => _isDetectingDimension = true);
    await RagMemoryDialogs.detectDimension(context, ref);
    if (mounted) {
      setState(() => _isDetectingDimension = false);
      await _loadData();
    }
  }

  Future<void> _clearCurrentDimension() async {
    final success = await RagMemoryDialogs.clearCurrentDimension(context, ref);
    if (success && mounted) await _loadData();
  }

  Future<void> _batchEmbedDiaries() async {
    final success = await RagMemoryDialogs.batchEmbedDiaries(
      context: context,
      ref: ref,
    );

    if (mounted && success) await _loadData();
  }

  Future<void> _addManualMemory() async {
    final success = await RagMemoryDialogs.addManualMemory(context, ref);
    if (success && mounted) await _loadData();
  }

  void _triggerMigration() {
    RagMemoryDialogs.startMigration(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    // 监听进度状态变化，一旦结束迁移或嵌入，自动重新加载数据
    ref.listen(ragProgressProvider, (previous, next) {
      if (previous != null && previous.isRunning && !next.isRunning) {
        _loadData();
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalCount = _stats['total_count'] as int? ?? 0;
    final ragState = ref.watch(ragProgressProvider);
    final isBatchEmbedding =
        ragState.isRunning && ragState.type == RagProgressType.batchEmbed;
    final isMigrating =
        ragState.isRunning && ragState.type == RagProgressType.migration;
    final isBusy = ragState.isRunning;

    return Container(
      color: colorScheme.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题 + 全局开关
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.color_lens,
                        size: 24,
                        color: colorScheme.primary,
                      ),
                      Text(
                        t.agent.rag.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // 全局记忆开关
                      Switch(
                        value: ref.watch(apiConfigServiceProvider).ragEnabled,
                        onChanged: (v) async {
                          await ref
                              .read(apiConfigServiceProvider)
                              .setRagEnabled(v);
                          setState(() {});
                          
                          if (v) {
                            final isOk = await ref.read(embeddingServiceProvider).testConnection();
                            if (!isOk && mounted) {
                              AppToast.showError(context, t.agent.rag.probe_failed);
                            }
                          }
                        },
                      ),
                      if (totalCount > 0)
                        TextButton.icon(
                          onPressed: _clearAll,
                          icon: Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                            color: colorScheme.error,
                          ),
                          label: Text(
                            t.agent.rag.clear_all,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                ),

                // RAG 关闭提示
                if (!ref.watch(apiConfigServiceProvider).ragEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.agent.rag.rag_disabled_hint,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: RagMemoryStatsBoard(
                    totalCount: totalCount,
                    stats: _stats,
                    isDetectingDimension: _isDetectingDimension,
                    onDetectDimension: _detectDimension,
                  ),
                ),

                const SizedBox(height: 12),

                // RAG 检索参数调节
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: RagMemoryRetrievalConfig(),
                ),

                const SizedBox(height: 12),

                // 如果正在进行模型迁移，显示专门的进度高亮区域
                if (isMigrating)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t.agent.rag.migration_preparing,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ragState.statusText.isNotEmpty
                                ? ragState.statusText
                                : '...',
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: ragState.total > 0
                                ? (ragState.progress / ragState.total).clamp(
                                    0.0,
                                    1.0,
                                  )
                                : null,
                            backgroundColor: colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_hasMismatchModel)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t.agent.rag.migration_mismatch_title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.agent.rag.migration_mismatch_content,
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            ),
                            onPressed: _triggerMigration,
                            icon: const Icon(Icons.sync, size: 16),
                            label: Text(t.agent.rag.migration_continue),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 操作按钮行
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 清空当前维度
                      RagActionChip(
                        icon: Icons.layers_clear,
                        label: t.agent.rag.action_clear_dimension,
                        color: isBusy ? colorScheme.outline : colorScheme.error,
                        onTap: isBusy ? null : _clearCurrentDimension,
                      ),
                      // 全量嵌入日记
                      RagActionChip(
                        icon: Icons.auto_stories,
                        label: isBatchEmbedding
                            ? t.agent.rag.batch_embed_progress(
                                progress: ragState.progress.toString(),
                                total: ragState.total.toString(),
                              )
                            : t.agent.rag.action_batch_embed,
                        color: isBusy
                            ? colorScheme.outline
                            : colorScheme.primary,
                        onTap: isBusy ? null : _batchEmbedDiaries,
                        isLoading: isBatchEmbedding,
                      ),
                      // 手动添加记忆
                      RagActionChip(
                        icon: Icons.add_comment_outlined,
                        label: t.agent.rag.action_add_memory,
                        color: isBusy
                            ? colorScheme.outline
                            : colorScheme.tertiary,
                        onTap: isBusy ? null : _addManualMemory,
                      ),
                      // 手动重置迁移
                      RagActionChip(
                        icon: Icons.sync,
                        label: "手动迁移模型配置",
                        color: isBusy
                            ? colorScheme.outline
                            : colorScheme.secondary,
                        onTap: isBusy ? null : _triggerMigration,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 搜索框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: t.agent.rag.search_hint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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

                // 加载态或空状态
                if (_isLoading || _filteredEntries.isEmpty)
                  SizedBox(
                    height: 300,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildEmptyState(colorScheme, textTheme),
                  ),
              ],
            ),
          ),

          // 条目列表 Sliver
          if (!_isLoading && _filteredEntries.isNotEmpty)
            _buildSliverEntryList(colorScheme, textTheme),
        ],
      ),
    );
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
            _searchQuery.isEmpty
                ? t.agent.rag.no_memories_yet
                : t.agent.rag.no_memories_match,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Text(
            t.agent.rag.memories_auto_hint,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.outline.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverEntryList(ColorScheme colorScheme, TextTheme textTheme) {
    final entries = _filteredEntries;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = entries[index];
          final text = entry['chunk_text'] as String? ?? '';
          final model = entry['model_id'] as String? ?? '';
          final embeddingId = entry['embedding_id'] as String? ?? '';
          final createdAt = entry['created_at'] as int?;
          final dateFormat = DateFormat('MM/dd HH:mm');
          final timeStr = createdAt != null
              ? dateFormat.format(
                  DateTime.fromMillisecondsSinceEpoch(createdAt),
                )
              : '';
          return MemoryEntryCard(
            entry: entry,
            onDelete: () => _deleteEntry(embeddingId),
            onEdit: () => _editEntry(entry),
            onTap: () => _showFullContent(text, model, timeStr),
          );
        }, childCount: entries.length),
      ),
    );
  }
}
