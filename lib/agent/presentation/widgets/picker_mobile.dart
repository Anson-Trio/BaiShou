/// 伙伴选择器 - 移动端视图
///
/// BottomSheet 简单卡片列表

import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/widgets/picker_shared_widgets.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:baishou/core/services/api_config_service.dart';

class PickerMobileView extends ConsumerStatefulWidget {
  final String? currentAssistantId;
  final ScrollController? scrollController;
  final ValueChanged<AgentAssistant?> onSelect;

  const PickerMobileView({
    super.key,
    this.currentAssistantId,
    this.scrollController,
    required this.onSelect,
  });

  @override
  ConsumerState<PickerMobileView> createState() => _PickerMobileViewState();
}

class _PickerMobileViewState extends ConsumerState<PickerMobileView> {
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
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                t.agent.assistant.select_title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.pop(context);
                  GoRouter.of(context).push('/settings/assistants');
                },
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
                  return ListenableBuilder(
                    listenable: ref.read(apiConfigServiceProvider),
                    builder: (context, _) {
                      final isPinned =
                          ref.read(apiConfigServiceProvider).pinnedAssistantIds.contains(a.id);

                      return _MobileCard(
                        assistant: a,
                        isSelected: isSelected,
                        isPinned: isPinned,
                        onTogglePin: () {
                          ref.read(apiConfigServiceProvider).togglePinnedAssistant(a.id);
                        },
                        onTap: () => widget.onSelect(a),
                      );
                    },
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
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;

  const _MobileCard({
    required this.assistant,
    required this.isSelected,
    required this.isPinned,
    required this.onTogglePin,
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
            buildAssistantAvatar(assistant, colorScheme, size: 40),
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
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected) ...[
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                size: 22,
                color: isPinned ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              onPressed: onTogglePin,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
