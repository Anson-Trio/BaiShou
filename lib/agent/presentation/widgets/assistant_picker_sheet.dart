/// 伙伴选择弹窗（重设计版 v2）
///
/// 桌面端：侧边栏伙伴列表（可拖动排序）+ 右侧可编辑标签详情面板
/// 移动端：BottomSheet 简单卡片列表

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/assistant_edit_page.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssistantPickerSheet extends ConsumerWidget {
  final String? currentAssistantId;
  final ValueChanged<AgentAssistant?> onSelect;

  const AssistantPickerSheet({
    super.key,
    this.currentAssistantId,
    required this.onSelect,
  });

  /// 静态入口
  static Future<(bool, AgentAssistant?)> show(
    BuildContext context, {
    String? currentAssistantId,
  }) async {
    bool didSelect = false;
    AgentAssistant? result;

    final isDesktop =
        MediaQuery.of(context).size.width >= 700 ||
        Platform.isWindows ||
        Platform.isMacOS ||
        Platform.isLinux;

    if (isDesktop) {
      await showDialog(
        context: context,
        builder: (ctx) {
          final screenSize = MediaQuery.of(ctx).size;
          final dialogWidth = (screenSize.width * 0.85).clamp(600.0, 1000.0);
          final dialogHeight = (screenSize.height * 0.85).clamp(400.0, 800.0);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: _DesktopPicker(
                currentAssistantId: currentAssistantId,
                onSelect: (assistant) {
                  didSelect = true;
                  result = assistant;
                  Navigator.pop(ctx);
                },
              ),
            ),
          );
        },
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) => _MobilePicker(
            currentAssistantId: currentAssistantId,
            scrollController: scrollController,
            onSelect: (assistant) {
              didSelect = true;
              result = assistant;
              Navigator.pop(ctx);
            },
          ),
        ),
      );
    }
    return (didSelect, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

// ═══════════════════════════════════════════════════════════
// 桌面端：侧边栏 + 可编辑标签详情面板
// ═══════════════════════════════════════════════════════════

class _DesktopPicker extends ConsumerStatefulWidget {
  final String? currentAssistantId;
  final ValueChanged<AgentAssistant?> onSelect;

  const _DesktopPicker({
    this.currentAssistantId,
    required this.onSelect,
  });

  @override
  ConsumerState<_DesktopPicker> createState() => _DesktopPickerState();
}

class _DesktopPickerState extends ConsumerState<_DesktopPicker>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  AgentAssistant? _selectedAssistant;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAssistantUpdated(AgentAssistant updated) {
    setState(() => _selectedAssistant = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final assistantsAsync = ref.watch(assistantListProvider);

    return Row(
      children: [
        // ── 左侧：伙伴列表侧边栏 ──
        Container(
          width: 200,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            children: [
              // 标题
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      t.agent.assistant.select_title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 搜索框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: '搜索...',
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: colorScheme.outline),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),

              const SizedBox(height: 8),

              // 伙伴列表
              Expanded(
                child: assistantsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (assistants) {
                    final filtered = _searchQuery.isEmpty
                        ? assistants
                        : assistants
                            .where((a) =>
                                a.name
                                    .toLowerCase()
                                    .contains(_searchQuery) ||
                                a.description
                                    .toLowerCase()
                                    .contains(_searchQuery))
                            .toList();

                    // 自动选中当前伙伴
                    if (_selectedAssistant == null && filtered.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedAssistant = filtered.firstWhere(
                              (a) =>
                                  a.id.toString() ==
                                  widget.currentAssistantId,
                              orElse: () => filtered.first,
                            );
                          });
                        }
                      });
                    }

                    // 选中项被数据刷新后同步
                    if (_selectedAssistant != null) {
                      final refreshed = filtered.where(
                        (a) => a.id == _selectedAssistant!.id).toList();
                      if (refreshed.isNotEmpty &&
                          refreshed.first != _selectedAssistant) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(
                                () => _selectedAssistant = refreshed.first);
                          }
                        });
                      }
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            t.agent.assistant.empty_hint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    // 有搜索时不允许拖动排序
                    if (_searchQuery.isNotEmpty) {
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final a = filtered[index];
                          return _SidebarItem(
                            key: ValueKey(a.id),
                            assistant: a,
                            isSelected: _selectedAssistant?.id == a.id,
                            isCurrent: a.id.toString() ==
                                widget.currentAssistantId,
                            onTap: () =>
                                setState(() => _selectedAssistant = a),
                          );
                        },
                      );
                    }

                    return ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      itemCount: filtered.length,
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, _, __) => Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.transparent,
                        child: child,
                      ),
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final reordered =
                            List<AgentAssistant>.from(filtered);
                        final item = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, item);

                        final orders = <(String, int)>[];
                        for (int i = 0; i < reordered.length; i++) {
                          orders.add((reordered[i].id, i));
                        }
                        ref
                            .read(assistantRepositoryProvider)
                            .updateSortOrders(orders);
                        ref.invalidate(assistantListProvider);
                      },
                      itemBuilder: (context, index) {
                        final a = filtered[index];
                        return _SidebarItem(
                          key: ValueKey(a.id),
                          assistant: a,
                          isSelected: _selectedAssistant?.id == a.id,
                          isCurrent:
                              a.id.toString() == widget.currentAssistantId,
                          dragIndex: index,
                          onTap: () =>
                              setState(() => _selectedAssistant = a),
                        );
                      },
                    );
                  },
                ),
              ),

              // 底部：新建伙伴按钮
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssistantEditPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(t.agent.assistant.create_title),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 右侧：详情面板 ──
        Expanded(
          child: _selectedAssistant == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text(
                        '选择一个伙伴查看详情',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : _DetailPanel(
                  key: ValueKey(_selectedAssistant!.id),
                  assistant: _selectedAssistant!,
                  isCurrent: _selectedAssistant!.id.toString() ==
                      widget.currentAssistantId,
                  tabController: _tabController,
                  onSelect: () => widget.onSelect(_selectedAssistant),
                  onAssistantUpdated: _onAssistantUpdated,
                ),
        ),
      ],
    );
  }
}

// ─── 侧边栏伙伴项 ────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  final AgentAssistant assistant;
  final bool isSelected;
  final bool isCurrent;
  final int? dragIndex;
  final VoidCallback onTap;

  const _SidebarItem({
    super.key,
    required this.assistant,
    required this.isSelected,
    required this.isCurrent,
    this.dragIndex,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final a = widget.assistant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : _isHovered
                      ? colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: widget.isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // 拖拽手柄
                if (widget.dragIndex != null)
                  ReorderableDragStartListener(
                    index: widget.dragIndex!,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 14,
                          color: colorScheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                // 头像
                _buildAvatar(a, colorScheme, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: widget.isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: widget.isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (widget.isCurrent) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.circle,
                                size: 6, color: colorScheme.primary),
                          ],
                        ],
                      ),
                      if (a.description.isNotEmpty)
                        Text(
                          a.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 右侧详情面板（可编辑） ─────────────────────────────────

class _DetailPanel extends ConsumerStatefulWidget {
  final AgentAssistant assistant;
  final bool isCurrent;
  final TabController tabController;
  final VoidCallback onSelect;
  final ValueChanged<AgentAssistant> onAssistantUpdated;

  const _DetailPanel({
    super.key,
    required this.assistant,
    required this.isCurrent,
    required this.tabController,
    required this.onSelect,
    required this.onAssistantUpdated,
  });

  @override
  ConsumerState<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends ConsumerState<_DetailPanel> {
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
                    _buildAvatar(widget.assistant, colorScheme, size: 38),
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
                                _Tag(
                                  text: t.agent.assistant.default_tag,
                                  color: colorScheme.tertiaryContainer,
                                  textColor:
                                      colorScheme.onTertiaryContainer,
                                ),
                              ],
                              if (widget.isCurrent) ...[
                                const SizedBox(width: 8),
                                _Tag(
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
              _PromptTabEditable(
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
              _MemoryTabEditable(
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

// ─── 提示词 Tab（可编辑） ─────────────────────────────────

class _PromptTabEditable extends ConsumerWidget {
  final TextEditingController promptController;
  final String? selectedProviderId;
  final String? selectedModelId;
  final VoidCallback onSave;
  final void Function(String? providerId, String? modelId) onModelSelected;
  final VoidCallback onModelCleared;

  const _PromptTabEditable({
    required this.promptController,
    required this.selectedProviderId,
    required this.selectedModelId,
    required this.onSave,
    required this.onModelSelected,
    required this.onModelCleared,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 系统提示词（可编辑）
          _SectionHeader(
            icon: Icons.description_outlined,
            title: t.agent.assistant.prompt_label,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: promptController,
            maxLines: 8,
            onChanged: (_) => onSave(),
            decoration: InputDecoration(
              hintText: t.agent.assistant.prompt_hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.2),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),

          const SizedBox(height: 20),

          // 模型绑定（可编辑）
          _SectionHeader(
            icon: Icons.auto_awesome_outlined,
            title: t.agent.assistant.bind_model_label,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showModelPicker(context, ref),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedProviderId != null
                        ? Icons.link_rounded
                        : Icons.public_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: selectedProviderId != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedProviderId!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                selectedModelId ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            t.agent.assistant.use_global_model,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (selectedProviderId != null)
                    IconButton(
                      icon: Icon(Icons.close, size: 16,
                          color: colorScheme.outline),
                      onPressed: onModelCleared,
                      visualDensity: VisualDensity.compact,
                      tooltip: t.agent.assistant.use_global_model,
                    )
                  else
                    Icon(Icons.chevron_right,
                        color: colorScheme.outline, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showModelPicker(BuildContext context, WidgetRef ref) {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final providers =
        apiConfig.getProviders().where((p) => p.isEnabled).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        t.agent.assistant.select_model_title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                // 供应商 + 模型列表
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: providers.length,
                    itemBuilder: (ctx, i) {
                      final provider = providers[i];
                      final modelList = provider.enabledModels.isNotEmpty
                          ? provider.enabledModels
                          : provider.models;

                      return ExpansionTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _getProviderIcon(provider.id),
                        ),
                        title: Text(
                          provider.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${modelList.length} 模型',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: modelList.map((modelId) {
                          final isSelected =
                              selectedProviderId == provider.id &&
                              selectedModelId == modelId;
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 40),
                            title: Text(
                              modelId,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? colorScheme.primary
                                    : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: colorScheme.primary, size: 18)
                                : null,
                            onTap: () {
                              onModelSelected(provider.id, modelId);
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                // 使用全局模型按钮
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        onModelCleared();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.public_rounded, size: 16),
                      label: Text(t.agent.assistant.use_global_model),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 根据供应商 ID 返回对应图标
  Widget _getProviderIcon(String providerId) {
    final id = providerId.toLowerCase();
    if (id.contains('openai')) {
      return Image.asset('assets/ai_provider_icon/openai.png',
          width: 24, height: 24);
    } else if (id.contains('gemini') || id.contains('google')) {
      return Image.asset('assets/ai_provider_icon/gemini-color.png',
          width: 24, height: 24);
    } else if (id.contains('anthropic') || id.contains('claude')) {
      return Image.asset('assets/ai_provider_icon/claude-color.png',
          width: 24, height: 24);
    } else if (id.contains('deepseek')) {
      return Image.asset('assets/ai_provider_icon/deepseek-color.png',
          width: 24, height: 24);
    } else if (id.contains('kimi') || id.contains('moonshot')) {
      return Image.asset('assets/ai_provider_icon/moonshot.png',
          width: 24, height: 24);
    }
    return const Icon(Icons.cloud_outlined, size: 24, color: Colors.grey);
  }
}

// ─── 记忆 Tab（可编辑） ───────────────────────────────────

class _MemoryTabEditable extends StatelessWidget {
  final double contextWindow;
  final bool isCompressEnabled;
  final double compressThreshold;
  final double compressKeepTurns;
  final ValueChanged<double> onContextWindowChanged;
  final ValueChanged<bool> onUnlimitedToggled;
  final ValueChanged<bool> onCompressToggled;
  final ValueChanged<double> onCompressThresholdChanged;
  final ValueChanged<double> onCompressKeepTurnsChanged;

  bool get _isUnlimited => contextWindow < 0;

  const _MemoryTabEditable({
    required this.contextWindow,
    required this.isCompressEnabled,
    required this.compressThreshold,
    required this.compressKeepTurns,
    required this.onContextWindowChanged,
    required this.onUnlimitedToggled,
    required this.onCompressToggled,
    required this.onCompressThresholdChanged,
    required this.onCompressKeepTurnsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上下文窗口
          _SectionHeader(
            icon: Icons.history_rounded,
            title: t.agent.assistant.context_window_label,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              Row(
                children: [
                  Text('窗口大小',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      )),
                  const Spacer(),
                  if (!_isUnlimited)
                    Text(
                      '${contextWindow.round()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _isUnlimited
                        ? t.agent.assistant.context_unlimited
                        : t.agent.assistant.context_limited,
                    style: theme.textTheme.bodySmall,
                  ),
                  Switch(
                    value: _isUnlimited,
                    onChanged: onUnlimitedToggled,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (!_isUnlimited) ...[
                Slider(
                  value: contextWindow.clamp(2.0, 100.0),
                  min: 2,
                  max: 100,
                  divisions: 49,
                  label: '${contextWindow.round()}',
                  onChanged: onContextWindowChanged,
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // 压缩设置
          _SectionHeader(
            icon: Icons.compress_rounded,
            title: t.agent.assistant.compress_label,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              Row(
                children: [
                  Text('状态',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      )),
                  const Spacer(),
                  if (isCompressEnabled)
                    Text(
                      _formatTokens(compressThreshold.round()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  Switch(
                    value: isCompressEnabled,
                    onChanged: onCompressToggled,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (isCompressEnabled) ...[
                Slider(
                  value: compressThreshold.clamp(10000.0, 1000000.0),
                  min: 10000,
                  max: 1000000,
                  divisions: 99,
                  label: _formatTokens(compressThreshold.round()),
                  onChanged: onCompressThresholdChanged,
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Text(t.agent.assistant.compress_keep_turns_label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        )),
                    const Spacer(),
                    Text(
                      t.agent.assistant.compress_keep_turns_unit(
                          count: compressKeepTurns.round()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: compressKeepTurns.clamp(1.0, 10.0),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${compressKeepTurns.round()}',
                  onChanged: onCompressKeepTurnsChanged,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 10000) {
      final w =
          (tokens / 10000).toStringAsFixed(tokens % 10000 == 0 ? 0 : 1);
      return '${w}w';
    }
    return '$tokens';
  }
}

// ═══════════════════════════════════════════════════════════
// 移动端：简单卡片列表
// ═══════════════════════════════════════════════════════════

class _MobilePicker extends ConsumerStatefulWidget {
  final String? currentAssistantId;
  final ScrollController? scrollController;
  final ValueChanged<AgentAssistant?> onSelect;

  const _MobilePicker({
    this.currentAssistantId,
    this.scrollController,
    required this.onSelect,
  });

  @override
  ConsumerState<_MobilePicker> createState() => _MobilePickerState();
}

class _MobilePickerState extends ConsumerState<_MobilePicker> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final assistantsAsync = ref.watch(assistantListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 20, color: colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                t.agent.assistant.select_title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: assistantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (assistants) {
              if (assistants.isEmpty) {
                return Center(
                  child: Text(
                    t.agent.assistant.empty_hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: assistants.length,
                separatorBuilder: (_, _a) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final a = assistants[index];
                  final isSelected =
                      widget.currentAssistantId == a.id.toString();

                  return _MobileCard(
                    assistant: a,
                    isSelected: isSelected,
                    onTap: () => widget.onSelect(a),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MobileCard extends StatelessWidget {
  final AgentAssistant assistant;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileCard({
    required this.assistant,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.25)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(assistant, colorScheme, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assistant.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (assistant.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      assistant.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: colorScheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 共享 UI 组件
// ═══════════════════════════════════════════════════════════

/// 构建伙伴头像：avatarPath → emoji → 默认 icon
Widget _buildAvatar(
  AgentAssistant assistant,
  ColorScheme colorScheme, {
  double size = 40,
}) {
  final avatarImage = _getAvatarImage(assistant.avatarPath);

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.28),
      color: colorScheme.surfaceContainerHighest,
      image: avatarImage != null
          ? DecorationImage(image: avatarImage, fit: BoxFit.cover)
          : null,
    ),
    child: avatarImage == null
        ? Center(
            child: assistant.emoji != null && assistant.emoji!.isNotEmpty
                ? Text(
                    assistant.emoji!,
                    style: TextStyle(fontSize: size * 0.5),
                  )
                : Icon(
                    Icons.auto_awesome_rounded,
                    size: size * 0.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
          )
        : null,
  );
}

ImageProvider? _getAvatarImage(String? path) {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (file.existsSync()) return FileImage(file);
  return null;
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  const _Tag(
      {required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
