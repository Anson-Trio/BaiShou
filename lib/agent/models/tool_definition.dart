/// 工具定义 — 发送给 LLM 的 Function Schema
/// 参考 opencode: packages/opencode/src/tool/tool.ts

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

  /// 转换为 OpenAI 兼容的 tools 格式
  Map<String, dynamic> toOpenAiFormat() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameterSchema,
        },
      };

  /// 转换为 Gemini functionDeclaration 格式
  Map<String, dynamic> toGeminiFormat() => {
        'name': name,
        'description': description,
        'parameters': parameterSchema,
      };

  /// 转换为 Anthropic tool 格式
  Map<String, dynamic> toAnthropicFormat() => {
        'name': name,
        'description': description,
        'input_schema': parameterSchema,
      };
}
