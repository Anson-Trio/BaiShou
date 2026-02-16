# 白守技术开发规范 (Baishou Technical Specification)

**所有的注释与说明文本强制使用中文书写**

---

## 1. 后端开发准则 (Backend Development Standards)

### 1.1 响应格式规范

- **统一响应对象**：所有 Controller 接口必须返回 `com.Baishou.common.result.SakuraReply<T>`
- **异常处理体系**：
  - 业务逻辑异常必须抛出 `com.Baishou.common.exception.BusinessException`
  - 严禁在 Controller 层捕获异常后返回错误代码，应统一交由 `GlobalExceptionHandler` 处理

### 1.2 包结构与分层

```
com.Baishou
├── controller      # 控制层：仅负责参数校验、调用 Service、返回响应
├── service         # 服务层：业务逻辑实现
│   └── impl        # 服务实现类
├── mapper          # 数据访问层：MyBatis-Plus Mapper 接口
├── model           # 数据模型
│   ├── entity      # 数据库实体类
│   ├── dto         # 数据传输对象（用于接口入参）
│   └── vo          # 视图对象（用于接口出参）
├── config          # 配置类
├── aspect          # 切面类
├── common          # 公共模块
│   ├── exception   # 异常定义
│   ├── result      # 响应封装
│   └── constant    # 常量定义
└── util            # 工具类
```

- **禁止跨层调用**：Controller 不得直接调用 Mapper，Service 不得直接操作 HttpServletRequest
- **DTO/VO 分离**：严禁将 Entity 直接作为接口参数或返回值

### 1.3 命名规范

#### 类命名

- Controller: `{模块}Controller`，如 `FileController`
- Service 接口: `{模块}Service`，如 `FileService`
- Service 实现: `{模块}ServiceImpl`，如 `FileServiceImpl`
- Mapper: `{模块}Mapper`，如 `FileMapper`
- Entity: 业务实体名，如 `File`, `User`
- DTO: `{操作}{模块}DTO`，如 `CreateFileDTO`, `UpdateUserDTO`
- VO: `{模块}VO`，如 `FileVO`, `UserVO`

#### 方法命名

- 查询单个: `get{Entity}By{Condition}`，如 `getFileById`
- 查询列表: `list{Entity}By{Condition}`，如 `listFilesByUserId`
- 分页查询: `page{Entity}By{Condition}`，如 `pageFilesByKeyword`
- 新增: `create{Entity}` 或 `add{Entity}`
- 修改: `update{Entity}`
- 删除: `delete{Entity}` 或 `remove{Entity}`
- 判断存在: `exists{Entity}By{Condition}`

#### 变量命名

- 布尔类型: `is{Description}`, `has{Description}`, `can{Description}`
- 集合类型: 复数形式，如 `files`, `users`
- 常量: 全大写下划线分隔，如 `MAX_FILE_SIZE`, `DEFAULT_PAGE_SIZE`

### 1.4 配置管理与日志

- **存放位置**：所有配置类必须存放在 `com.BaiShou.config` 及其子包下
- **配置注入方式**：优先使用 `@ConfigurationProperties` 绑定 `yml` 文件中的 prefix
- **强制控制台日志**：**所有 Profile (Local, Dev, Prod) 必须完整输出控制台日志**。
- **日志限制**：禁止在代码中硬编码日志格式，相关逻辑应在 `LoggingConfig` 中统一维护，且不得根据 Profile 过滤控制台输出。
- **环境隔离**：敏感配置必须使用环境变量或配置中心，严禁硬编码。

### 1.5 数据库规范

#### 表设计

- **命名规则**：全小写下划线分隔，如 `tb_user`, `tb_file`
- **主键字段**：统一使用 `id`，类型为 `BIGINT`，使用雪花算法生成
- **时间字段**：
  - 创建时间: `create_time` (DATETIME)
  - 更新时间: `update_time` (DATETIME)
  - 删除时间: `delete_time` (DATETIME，软删除场景)
- **用户追踪**：
  - `create_user` (BIGINT): 创建人 ID
  - `update_user` (BIGINT): 更新人 ID
- **软删除**：使用 `deleted` (TINYINT)，0 表示未删除，1 表示已删除
- **枚举字段**：使用 TINYINT 或 VARCHAR，必须在注释中说明枚举值含义

#### 索引规范

- 单表索引数量不超过 5 个
- 单个索引字段数不超过 5 个
- 查询条件字段必须建立索引
- 避免在低选择性字段（如性别）上建立索引

### 1.6 安全规范

- **参数校验**：所有 DTO 必须使用 `@Valid` 注解进行参数校验
- **SQL 注入**：禁止使用字符串拼接构造 SQL，必须使用 MyBatis 参数绑定
- **XSS 防护**：用户输入的文本内容必须进行 HTML 转义
- **权限校验**：敏感接口必须使用 `@PreAuthorize` 注解进行权限校验

### 1.7 性能规范

- **分页查询**：列表查询必须使用分页，禁止一次性查询全部数据
- **慢查询**：单次查询时间不得超过 1 秒，复杂查询需使用索引优化
- **缓存策略**：热点数据必须使用 Redis 缓存，缓存时间根据业务特性设置
- **异步处理**：耗时操作（如文件上传、邮件发送）必须使用异步或消息队列

### 1.8 文档要求

- **类注释**：所有 public 类必须添加类级别 JavaDoc，说明类的职责
- **方法注释**：所有 public 方法必须添加 JavaDoc，说明参数、返回值、异常
- **复杂逻辑**：复杂的业务逻辑必须添加行内注释，说明设计思路
- **接口文档**：使用 Knife4j 注解生成 API 文档，必须包含请求示例和响应示例

---

## 2. 前端开发准则 (Frontend Development Standards)

### 2.1 接口层解耦 (API Service Isolation)

- **严禁直接请求**：禁止在视图组件（View/Component）中直接调用请求库
- **模块化抽取**：所有接口请求逻辑必须抽取至 `src/api/` 目录，并按业务模块划分
- **类型约束**：每个 API 函数必须定义 Request 和 Response 的 TypeScript 类型

### 2.2 项目结构

```
src/
├── api/              # API 请求封装
├── assets/           # 静态资源（图片、字体等）
├── components/       # 公共组件
├── views/            # 页面组件
├── router/           # 路由配置
├── stores/           # Pinia 状态管理
├── utils/            # 工具函数
├── styles/           # 全局样式
└── types/            # TypeScript 类型定义
```

### 2.3 组件规范

#### 命名规则

- 组件文件名：大驼峰，如 `FileUpload.vue`
- 组件注册名：大驼峰，如 `FileUpload`
- Props 命名：小驼峰，如 `maxSize`, `acceptTypes`
- Events 命名：小驼峰，如 `update:modelValue`, `uploadSuccess`

#### 组件设计原则

- **单一职责**：一个组件只负责一个功能
- **Props 向下，Events 向上**：父组件通过 Props 传递数据，子组件通过 Events 触发事件
- **避免过深嵌套**：组件嵌套层级不超过 4 层
- **可复用性**：公共组件必须支持通过 Props 自定义行为

#### Props 定义

- 必须使用 TypeScript 定义 Props 类型
- 必须提供默认值（除非是必填项）
- 必须添加注释说明 Props 用途

```typescript
interface Props {
  /** 最大文件大小（MB） */
  maxSize?: number;
  /** 允许的文件类型 */
  acceptTypes?: string[];
  /** 是否禁用 */
  disabled?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  maxSize: 10,
  acceptTypes: () => ["image/*"],
  disabled: false,
});
```

### 2.4 状态管理

- **Token 管理**：鉴权 Token 的注入必须在 Axios 全局拦截器中完成
- **全局状态**：使用 Pinia 管理全局状态，按模块划分 Store
- **本地状态**：组件内部状态使用 `ref` 或 `reactive`，不需要提升到全局

### 2.5 样式规范

#### CSS 命名

- 使用 BEM 命名规范：`block__element--modifier`
- 类名全小写，单词用连字符分隔

```css
.file-upload {
}
.file-upload__button {
}
.file-upload__button--disabled {
}
```

#### 样式组织

- 使用 CSS 变量管理主题色、间距等
- 公共样式提取到 `src/styles/` 目录
- 组件样式使用 `<style scoped>`

### 2.6 TypeScript 规范

- **禁用 any**：严禁使用 `any` 类型，必须明确定义类型
- **接口优先**：优先使用 `interface` 定义对象类型
- **类型导出**：公共类型必须导出供其他模块使用

---

## 3. Git 工作流规范

### 3.1 分支管理

- `main`: 主分支，始终保持稳定可发布状态
- `develop`: 开发分支，日常开发在此分支进行
- `feature/{功能名}`: 功能分支，从 develop 拉取，开发完成后合并回 develop
- `hotfix/{问题描述}`: 紧急修复分支，从 main 拉取，修复后合并回 main 和 develop

### 3.2 提交信息规范

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type**: 提交类型
  - `feat`: 新功能
  - `fix`: 修复 bug
  - `docs`: 文档更新
  - `style`: 代码格式调整（不影响功能）
  - `refactor`: 重构（不是新功能也不是修复 bug）
  - `test`: 测试相关
  - `chore`: 构建或辅助工具变动
- **scope**: 影响范围，如 `auth`, `file`, `config`
- **subject**: 简短描述，不超过 50 字符
- **body**: 详细描述（可选）
- **footer**: 关闭的 issue 或 breaking changes（可选）

**示例**：

```
feat(file): 新增文件分片上传功能

支持大文件分片上传，自动计算 MD5 校验
优化上传进度显示

Closes #123
```

---

## 4. 基础设施规范

### 4.1 Profile 管理

- **全环境一致性**：**所有 Profile 下的日志输出行为必须一致，均需输出控制台日志**。
- **参数解耦**：非通用参数严禁写入 `application.yml` 主文件。

### 4.2 容器管理

- **权限基准**：Docker 数据目录必须确保宿主机具备读写权限
- **资源限制**：生产环境容器必须设置内存和 CPU 限制
- **健康检查**：关键服务必须配置健康检查

---
