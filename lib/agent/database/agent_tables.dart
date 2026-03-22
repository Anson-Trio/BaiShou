import 'package:drift/drift.dart';

/// Agent 会话表
class AgentSessions extends Table {
  /// 会话 ID (UUID)
  TextColumn get id => text()();

  /// 会话标题（自动生成或用户自定义）
  TextColumn get title => text().withDefault(const Constant('新对话'))();

  /// 关联的 Vault 名称
  TextColumn get vaultName => text()();

  /// 关联的伙伴 ID（nullable，null 表示无绑定伙伴）
  TextColumn get assistantId => text().nullable()();

  /// 是否置顶
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// 独立的系统提示词（如果有）
  TextColumn get systemPrompt => text().nullable()();

  /// 使用的供应商 ID
  TextColumn get providerId => text()();

  /// 使用的模型 ID
  TextColumn get modelId => text()();

  /// 累计输入 token 数
  IntColumn get totalInputTokens => integer().withDefault(const Constant(0))();

  /// 累计输出 token 数
  IntColumn get totalOutputTokens => integer().withDefault(const Constant(0))();

  /// 累计费用（美元 × 1,000,000 存为整数）
  IntColumn get totalCostMicros => integer().withDefault(const Constant(0))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 最后活跃时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Agent 消息表 — 存储消息元数据
/// 每条 Message 的具体内容拆分到 AgentParts 表
class AgentMessages extends Table {
  /// 消息 ID
  TextColumn get id => text()();

  /// 所属会话 ID (外键)
  TextColumn get sessionId => text().references(AgentSessions, #id)();

  /// 消息角色 (system / user / assistant / tool)
  TextColumn get role => text()();

  /// 是否是压缩摘要消息
  BoolColumn get isSummary => boolean().withDefault(const Constant(false))();

  /// 对应的用户提问消息 ID（针对 assistant 和 tool 消息）
  TextColumn get askId => text().nullable()();

  /// 使用的供应商 ID（assistant 消息才有）
  TextColumn get providerId => text().nullable()();

  /// 使用的模型 ID（assistant 消息才有）
  TextColumn get modelId => text().nullable()();

  /// 消息顺序号（用于排序）
  IntColumn get orderIndex => integer()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Agent 消息 Part 表 — 存储消息的细粒度内容
/// 一条 Message 包含多个 Part（文本段、工具调用、步骤统计等）
class AgentParts extends Table {
  /// Part ID
  TextColumn get id => text()();

  /// 所属消息 ID (外键)
  TextColumn get messageId => text().references(AgentMessages, #id)();

  /// 所属会话 ID（冗余索引，方便按会话查询）
  TextColumn get sessionId => text()();

  /// Part 类型 (text / tool / stepFinish / compaction)
  TextColumn get type => text()();

  /// Part 数据 (JSON blob，结构取决于 type)
  TextColumn get data => text()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// AI 伙伴表
/// 用户可创建不同角色的伙伴，每个伙伴有独立的提示词、头像和上下文窗口配置
class AgentAssistants extends Table {
  /// 伙伴 ID (UUID)
  TextColumn get id => text()();

  /// 伙伴名称
  TextColumn get name => text()();

  /// 表情符号（用于侧栏展示，null 时使用默认图标）
  TextColumn get emoji => text().nullable()();

  /// \u4f19\u4f34简介
  TextColumn get description => text().withDefault(const Constant(''))();

  /// 头像本地路径（null 表示使用默认头像）
  TextColumn get avatarPath => text().nullable()();

  /// 系统提示词
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();

  /// 是否为默认伙伴
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// 上下文窗口大小（发送给模型的历史消息条数）
  IntColumn get contextWindow => integer().withDefault(const Constant(20))();

  /// 绑定的供应商 ID（null 时使用全局模型）
  TextColumn get providerId => text().nullable()();

  /// 绑定的模型 ID（null 时使用全局模型）
  TextColumn get modelId => text().nullable()();

  /// 会话压缩阈值：对话达到此 token 数时触发压缩（0=关闭，默认 60000）
  IntColumn get compressTokenThreshold =>
      integer().withDefault(const Constant(60000))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 会话压缩快照表
/// 每次压缩生成一条快照记录（追加存储，不覆盖旧快照）
class CompressionSnapshots extends Table {
  /// 快照 ID（自增）
  IntColumn get id => integer().autoIncrement()();

  /// 所属会话 ID
  TextColumn get sessionId => text().references(AgentSessions, #id)();

  /// 压缩摘要内容
  TextColumn get summaryText => text()();

  /// 本快照覆盖到哪条消息的 ID（含）
  TextColumn get coveredUpToMessageId => text()();

  /// 本次压缩覆盖的消息总数（累计）
  IntColumn get messageCount => integer()();

  /// 摘要本身的 token 数（估算，可选）
  IntColumn get tokenCount => integer().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
