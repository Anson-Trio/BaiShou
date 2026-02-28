# 白守 (BaiShou) - VIBE & 开发规约
本文更新时间：2026-2-28

> **"以纯白的誓约，守护彼此的一生。"**
> 此文档定义了白守（BaiShou）项目的代码风格、架构规范与工程标准。
> 所有的注释与说明文本强制使用 **中文** 书写。

---

## 1. 核心精神 (The Vibe)

- **纯粹 (Purity)**: 代码逻辑必须干净、直观。拒绝过度封装，保持逻辑的扁平化。
- **稳固 (Stability)**: 数据层必须极其健壮，通过影子索引与物理文件双重保障。
- **流畅 (Flow)**: UI 交互应具备自然的转场与动画细节，确保用户体验的连贯性。
- **透明 (Transparency)**: 状态管理清晰，副作用必须可追踪，代码即文档。

---

## 2. 技术栈 (Tech Stack)

| 领域           | 选型                     | 说明                                                 |
| :------------- | :----------------------- | :--------------------------------------------------- |
| **Framework**  | **Flutter 3.x**          | 全平台统一体验                                       |
| **Language**   | **Dart 3.x**             | 开启 100% 空安全，使用 Records, Patterns 等新特性    |
| **State Mgmt** | **Riverpod (Generator)** | 使用 `@riverpod` 注解生成代码                         |
| **Database**   | **Drift**                | 类型安全的 SQLite 封装                               |
| **Routing**    | **GoRouter**             | 声明式路由管理                                       |
| **UI System**  | **Material Design 3**    | 遵循 M3 规范，设计素雅淡洁                           |
| **Immutable**  | **Freezed**              | 数据类不可变，杜绝隐式状态修改                       |
| **I18n**       | **slang**                | 强类型翻译键，代码生成                               |

---

## 3. 项目架构 (Architecture)

采用 **Feature-First + Riverpod Architecture** 分层结构。

```text
lib/
├── app.dart                # 应用入口 widget
├── main.dart               # main 函数入口
├── core/                   # 核心通用模块
│   ├── clients/            # 各种 API/三方客户端
│   ├── database/           # Drift 数据库定义与配置
│   ├── theme/              # 全局配色与字阶配置
│   ├── router/             # 路由分发逻辑
│   └── widgets/            # 跨功能单元复用的核心组件
├── features/               # 业务模块 (按功能划分)
│   ├── diary/              # 日记记录模块
│   ├── summary/            # 周期总结模块
│   ├── settings/           # 系统设置模块
│   └── home/               # 主页引导
├── i18n/                   # 国际化翻译源文件 (JSON)
└── source/                 # 静态资源（提示词、图片、配置模板）
```

---

## 4. 编码规范 (Coding Standards)

### 4.1 核心原则
- **拒绝硬编码**: 所有 UI 文案、配置路径、模型名称严禁直接写死在代码中。
- **类型安全**: 优先使用 Freezed 定义模型，利用 Dart 模式匹配处理状态。
- **单一职责**: 每个 Widget 或 Controller 只负责一件事。

### 4.2 国际化 (I18n)
- **多语言维护**: 所有的文案必须统一维护在 `lib/i18n/` 下的 JSON 文件中。
- **基准语言**: `zh.i18n.json` 为主开发语言，新增 Key 后需同步更新到 `en`, `ja` 等文件。
- **代码访问**: 严禁在 UI 中直接使用中文字符串，必须通过 `t.xxx.yyy` 访问翻译生成的强类型 Key。

---

## 5. 文档与维护

### 5.1 更新日志 (Changelogs)
- **存放路径**: `docs/Changelogs/`
- **规范**: 每次重大版本发布（或 Milestone 达成）后，在该目录下创建一个以版本号命名的 Markdown 文件（如 `v1.0.0.md`），详细记录该版本的变更项。

### 5.2 代码注释
- **强制中文**: 所有注释使用中文，重点解释“为什么这样做”而非“在做什么”。

---

## 6. AI 协作规约 (Instructions for AI)

当 AI 编写代码时：
1. **I18n 优先**: 新增 UI 必须先定义翻译键，禁止硬编码。
2. **绝对路径**: Import 优先使用 `package:baishou/...`。
3. **分拆策略**: 单一 `build` 方法超过 80 行即应考虑拆分子组件。
4. **错误处理**: 利用 `AsyncValue` 优雅处理数据加载的空、错、忙状态。
