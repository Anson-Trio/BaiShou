import 'dart:convert';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:flutter/material.dart';

class ToolResultGroup extends StatefulWidget {
  final List<ChatMessage> messages;

  const ToolResultGroup({super.key, required this.messages});

  @override
  State<ToolResultGroup> createState() => _ToolResultGroupState();
}

class _ToolResultGroupState extends State<ToolResultGroup> {
  final Map<String, bool> _expanded = {};

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.messages.asMap().entries.map((entry) {
          final index = entry.key;
          final msg = entry.value;
          
          String toolCallId = '';
          String toolName = '';
          Map<String, dynamic> args = {};
          
          if (msg.toolCalls?.isNotEmpty == true) {
            final call = msg.toolCalls!.first;
            toolCallId = call.id;
            toolName = call.name;
            args = call.arguments;
          } else {
            // 这是 tool role 的回复
            toolCallId = msg.toolCallId ?? '';
            toolName = 'Tool Result';
          }

          final isExpanded = _expanded[toolCallId] ?? false;
          final isLast = index == widget.messages.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _expanded[toolCallId] = !isExpanded;
                  });
                },
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.build_circle_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toolName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (args.isNotEmpty && !isExpanded)
                              Text(
                                args.toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                        color: theme.colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        msg.content ?? (args.isNotEmpty ? const JsonEncoder.withIndent('  ').convert(args) : ''),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
