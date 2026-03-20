import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 总结设置页面
/// 包含月度总结数据源选择和提示词模板编辑
class SummarySettingsView extends ConsumerStatefulWidget {
  const SummarySettingsView({super.key});

  @override
  ConsumerState<SummarySettingsView> createState() =>
      _SummarySettingsViewState();
}

class _SummarySettingsViewState extends ConsumerState<SummarySettingsView> {
  String _monthlySummarySource = 'weeklies';

  // 提示词模板编辑控制器
  late TextEditingController _instructionsController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _instructionsController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  void _loadConfig() {
    final service = ref.read(apiConfigServiceProvider);

    setState(() {
      _monthlySummarySource = service.monthlySummarySource;
      _initialized = true;
    });

    _instructionsController.text =
        service.summaryInstructions ?? '**重要指令**：禁止输出任何问候语、开场白或结束语。直接输出纯 Markdown 内容。';
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
          // ── 月度总结数据源 ──
          _buildSectionCard(
            theme: theme,
            icon: Icons.source_outlined,
            title: t.settings.monthly_summary_data_source,
            description: t.settings.monthly_summary_data_source_desc,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'weeklies',
                  label: Text(t.settings.read_only_weeklies),
                  icon: const Icon(Icons.calendar_view_week_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'diaries',
                  label: Text(t.settings.read_all_diaries),
                  icon: const Icon(Icons.article_outlined, size: 16),
                ),
              ],
              selected: {_monthlySummarySource},
              onSelectionChanged: (sel) async {
                final chosen = sel.first;
                setState(() => _monthlySummarySource = chosen);
                await ref
                    .read(apiConfigServiceProvider)
                    .setMonthlySummarySource(chosen);
              },
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),

          const SizedBox(height: 16),

          // ── AI 提示词 ──
          _buildSectionCard(
            theme: theme,
            icon: Icons.rule_rounded,
            title: t.settings.summary_ai_prompt_title,
            description: t.settings.summary_ai_prompt_desc,
            child: Column(
              children: [
                TextField(
                  controller: _instructionsController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: t.settings.summary_ai_prompt_hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _buildSaveResetRow(
                  onSave: () async {
                    await ref
                        .read(apiConfigServiceProvider)
                        .setSummaryInstructions(
                            _instructionsController.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.settings.saved)),
                      );
                    }
                  },
                  onReset: () {
                    _instructionsController.text =
                        '**重要指令**：禁止输出任何问候语、开场白或结束语。直接输出纯 Markdown 内容。';
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 提示信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.settings.summary_instructions_desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSaveResetRow({
    required VoidCallback onSave,
    required VoidCallback onReset,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onReset,
          child: Text(t.settings.restore_default),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: onSave,
          child: Text(t.common.save),
        ),
      ],
    );
  }
}
