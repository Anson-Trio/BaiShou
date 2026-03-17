import 'dart:io';

import 'package:baishou/core/database/tables/diaries.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

/// 主数据库（日记 + 总结）
/// 使用 NativeDatabase 替代 drift_flutter 的 driftDatabase()，统一 SQLite 技术栈
@DriftDatabase(tables: [Diaries, Summaries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.deleteTable('diaries');
          await m.createTable(diaries);
        }
      },
    );
  }
}

/// 使用 NativeDatabase + LazyDatabase 打开数据库连接
/// 替代原来的 drift_flutter driftDatabase()
QueryExecutor _openConnection(StoragePathService pathService) {
  return LazyDatabase(() async {
    final sysDir = await pathService.getGlobalRegistryDirectory();
    final dbFile = File(p.join(sysDir.path, 'baishou.sqlite'));
    return NativeDatabase.createInBackground(dbFile);
  });
}

/// 提供数据库实例
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final pathService = ref.watch(storagePathServiceProvider);
  return AppDatabase(_openConnection(pathService));
}
