/// Agent 工具系统 — 基类与注册中心
/// 参考 opencode: packages/opencode/src/tool/tool.ts + registry.ts

import 'package:baishou/agent/models/tool_definition.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/agent/tools/tool_config_param.dart';
import 'package:flutter/material.dart';

/// 工具执行上下文
class ToolContext {
  final String sessionId;
  final String vaultPath;

  /// 用户自定义的工具参数（从持久化配置中加载）
  final Map<String, dynamic> userConfig;

  /// 嵌入服务（由 Notifier 在执行时注入，保证 Ref 有效）
  final EmbeddingService? embeddingService;

  const ToolContext({
    required this.sessionId,
    required this.vaultPath,
    this.userConfig = const {},
    this.embeddingService,
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

  // ─── 工具管理 UI 元数据 ──────────────────────────────────

  /// 显示名称（给用户看）
  String get displayName => id;

  /// 分类标签（用于 UI 分组）
  String get category => 'general';

  /// 工具图标
  IconData get icon => Icons.build_outlined;

  /// 是否允许用户禁用此工具（核心工具不允许）
  bool get canBeDisabled => true;

  /// 是否在工具管理设置页面中显示（某些工具有专属管理页面，无需重复显示）
  bool get showInSettings => true;

  /// 可配置参数列表（空 = 无可配参数）
  List<ToolConfigParam> get configurableParams => [];

  // ─── 执行 ──────────────────────────────────────────────

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
