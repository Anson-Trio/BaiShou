/// 伙伴选择器 - 右侧详情面板（可编辑）
///
/// 包含伙伴头部信息、TabBar + TabBarView（提示词/记忆）、选择按钮

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/widgets/picker_memory_tab.dart';
import 'package:baishou/agent/presentation/widgets/picker_prompt_tab.dart';
import 'package:baishou/agent/presentation/widgets/picker_shared_widgets.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PickerDetailPanel extends ConsumerStatefulWidget {
  final AgentAssistant assistant;
  final bool isCurrent;
  final TabController tabController;
  final VoidCallback onSelect;
  final ValueChanged<AgentAssistant> onAssistantUpdated;

  const PickerDetailPanel({
    super.key,
    required this.assistant,
    required this.isCurrent,
    required this.tabController,
    required this.onSelect,
    required this.onAssistantUpdated,
  });

  @override
  ConsumerState<PickerDetailPanel> createState() => _PickerDetailPanelState();
}

class _PickerDetailPanelState extends ConsumerState<PickerDetailPanel> {
  late TextEditingController _promptController;
  late double _contextWindow;
  late bool _isCompressEnabled;
  late double _compressThreshold;
  late double _compressKeepTurns;
  String? _selectedProviderId;
  String? _selectedModelId;

  bool get _isUnlimitedContext => _contextWindow < 0;

  @override
  void initState() {
    super.initState();
    final a = widget.assistant;
    _promptController = TextEditingController(text: a.systemPrompt);
    _contextWindow = a.contextWindow.toDouble();
    _isCompressEnabled = a.compressTokenThreshold > 0;
    _compressThreshold = a.compressTokenThreshold.toDouble();
    _compressKeepTurns = a.compressKeepTurns.toDouble();
    _selectedProviderId = a.providerId;
    _selectedModelId = a.modelId;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final service = ref.read(assistantServiceProvider);
    await service.updateAssistant(
      id: widget.assistant.id,
      name: widget.assistant.name,
      systemPrompt: _promptController.text.trim(),
      contextWindow: _isUnlimitedContext ? -1 : _contextWindow.round(),
      providerId: _selectedProviderId,
      modelId: _selectedModelId,
      clearModel: _selectedProviderId == null,
      compressTokenThreshold:
          _isCompressEnabled ? _compressThreshold.round() : 0,
      compressKeepTurns: _compressKeepTurns.round(),
    );
    ref.invalidate(assistantListProvider);

    // 刷新选中的助手
    final repo = ref.read(assistantRepositoryProvider);
    final updated = await repo.get(widget.assistant.id);
    if (updated != null) {
      widget.onAssistantUpdated(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // ── 顶部：伙伴信息 + 标签栏 ──
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            children: [
              // 伙伴头部信息
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    buildAssistantAvatar(widget.assistant, colorScheme,
                        size: 38),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.assistant.name,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.assistant.isDefault) ...[
                                const SizedBox(width: 8),
                                PickerTag(
                                  text: t.agent.assistant.default_tag,
                                  color: colorScheme.tertiaryContainer,
                                  textColor:
                                      colorScheme.onTertiaryContainer,
                                ),
                              ],
                              if (widget.isCurrent) ...[
                                const SizedBox(width: 8),
                                PickerTag(
                                  text: '当前',
                                  color: colorScheme.primaryContainer,
                                  textColor: colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          if (widget.assistant.description.isNotEmpty)
                            Text(
                              widget.assistant.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 标签栏（紧凑）
              TabBar(
                controller: widget.tabController,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorColor: colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerHeight: 0,
                labelStyle: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [
                  Tab(text: '提示词', height: 36),
                  Tab(text: '记忆', height: 36),
                ],
              ),
            ],
          ),
        ),

        // ── 标签内容 ──
        Expanded(
          child: TabBarView(
            controller: widget.tabController,
            children: [
              PickerPromptTab(
                promptController: _promptController,
                selectedProviderId: _selectedProviderId,
                selectedModelId: _selectedModelId,
                onSave: _save,
                onModelSelected: (pid, mid) {
                  setState(() {
                    _selectedProviderId = pid;
                    _selectedModelId = mid;
                  });
                  _save();
                },
                onModelCleared: () {
                  setState(() {
                    _selectedProviderId = null;
                    _selectedModelId = null;
                  });
                  _save();
                },
              ),
              PickerMemoryTab(
                contextWindow: _contextWindow,
                isCompressEnabled: _isCompressEnabled,
                compressThreshold: _compressThreshold,
                compressKeepTurns: _compressKeepTurns,
                onContextWindowChanged: (v) {
                  setState(() => _contextWindow = v);
                  _save();
                },
                onUnlimitedToggled: (v) {
                  setState(
                      () => _contextWindow = v ? -1 : 20);
                  _save();
                },
                onCompressToggled: (v) {
                  setState(() {
                    _isCompressEnabled = v;
                    if (v && _compressThreshold <= 0) {
                      _compressThreshold = 60000;
                    }
                  });
                  _save();
                },
                onCompressThresholdChanged: (v) {
                  setState(() => _compressThreshold = v);
                  _save();
                },
                onCompressKeepTurnsChanged: (v) {
                  setState(() => _compressKeepTurns = v);
                  _save();
                },
              ),
            ],
          ),
        ),

        // ── 底部：选择按钮 ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              onPressed: widget.onSelect,
              icon: widget.isCurrent
                  ? const Icon(Icons.check_circle_rounded, size: 18)
                  : const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(widget.isCurrent ? '当前伙伴' : '选择此伙伴'),
              style: FilledButton.styleFrom(
                backgroundColor: widget.isCurrent
                    ? colorScheme.surfaceContainerHighest
                    : null,
                foregroundColor: widget.isCurrent
                    ? colorScheme.onSurfaceVariant
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
