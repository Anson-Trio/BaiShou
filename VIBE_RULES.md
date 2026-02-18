# 白守 (BaiShou) - VIBE & 开发规约

> **"以纯白的誓约，守护彼此的一生。"**
> 此文档定义了白守（BaiShou）项目的代码风格、架构规范与核心精神。
> 所有的注释与说明文本强制使用 **中文** 书写。

---

## 1. 核心精神 (The Vibe)

- **纯粹 (Purity)**: 代码逻辑必须像"白守"的名字一样干净、纯粹。拒绝过度封装，拒绝面条代码。
- **稳固 (Stability)**: 我们守护的是用户的**记忆**。数据层（Data Layer）必须极其健壮，绝不允许丢失用户的一个字符。
- **温暖 (Warmth)**: UI 交互应带有微小的灵动感（Micro-interactions）。即使是 MVP 版本，基础的动画曲线（Curves）和转场也应自然流畅（Sakura's Request）。
- **理性 (Logic)**: 架构分层严明，状态管理清晰。任何副作用（Side Effects）必须可追踪（Akatsuki's Mandate）。

---

## 2. 技术栈 (Tech Stack)

| 领域           | 选型                     | 说明                                                 |
| :------------- | :----------------------- | :--------------------------------------------------- |
| **Framework**  | **Flutter 3.x**          | 全平台统一体验                                       |
| **Language**   | **Dart 3.x**             | 开启 100% 空安全，使用 Records, Patterns 等新特性    |
| **State Mgmt** | **Riverpod (Generator)** | 使用 `@riverpod` 注解生成代码，拒绝手动编写 Provider |
| **Database**   | **Drift**                | 类型安全的 SQLite 封装，这也是为了数据的稳固性       |
| **Routing**    | **GoRouter**             | 声明式路由管理                                       |
| **UI System**  | **Material Design 3**    | 使用官方 M3 规范，配色需符合"白守"的素雅淡洁         |
| **Immutable**  | **Freezed**              | 数据类必须不可变，杜绝隐式状态修改                   |
| **AI Client**  | **Google Generative AI** | 直接调用 Gemini API (MVP阶段)                        |

---

## 3. 项目架构 (Architecture)

采用 **Feature-First + Riverpod Architecture** 分层结构。

```text
lib/
├── app.dart                # 应用入口 widget
├── bootstrap.dart          # 启动逻辑（日志、Crashlytics等）
├── main.dart               # main 函数
├── core/                   # 核心通用模块
│   ├── theme/              # 主题配置 (Sakura's Palette)
│   ├── constants/          # 常量 (API keys, constraints)
│   ├── utils/              # 通用工具
│   ├── database/           # Drift 数据库配置
│   └── router/             # GoRouter 配置
├── features/               # 业务模块 (按功能划分)
│   ├── diary/              # e.g. 日记模块
│   │   ├── data/           # Data Layer (Repository, DTOs, Sources)
│   │   ├── domain/         # Domain Layer (Entities, Logic)
│   │   └── presentation/   # Presentation Layer (Widgets, Controllers)
│   ├── summary/            # e.g. 总结模块
│   └── settings/           # e.g. 设置模块
└── l10n/                   # 国际化 (虽然目前仅中文，预留结构)
```

### 3.1 严格分层原则

- **Presentation Layer** 只能调用 **Application/Service Layer** 或 **Providers**。
- **UI Widget** 严禁包含复杂业务逻辑，必须委托给 `AsyncNotifier` 或 `Controller`。
- **Data Layer** 严禁直接暴露给 UI，必须通过 Repository 接口。

---

## 4. 编码规范 (Coding Standards)

### 4.1 Riverpod 规范

- **强制使用 Code Generation**:

  ```dart
  // ✅ Good
  @riverpod
  String hello(Ref ref) => 'Hello';

  // ❌ Bad
  final helloProvider = Provider((ref) => 'Hello');
  ```

- **Controller 命名**: 使用 `XxxController` 或 `XxxNotifier`。
- **State 命名**: 状态类尽量使用 Freezed 定义。

### 4.2 UI 开发规范 (Sakura's Aesthetic)

- **拆分组件**: 超过 100 行的 `build` 方法必须拆分为小组件。
- **常量抽取**: 所有的 Padding, Spacing, Colors 必须引用 `Theme.of(context)` 或常数文件，禁止硬编码 Magic Number。
- **中文字体**: 确保 Android/iOS 下中文字体显示优化，优先使用圆体或衬线体以体现"日记"的文学感。

### 4.3 异常处理 (Akatsuki's Shield)

- 使用 `AsyncValue` 处理加载与错误状态。
- **Error Handling**: 所有的 Repository 方法应捕获底层异常（如 SQLite 异常）并转换为 App 统一的 `Failure` 类。
- **Logging**: 关键路径必须打 Log，但禁止在生产环境输出敏感数据（日记内容）。

---

## 5. 数据模型与数据库 (Data & DB)

### 5.1 Drift Table 定义

- 表名使用 **蛇形命名法 (snake_case)**。
- 所有表必须包含 `created_at` 和 `updated_at`。
- 日记表 `diaries` 必须对 `date` 字段建立索引。

### 5.2 JSON 序列化

- 使用 `json_serializable` 和 `freezed`。
- 所有的 API 响应模型放在 `data/models` 下。
- 所有的业务实体模型放在 `domain/entities` 下。

---

## 6. Git 工作流 (Workflow)

遵循 **Conventional Commits**：

- `feat`: ✨ 新功能 (Sparkles for Sakura)
- `fix`: 🐛 修复 Bug
- `refactor`: ♻️ 重构
- `docs`: 📝 文档
- `chore`: 🔧 配置修改

**Commit 示例**:
`feat(diary): 增加日记编辑页面的 Markdown 预览功能`

---

## 7. AI 协作指令 (Instructions for AI)

当你（AI）编写代码时：

1. **优先生成完整代码**：不要只给片段，尽量给出可直接运行的完整文件或类。
2. **检查 Import**：确保 import 路径正确，优先使用绝对路径 `package:baishou/...`。
3. **解释逻辑**：在复杂逻辑处（尤其是 Riverpod 的状态流转），用注释解释清楚。
4. **UI 微调**：在编写 UI 时，主动添加 `const` 修饰符，主动思考 Padding 和对齐，确保 visually pleasing。
