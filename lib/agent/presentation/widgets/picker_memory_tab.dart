/// 伙伴选择器 - 记忆 Tab（可编辑）
///
/// 上下文窗口设置 + 压缩参数配置

import 'package:baishou/agent/presentation/widgets/picker_shared_widgets.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class PickerMemoryTab extends StatelessWidget {
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

  const PickerMemoryTab({
    super.key,
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
          PickerSectionHeader(
            icon: Icons.history_rounded,
            title: t.agent.assistant.context_window_label,
          ),
          const SizedBox(height: 8),
          PickerInfoCard(
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
          PickerSectionHeader(
            icon: Icons.compress_rounded,
            title: t.agent.assistant.compress_label,
          ),
          const SizedBox(height: 8),
          PickerInfoCard(
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
