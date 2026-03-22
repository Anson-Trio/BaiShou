/// 伙伴选择弹窗（重设计版 v2）
///
/// 桌面端：侧边栏伙伴列表（可拖动排序）+ 右侧可编辑标签详情面板
/// 移动端：BottomSheet 简单卡片列表

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/pages/assistant_edit_page.dart';
import 'package:baishou/agent/presentation/widgets/picker_detail_panel.dart';
import 'package:baishou/agent/presentation/widgets/picker_mobile.dart';
import 'package:baishou/agent/presentation/widgets/picker_sidebar_item.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
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
          builder: (_, scrollController) => PickerMobileView(
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
                          return PickerSidebarItem(
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
                        return PickerSidebarItem(
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
              : PickerDetailPanel(
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
