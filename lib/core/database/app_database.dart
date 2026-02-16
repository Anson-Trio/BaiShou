import 'dart:io';

import 'package:baishou/core/database/tables/diaries.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

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
          // Recreate diaries table to remove unique constraint on date
          // Warning: This deletes existing diaries!
          await m.deleteTable('diaries');
          await m.createTable(diaries);
        }
      },
    );
  }
}

/// 打开数据库连接
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // 获取存储路径
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'baishou.sqlite'));

    // 针对 Android 的修复 (如果在 Android 上运行)
    if (Platform.isAndroid) {
      // await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // 针对 Linux/Windows 的临时修复 (确保 sqlite3 库加载)
    // 在纯 Dart 环境或某些桌面环境，可能需要显式加载动态库，
    // 但使用 drift_flutter_libs 通常会自动处理。

    return NativeDatabase.createInBackground(file);
  });
}

/// 提供数据库实例
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}
