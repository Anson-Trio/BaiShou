/// Agent System Prompt 构建器
///
/// 根据上下文动态构建 Agent 的系统提示词
/// 所有文案从外部传入（i18n 或用户设置），不硬编码任何内容

import 'package:baishou/agent/tools/agent_tool.dart';

class SystemPromptBuilder {
  /// 构建完整的 Agent System Prompt
  ///
  /// [persona] 人设描述（来自用户设置或 i18n 默认值）
  /// [guidelines] 行为准则（来自用户设置或 i18n 默认值）
  /// [vaultName] 当前 Vault 名称
  /// [tools] 可用工具注册中心
  static String build({
    required String persona,
    required String guidelines,
    required String vaultName,
    required ToolRegistry tools,
  }) {
    final buffer = StringBuffer();

    // 人设
    buffer.writeln(persona);
    buffer.writeln();

    // 时间上下文
    final now = DateTime.now();
    buffer.writeln(
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    buffer.writeln();

    // Vault 上下文
    buffer.writeln('Vault: $vaultName');
    buffer.writeln();

    // 可用工具说明
    if (tools.ids.isNotEmpty) {
      for (final id in tools.ids) {
        final tool = tools.get(id);
        if (tool != null) {
          buffer.writeln('- **${tool.id}**: ${tool.description}');
        }
      }
      buffer.writeln();

      // RAG 工具禁用时，指引 AI 使用日记工具
      final hasMemoryStore = tools.get('memory_store') != null;
      final hasVectorSearch = tools.get('vector_search') != null;
      if (!hasMemoryStore || !hasVectorSearch) {
        buffer.writeln(
          'Note: Memory/RAG tools are currently disabled by the user. '
          'For storing and retrieving information, use the diary/summary tools instead. '
          'Do NOT attempt to call memory_store or vector_search.',
        );
        buffer.writeln();
      }
    }

    // 行为准则
    buffer.writeln(guidelines);

    return buffer.toString();
  }
}
