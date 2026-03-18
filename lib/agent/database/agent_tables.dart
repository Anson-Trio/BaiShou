import 'package:drift/drift.dart';

/// Agent 会话表
class AgentSessions extends Table {
  /// 会话 ID (UUID)
  TextColumn get id => text()();

  /// 会话标题（自动生成或用户自定义）
  TextColumn get title => text().withDefault(const Constant('新对话'))();

  /// 关联的 Vault 名称
  TextColumn get vaultName => text()();

  /// 是否置顶
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// 独立的系统提示词（如果有）
  TextColumn get systemPrompt => text().nullable()();

  /// 使用的供应商 ID
  TextColumn get providerId => text()();

  /// 使用的模型 ID
  TextColumn get modelId => text()();

  /// 累计输入 token 数
  IntColumn get totalInputTokens =>
      integer().withDefault(const Constant(0))();

  /// 累计输出 token 数
  IntColumn get totalOutputTokens =>
      integer().withDefault(const Constant(0))();

  /// 累计费用（美元 × 1,000,000 存为整数）
  IntColumn get totalCostMicros =>
      integer().withDefault(const Constant(0))();

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
  TextColumn get sessionId =>
      text().references(AgentSessions, #id)();

  /// 消息角色 (system / user / assistant / tool)
  TextColumn get role => text()();

  /// 是否是压缩摘要消息
  BoolColumn get isSummary =>
      boolean().withDefault(const Constant(false))();

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
  TextColumn get messageId =>
      text().references(AgentMessages, #id)();

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
