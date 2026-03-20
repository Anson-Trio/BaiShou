import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/agent/prompts/prompt_templates.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 总结设置页面
/// 包含月度总结数据源选择和分类型提示词模板编辑
class SummarySettingsView extends ConsumerStatefulWidget {
  const SummarySettingsView({super.key});

  @override
  ConsumerState<SummarySettingsView> createState() =>
      _SummarySettingsViewState();
}

class _SummarySettingsViewState extends ConsumerState<SummarySettingsView>
    with SingleTickerProviderStateMixin {
  String _monthlySummarySource = 'weeklies';
  bool _initialized = false;


  // 4 种总结类型
  static const _types = ['weekly', 'monthly', 'quarterly', 'yearly'];
  static const _typeIcons = [
    Icons.calendar_view_week_rounded,
    Icons.calendar_month_rounded,
    Icons.date_range_rounded,
    Icons.calendar_today_rounded,
  ];

  late TabController _tabController;
  final Map<String, TextEditingController> _controllers = {};

  String _typeLabel(String type) {
    switch (type) {
      case 'weekly':
        return t.summary.tab_weekly;
      case 'monthly':
        return t.summary.tab_monthly;
      case 'quarterly':
        return t.summary.tab_quarterly;
      case 'yearly':
        return t.summary.tab_yearly;
      default:
        return type;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _types.length, vsync: this);
    for (final type in _types) {
      _controllers[type] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  void _loadConfig() {
    final service = ref.read(apiConfigServiceProvider);

    setState(() {
      _monthlySummarySource = service.monthlySummarySource;
      _initialized = true;
    });

    // 加载每种类型的提示词模板
    for (final type in _types) {
      final saved = service.getSummaryInstructions(type);
      _controllers[type]!.text = saved ?? PromptTemplates.getDefaultTemplate(type);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
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
                icon:
                    const Icon(Icons.calendar_view_week_rounded, size: 16),
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

        // ── AI 提示词（分类型 Tab） ──
        _buildSectionCard(
          theme: theme,
          icon: Icons.rule_rounded,
          title: t.settings.summary_ai_prompt_title,
          description: t.settings.summary_ai_prompt_desc,
          child: Column(
            children: [
              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelPadding: EdgeInsets.zero,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: colorScheme.onPrimaryContainer,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: List.generate(_types.length, (i) => Tab(
                    height: 36,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcons[i], size: 14),
                        const SizedBox(width: 4),
                        Text(_typeLabel(_types[i])),
                      ],
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 12),
              // Tab Content
              SizedBox(
                height: 220,
                child: TabBarView(
                  controller: _tabController,
                  children: _types.map((type) => Column(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[type],
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: t.settings.summary_ai_prompt_hint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSaveResetRow(
                        onSave: () async {
                          await ref
                              .read(apiConfigServiceProvider)
                              .setSummaryInstructions(
                                  type, _controllers[type]!.text.trim());
                          if (mounted) {
                            AppToast.showSuccess(context,
                                '${_typeLabel(type)} ${t.settings.saved}');
                          }
                        },
                        onReset: () {
                          _controllers[type]!.text =
                              PromptTemplates.getDefaultTemplate(type);
                        },
                      ),
                    ],
                  )).toList(),
                ),
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
