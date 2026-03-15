/// 工具定义 — 发送给 LLM 的 Function Schema
/// 参考 opencode: packages/opencode/src/tool/tool.ts
///
/// 纯数据类，格式转换由各 Client 负责

/// 发送给 LLM 的工具函数描述
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameterSchema;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameterSchema,
  });
}
