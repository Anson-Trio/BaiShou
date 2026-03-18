# BaiShou Agent 工具开发规范

本文档定义了为白守 Agent 开发内置工具时应遵循的规范，确保代码风格统一、多语言兼容、可维护性高。

---

## 1. 文件结构

每个工具放在 `lib/agent/tools/<category>/` 下，命名格式为 `<tool_id>_tool.dart`。

```
lib/agent/tools/
├── agent_tool.dart          # 基类，不要修改
├── built_in_tool_provider.dart
├── tool_config_param.dart
├── TOOL_DEV_GUIDE.md        # ← 本文件
├── diary/
│   ├── diary_read_tool.dart
│   ├── diary_list_tool.dart
│   └── diary_search_tool.dart
├── memory/
│   ├── vector_search_tool.dart
│   └── memory_store_tool.dart
├── message/
│   └── message_search_tool.dart
└── summary/
    └── summary_read_tool.dart
```

---

## 2. 工具模板

```dart
import 'package:baishou/agent/tools/agent_tool.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';

class MyNewTool extends AgentTool {
  // 依赖注入
  final SomeDependency _dep;
  MyNewTool(this._dep);

  // ─── 标识 ────────────────────────────────────
  @override
  String get id => 'my_new_tool'; // snake_case，全局唯一

  // ─── 用户可见 UI 文本（必须走 slang 多语言） ──────
  @override
  String get displayName => t.agent.tools.my_new_tool;

  @override
  String get category => 'my_category';

  @override
  IconData get icon => Icons.star_outlined;

  // ─── LLM 描述（必须英文，不走 slang） ─────────────
  @override
  String get description =>
      'A concise English description of what this tool does. '
      'This text is sent directly to the LLM as part of function calling.';

  // ─── 参数 Schema（必须英文） ─────────────────────
  @override
  Map<String, dynamic> get parameterSchema => {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'English description for the LLM.',
      },
    },
    'required': ['query'],
  };

  // ─── 执行 ────────────────────────────────────
  @override
  Future<ToolResult> execute(
    Map<String, dynamic> arguments,
    ToolContext context,
  ) async {
    // 实现逻辑
    return ToolResult(output: 'result');
  }
}
```

---

## 3. 多语言规则 ⚠️

这是最重要的部分。工具中的文本分为两类，处理方式完全不同：

### ✅ 用户可见文本 → 必须使用 slang

| 字段 | 说明 |
|------|------|
| `displayName` | 在工具管理页、工具调用 UI 卡片上展示 |
| `configurableParams.label` | 工具配置面板展示的参数名 |
| `configurableParams.description` | 工具配置面板展示的参数说明 |

**做法**：
1. 在 `lib/i18n/zh.i18n.json` → `agent.tools` 下添加 key
2. 同步更新 `en.i18n.json`、`ja.i18n.json`、`zh_TW.i18n.json`
3. 运行 `dart run slang` 生成类型安全代码
4. 在 Dart 中使用 `t.agent.tools.xxx` 引用

**示例**：

```json
// zh.i18n.json
"agent": {
  "tools": {
    "my_new_tool": "我的新工具",
    "param_threshold": "阈值",
    "param_threshold_desc": "搜索相似度阈值"
  }
}
```

```dart
@override
String get displayName => t.agent.tools.my_new_tool;

@override
List<ToolConfigParam> get configurableParams => [
  ToolConfigParam(
    key: 'threshold',
    label: t.agent.tools.param_threshold,
    description: t.agent.tools.param_threshold_desc,
    type: ParamType.decimal,
    defaultValue: 0.7,
  ),
];
```

### ❌ LLM 指令文本 → 必须英文，不走 slang

| 字段 | 说明 |
|------|------|
| `description` | 发送给 LLM 的工具描述 |
| `parameterSchema` 内的 `description` | 发送给 LLM 的参数说明 |
| `ToolResult.output` | 返回给 LLM 的执行结果 |
| `ToolResult.error()` | 返回给 LLM 的错误信息 |

**原因**：这些文本是 API 层面的指令，LLM 需要稳定的英文提示词。中文描述可能导致部分模型理解偏差。

---

## 4. 注册工具

在 `built_in_tool_provider.dart` 中注册：

```dart
final myNewTool = MyNewTool(dep);
registry.register(myNewTool);
```

---

## 5. 检查清单

开发完一个新工具后，请逐项确认：

- [ ] `id` 使用 snake_case，全局唯一
- [ ] `displayName` 使用 `t.agent.tools.xxx`（已添加四语言 key）
- [ ] `description` 和 `parameterSchema` 使用英文
- [ ] `configurableParams` 的 `label` 和 `description` 使用 slang
- [ ] 已在 `built_in_tool_provider.dart` 中注册
- [ ] 运行 `dart run slang` 重新生成
- [ ] 运行 `flutter analyze` 确认 0 error
