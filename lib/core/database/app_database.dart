import 'package:baishou/core/database/tables/diaries.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

/// 数据库类
@DriftDatabase(tables: [Diaries, Summaries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // 在版本 2 中，我们可能对日记表进行了调整
          // 注意：m.deleteTable(diaries) 会删除所有现有数据，仅在开发初期使用
          // 如果是生产环境，应该使用 m.addColumn 等方式进行增量更新
          await m.deleteTable('diaries');
          await m.createTable(diaries);
        }
      },
    );
  }
}

/// 使用 drift_flutter 打开数据库连接
/// 它会自动根据平台（Mobile/Desktop/Web）选择最佳的存储和运行时实现
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'baishou',
    // 如果需要自定义存储位置或进行更复杂的配置，可以在这里添加参数
    // drift_flutter 会自动处理 Web 端的 WASM 加载
  );
}

/// 提供数据库实例
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}
