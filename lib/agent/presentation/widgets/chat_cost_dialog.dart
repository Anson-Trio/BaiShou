/// 聊天费用详情弹窗
///
/// 显示累计 Token 消耗和费用统计

import 'package:baishou/agent/presentation/notifiers/agent_chat_notifier.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

/// 费用详情弹窗入口
void showCostDetailDialog(BuildContext context, AgentChatState chatState) {
  final theme = Theme.of(context);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.agent.chat.cost_detail_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.agent.chat.cost_cumulative_title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          CostRow(
            label: t.agent.chat.cost_cumulative_total,
            value:
                '\$${(chatState.totalCostMicros / 1000000).toStringAsFixed(6)}',
          ),
          CostRow(
            label: t.agent.chat.cost_cumulative_input,
            value:
                '${chatState.totalInputTokens} ${t.agent.chat.tokens_unit}',
          ),
          CostRow(
            label: t.agent.chat.cost_cumulative_output,
            value:
                '${chatState.totalOutputTokens} ${t.agent.chat.tokens_unit}',
          ),
          const Divider(height: 24),
          Text(
            t.agent.chat.cost_context_title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          CostRow(
            label: t.agent.chat.cost_context_size,
            value: chatState.lastInputTokens > 0
                ? '${chatState.lastInputTokens} ${t.agent.chat.tokens_unit}'
                : t.agent.chat.cost_no_data,
          ),
          const SizedBox(height: 16),
          Text(
            t.agent.chat.cost_disclaimer,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.confirm),
        ),
      ],
    ),
  );
}

/// 费用详情弹窗中的 label-value 行
class CostRow extends StatelessWidget {
  final String label;
  final String value;
  const CostRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'RobotoMono',
            ),
          ),
        ],
      ),
    );
  }
}
