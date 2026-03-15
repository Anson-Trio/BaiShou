/// Agent System Prompt 构建器
///
/// 根据上下文动态构建 Agent 的系统提示词
/// 包含基础人设、可用工具描述、当前日期等上下文信息

import 'package:baishou/agent/tools/agent_tool.dart';

class SystemPromptBuilder {
  /// 构建完整的 Agent System Prompt
  ///
  /// [vaultName] 当前 Vault 名称
  /// [tools] 可用工具注册中心
  /// [customPersona] 可选的自定义人设（来自提示词设置）
  static String build({
    required String vaultName,
    required ToolRegistry tools,
    String? customPersona,
  }) {
    final buffer = StringBuffer();

    // 基础人设
    buffer.writeln(_basePersona(customPersona));
    buffer.writeln();

    // 时间上下文
    buffer.writeln(_timeContext());
    buffer.writeln();

    // Vault 上下文
    buffer.writeln(_vaultContext(vaultName));
    buffer.writeln();

    // 可用工具说明
    if (tools.ids.isNotEmpty) {
      buffer.writeln(_toolsContext(tools));
    }

    // 行为准则
    buffer.writeln();
    buffer.writeln(_behaviorGuidelines());

    return buffer.toString();
  }

  /// 基础人设
  static String _basePersona(String? customPersona) {
    if (customPersona != null && customPersona.isNotEmpty) {
      return customPersona;
    }

    return '''你是白守（BaiShou）的 AI 助手，帮助用户管理和回顾他们的日记与生活记录。
你善于理解用户的情感和需求，能够通过阅读日记内容来提供有价值的回顾、分析和建议。
你说话自然、温暖，像一个了解用户的朋友。''';
  }

  /// 时间上下文
  static String _timeContext() {
    final now = DateTime.now();
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[now.weekday - 1];

    return '当前时间：${now.year}年${now.month}月${now.day}日 $weekday '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Vault 上下文
  static String _vaultContext(String vaultName) {
    return '当前工作空间（Vault）：$vaultName';
  }

  /// 可用工具说明
  static String _toolsContext(ToolRegistry tools) {
    final buffer = StringBuffer();
    buffer.writeln('你可以使用以下工具来访问用户的数据：');
    buffer.writeln();

    for (final id in tools.ids) {
      final tool = tools.get(id);
      if (tool != null) {
        buffer.writeln('- **${tool.id}**: ${tool.description}');
      }
    }

    return buffer.toString();
  }

  /// 行为准则
  static String _behaviorGuidelines() {
    return '''## 行为准则
- 当用户询问日记相关内容时，主动使用工具查阅，不要编造内容。
- 在引用日记内容时，注明日期来源。
- 尊重用户的隐私，不对日记内容做道德评判。
- 如果工具返回"未找到"，如实告知用户，不要虚构数据。
- 回答简洁但有温度，避免冗长的套话。''';
  }
}
