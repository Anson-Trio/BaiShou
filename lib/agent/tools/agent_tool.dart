/// Agent 工具系统 — 基类与注册中心
/// 参考 opencode: packages/opencode/src/tool/tool.ts + registry.ts

import 'package:baishou/agent/models/tool_definition.dart';

/// 工具执行上下文
class ToolContext {
  final String sessionId;
  final String vaultPath;

  const ToolContext({
    required this.sessionId,
    required this.vaultPath,
  });
}

/// 工具执行结果
class ToolResult {
  final String output;
  final bool success;
  final Map<String, dynamic>? metadata;

  const ToolResult({
    required this.output,
    this.success = true,
    this.metadata,
  });

  factory ToolResult.error(String message) => ToolResult(
        output: 'Error: $message',
        success: false,
      );
}

/// 工具定义基类
/// 每个具体工具继承此类，实现 execute 方法
abstract class AgentTool {
  /// 工具唯一标识
  String get id;

  /// 工具的人类可读描述 (发送给 LLM)
  String get description;

  /// JSON Schema 格式的参数定义
  Map<String, dynamic> get parameterSchema;

  /// 执行工具
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  );

  /// 转换为发送给 LLM 的 ToolDefinition
  ToolDefinition toDefinition() => ToolDefinition(
        name: id,
        description: description,
        parameterSchema: parameterSchema,
      );
}

/// 工具注册中心
/// 参考 opencode: packages/opencode/src/tool/registry.ts
class ToolRegistry {
  final Map<String, AgentTool> _tools = {};

  /// 注册工具
  void register(AgentTool tool) {
    _tools[tool.id] = tool;
  }

  /// 批量注册
  void registerAll(List<AgentTool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  /// 获取工具
  AgentTool? get(String id) => _tools[id];

  /// 所有已注册工具 ID
  List<String> get ids => _tools.keys.toList();

  /// 转换为 ToolDefinition 列表 (发送给 LLM)
  List<ToolDefinition> toDefinitions() =>
      _tools.values.map((t) => t.toDefinition()).toList();
}
