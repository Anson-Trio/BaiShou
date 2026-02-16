import 'package:drift/drift.dart';

/// 日记表
/// 存储用户每天的日记内容
class Diaries extends Table {
  /// 主键 ID (自增)
  IntColumn get id => integer().autoIncrement()();

  /// 日记日期 (建立索引方便查询)
  DateTimeColumn get date => dateTime()();

  /// 日记内容 (Markdown格式)
  TextColumn get content => text()();

  /// 标签 (以逗号分隔的字符串存储，简单起见)
  TextColumn get tags => text().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
