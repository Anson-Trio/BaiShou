import 'package:drift/drift.dart';

/// Agent 会话表
class AgentSessions extends Table {
  /// 会话 ID (UUID)
  TextColumn get id => text()();

  /// 会话标题（自动生成或用户自定义）
  TextColumn get title => text().withDefault(const Constant('新对话'))();

  /// 关联的 Vault 名称
  TextColumn get vaultName => text()();

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

  /// 累计费用（美元，乘以 1000000 存为整数以避免浮点误差）
  IntColumn get totalCostMicros =>
      integer().withDefault(const Constant(0))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 最后活跃时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Agent 消息表
class AgentMessages extends Table {
  /// 消息 ID
  TextColumn get id => text()();

  /// 所属会话 ID (外键)
  TextColumn get sessionId =>
      text().references(AgentSessions, #id)();

  /// 消息角色 (system / user / assistant / tool)
  TextColumn get role => text()();

  /// 消息文本内容
  TextColumn get content => text().nullable()();

  /// 工具调用信息 (JSON 序列化的 List<ToolCall>)
  TextColumn get toolCalls => text().nullable()();

  /// 工具结果对应的 call ID
  TextColumn get toolCallId => text().nullable()();

  /// 消息顺序号（用于排序）
  IntColumn get orderIndex => integer()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
