/// 伙伴选择弹窗
///
/// 展示伙伴列表（卡片式设计），支持搜索、选择或清除
/// 桌面端使用 Dialog，移动端使用 BottomSheet

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
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

  /// 静态方法：弹出选择器
  /// 返回 (是否做出了选择, 选中的伙伴)
  /// didSelect=false 表示用户关闭弹窗未操作
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
      // 桌面端：Dialog
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
            child: _PickerContent(
              currentAssistantId: currentAssistantId,
              onSelect: (assistant) {
                didSelect = true;
                result = assistant;
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      );
    } else {
      // 移动端：BottomSheet
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
          builder: (_, scrollController) => _PickerContent(
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

// ─── 弹窗内容主体 ────────────────────────────────────────

class _PickerContent extends ConsumerStatefulWidget {
  final String? currentAssistantId;
  final ScrollController? scrollController;
  final ValueChanged<AgentAssistant?> onSelect;

  const _PickerContent({
    this.currentAssistantId,
    this.scrollController,
    required this.onSelect,
  });

  @override
  ConsumerState<_PickerContent> createState() => _PickerContentState();
}

class _PickerContentState extends ConsumerState<_PickerContent> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final assistantsAsync = ref.watch(assistantListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 标题栏 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.agent.assistant.select_title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // 清除选择
              if (widget.currentAssistantId != null)
                IconButton(
                  onPressed: () => widget.onSelect(null),
                  icon: Icon(
                    Icons.link_off_rounded,
                    size: 20,
                    color: colorScheme.outline,
                  ),
                  tooltip: t.agent.assistant.clear_selection,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 搜索框 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: '搜索...',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: colorScheme.outline,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),

        const SizedBox(height: 12),

        // ── 助手列表 ──
        Expanded(
          child: assistantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assistants) {
              // 搜索过滤
              final filtered = _searchQuery.isEmpty
                  ? assistants
                  : assistants.where((a) {
                      return a.name.toLowerCase().contains(_searchQuery) ||
                          a.systemPrompt.toLowerCase().contains(_searchQuery);
                    }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                        ? '无搜索结果'
                            : t.agent.assistant.empty_hint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final a = filtered[index];
                  final isSelected =
                      widget.currentAssistantId == a.id.toString();

                  return _AssistantCard(
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

// ─── 助手卡片组件 ────────────────────────────────────────

class _AssistantCard extends StatefulWidget {
  final AgentAssistant assistant;
  final bool isSelected;
  final VoidCallback onTap;

  const _AssistantCard({
    required this.assistant,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AssistantCard> createState() => _AssistantCardState();
}

class _AssistantCardState extends State<_AssistantCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final a = widget.assistant;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.25)
                : _isHovered
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : _isHovered
                      ? colorScheme.outlineVariant.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: widget.isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  image: _getAvatar(a.avatarPath) != null
                      ? DecorationImage(
                          image: _getAvatar(a.avatarPath)!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _getAvatar(a.avatarPath) == null
                    ? Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 22,
                          color: widget.isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // 内容
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: widget.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: widget.isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (a.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.agent.assistant.default_tag,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (a.systemPrompt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        a.systemPrompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 选中指示器
              if (widget.isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _getAvatar(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }
}
