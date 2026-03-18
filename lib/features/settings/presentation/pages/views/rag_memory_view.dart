// RAG 记忆管理页面
//
// 展示所有已嵌入的向量条目，支持搜索、删除、统计

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/core/services/api_config_service.dart';
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
          // 标题
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

          // 统计信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildStatsRow(colorScheme, textTheme, totalCount),
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
      ],
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
