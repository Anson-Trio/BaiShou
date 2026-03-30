import 'dart:io';

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/session_manager.dart';
import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/agent/presentation/widgets/assistant_picker_sheet.dart';
import 'package:baishou/agent/presentation/widgets/picker_shared_widgets.dart';
import 'package:baishou/agent/presentation/widgets/session_list_tile.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';

/// Agent 侧边栏组件
///
/// 包含品牌区、当前伙伴、新对话按钮、对话历史列表、
/// 批量删除操作栏以及底部用户卡片。
class AgentSidebar extends ConsumerStatefulWidget {
  const AgentSidebar({
    super.key,
    required this.currentAssistant,
    required this.sessions,
    required this.isLoading,
    required this.selectedSessionId,
    required this.searchQuery,
    required this.hasMore,
    required this.onSearchQueryChanged,
    required this.onLoadMore,
    required this.onSessionSelected,
    required this.onNewSession,
    required this.onAssistantSwitched,
    required this.onSessionsChanged,
    this.onCollapse,
  });

  final AgentAssistant? currentAssistant;
  final List<AgentSession>? sessions;
  final bool isLoading;
  final String? selectedSessionId;
  final String searchQuery;
  final bool hasMore;
  final ValueChanged<String> onSearchQueryChanged;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onNewSession;
  final ValueChanged<AgentAssistant> onAssistantSwitched;
  final VoidCallback onSessionsChanged;
  final VoidCallback? onCollapse;

  @override
  ConsumerState<AgentSidebar> createState() => _AgentSidebarState();
}

class _AgentSidebarState extends ConsumerState<AgentSidebar> {
  bool _isMultiSelect = false;
  final Set<String> _selectedIds = {};
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant AgentSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(userProfileProvider);
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── 顶部品牌区 ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.agent.partner_label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isDesktop && widget.onCollapse != null)
                          IconButton(
                            icon: const Icon(Icons.menu_open_rounded, size: 20),
                            tooltip: t.agent.chat.collapse_sidebar,
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onCollapse,
                          ),
                      ],
                    ),
                  ),

                  // ─── 当前伙伴区域 ───
                  if (widget.currentAssistant != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: InkWell(
                        onTap: _showAssistantSwitcher,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              buildAssistantAvatar(
                                widget.currentAssistant!,
                                theme.colorScheme,
                                size: 36,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.currentAssistant!.name,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget
                                        .currentAssistant!
                                        .description
                                        .isNotEmpty)
                                      Text(
                                        widget.currentAssistant!.description,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.unfold_more,
                                size: 18,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ─── 固定的伙伴区域 (横向列表) ───
                  _buildPinnedAssistants(context, theme),

                  const SizedBox(height: 4),

                  // ─── 新对话按钮 ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: FilledButton.icon(
                      onPressed: widget.onNewSession,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(t.agent.sessions.new_chat),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ─── 功能选项区 ───
                  SidebarMenuItem(
                    icon: Icons.settings_rounded,
                    label: t.settings.title,
                    isSelected: false,
                    onTap: () => context.push('/settings'),
                  ),

                  const SizedBox(height: 8),

                  // ─── 对话历史区标题 ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          t.agent.chat.recent_chats,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        if (widget.sessions != null && widget.sessions!.isNotEmpty)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() {
                              _isMultiSelect = !_isMultiSelect;
                              _selectedIds.clear();
                            }),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _isMultiSelect
                                    ? Icons.close
                                    : Icons.checklist_rounded,
                                size: 16,
                                color: _isMultiSelect
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ─── 搜索过滤框 ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: t.agent.chat.search_recent,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: widget.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                widget.onSearchQueryChanged('');
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      style: theme.textTheme.bodyMedium,
                      onChanged: widget.onSearchQueryChanged,
                    ),
                  ),

                  const SizedBox(height: 4),
                ],
              ),
            ),

            // ─── 对话列表 ───
            if (widget.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (widget.sessions == null || widget.sessions!.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      t.agent.sessions.no_history,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              )
            else
              Builder(builder: (context) {
                final items = widget.sessions!;

                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          t.agent.chat.no_search_results,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return SliverList.builder(
                  itemCount: items.length + (widget.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: TextButton(
                          onPressed: widget.onLoadMore,
                          child: Text(t.agent.chat.load_more),
                        ),
                      );
                    }

                    final session = items[index];
                    final isSelected = session.id == widget.selectedSessionId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SessionListTile(
                        key: ValueKey(session.id),
                        session: session,
                        isSelected: isSelected,
                        isMultiSelect: _isMultiSelect,
                        isChecked: _selectedIds.contains(session.id),
                        onTap: () => widget.onSessionSelected(session.id),
                        onCheckChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedIds.add(session.id);
                          } else {
                            _selectedIds.remove(session.id);
                          }
                        }),
                        onPin: () async {
                          await ref
                              .read(sessionManagerProvider)
                              .togglePinSession(
                                session.id,
                                !session.isPinned,
                              );
                          widget.onSessionsChanged();
                        },
                        onRename: () => _renameSession(session.id, session.title),
                        onDelete: () => _deleteSession(session.id, session.title),
                      ),
                    );
                  },
                );
              }),

            // ─── 底部用户卡片和选项栏区域 ───
            SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── 批量删除操作栏 ───
                  if (_isMultiSelect && widget.sessions != null)
                    _buildBatchDeleteBar(theme),

                  // ─── 底部用户卡片 ───
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage:
                              userProfile.avatarPath != null &&
                                  File(userProfile.avatarPath!).existsSync()
                              ? FileImage(File(userProfile.avatarPath!))
                              : null,
                          child:
                              userProfile.avatarPath == null ||
                                  !File(userProfile.avatarPath!).existsSync()
                              ? Text(
                                  userProfile.nickname.isNotEmpty
                                      ? userProfile.nickname[0].toUpperCase()
                                      : 'U',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            userProfile.nickname.isNotEmpty
                                ? userProfile.nickname
                                : t.settings.default_nickname,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchDeleteBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() {
              if (_selectedIds.length == widget.sessions!.length) {
                _selectedIds.clear();
              } else {
                _selectedIds.addAll(widget.sessions!.map((s) => s.id));
              }
            }),
            child: Text(
              _selectedIds.length == widget.sessions!.length
                  ? t.agent.chat.deselect_all
                  : t.agent.chat.select_all,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _selectedIds.isEmpty ? null : _batchDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(t.agent.chat.delete_count(count: _selectedIds.length)),
            style: FilledButton.styleFrom(
              backgroundColor: _selectedIds.isEmpty
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.error,
              foregroundColor: _selectedIds.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _batchDelete() async {
    final theme = Theme.of(context);
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.sessions.delete_title),
        content: Text(t.agent.chat.delete_confirm_multi(count: count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text(t.agent.chat.delete_count(count: count)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(sessionManagerProvider)
          .deleteSessions(_selectedIds.toList());
      if (_selectedIds.contains(widget.selectedSessionId)) {
        ref.read(agentChatProvider.notifier).clearChat();
      }
      _selectedIds.clear();
      _isMultiSelect = false;
      widget.onSessionsChanged();
    }
  }

  Future<void> _showAssistantSwitcher() async {
    if (!mounted) return;
    final (didSelect, selected) = await AssistantPickerSheet.show(
      context,
      currentAssistantId: widget.currentAssistant?.id.toString(),
    );
    if (!didSelect || selected == null) return;
    widget.onAssistantSwitched(selected);
  }

  Future<void> _deleteSession(String id, String title) async {
    final displayTitle = title.isEmpty ? t.agent.sessions.new_chat : title;
    final act = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.sessions.delete_title),
        content: Text(
          t.agent.sessions.delete_confirm.replaceAll('{title}', displayTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(t.agent.sessions.delete_btn),
          ),
        ],
      ),
    );
    if (act == true) {
      await ref.read(sessionManagerProvider).deleteSession(id);
      if (widget.selectedSessionId == id) {
        ref.read(agentChatProvider.notifier).clearChat();
      }
      widget.onSessionsChanged();
    }
  }

  Future<void> _renameSession(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.sessions.rename),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: t.agent.sessions.rename_hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(controller.text),
            child: Text(t.common.save),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await ref.read(sessionManagerProvider).renameSession(id, newName.trim());
      widget.onSessionsChanged();
    }
  }

  Widget _buildPinnedAssistants(BuildContext context, ThemeData theme) {
    final apiConfig = ref.watch(apiConfigServiceProvider);
    final allAssistants = ref.watch(assistantListProvider).value ?? [];
    return ListenableBuilder(
      listenable: apiConfig,
      builder: (context, child) {
        final pinnedIds = apiConfig.pinnedAssistantIds;
        final pinnedAssistants = pinnedIds
            .map((id) => allAssistants.where((a) => a.id == id).firstOrNull)
            .whereType<AgentAssistant>()
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pinnedAssistants.length + 1,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final isDesktop = MediaQuery.of(context).size.width >= 700 ||
                Platform.isWindows ||
                Platform.isMacOS ||
                Platform.isLinux;

            if (index == pinnedAssistants.length) {
              if (isDesktop) return const SizedBox.shrink();
              return Tooltip(
                message: t.agent.chat.manage_pinned,
                child: InkWell(
                  onTap: () => context.push('/settings/assistants'),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }

            final assistant = pinnedAssistants[index];
            final isSelected = widget.currentAssistant?.id == assistant.id;

            return Tooltip(
              message: assistant.name,
              child: InkWell(
                onTap: () {
                  if (!isSelected) {
                    widget.onAssistantSwitched(assistant);
                    if (Scaffold.of(context).isDrawerOpen) {
                      Navigator.pop(context);
                    }
                  }
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
                  child: ClipOval(
                    child: buildAssistantAvatar(
                      assistant,
                      theme.colorScheme,
                      size: isSelected ? 36 : 40,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
      },
    );
  }
}
