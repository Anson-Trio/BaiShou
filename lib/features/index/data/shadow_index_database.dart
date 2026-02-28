import 'dart:io';

import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'shadow_index_database.g.dart';

/// 影子索引库服务 (Shadow Index Database)
/// 负责操作当前活跃 Vault 专属的 `.baishou/shadow_index.db`
@Riverpod(keepAlive: true)
class ShadowIndexDatabase extends _$ShadowIndexDatabase {
  Database? _db;

  @override
  FutureOr<void> build() async {
    // 监听活跃 Vault 的变化，一旦切换立刻执行重载逻辑
    ref.listen(vaultServiceProvider, (previous, next) {
      if (next.value != null && next.value?.name != previous?.value?.name) {
        _reconnectDatabase(next.value!.name);
      }
    });

    final activeVault = await ref.read(vaultServiceProvider.future);
    if (activeVault != null) {
      await _initDatabase(activeVault.name);
    }
  }

  Future<void> _reconnectDatabase(String vaultName) async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
    await _initDatabase(vaultName);
  }

  Future<void> _initDatabase(String vaultName) async {
    final pathProvider = ref.read(storagePathServiceProvider);
    final sysDir = await pathProvider.getVaultSystemDirectory(vaultName);
    final dbPath = p.join(sysDir.path, 'shadow_index.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // 创建基础镜像表：记录物理文件的元数据和状态
        await db.execute('''
          CREATE TABLE journals_index (
            id INTEGER PRIMARY KEY,
            file_path TEXT UNIQUE NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            weather TEXT,
            mood TEXT,
            location TEXT,
            location_detail TEXT,
            is_favorite INTEGER DEFAULT 0,
            has_media INTEGER DEFAULT 0
          )
        ''');

        // 创建全文检索虚拟表 (FTS5) - 未来扩展用
        await db.execute('''
          CREATE VIRTUAL TABLE journals_fts USING fts5(
            content,
            tags,
            content='journals_index',
            content_rowid='id'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 留作日后挂接 sqlite-vec 向量虚拟表用
      },
    );
  }

  /// 提供对外安全的 DB 访问句柄
  Future<Database> get database async {
    if (_db == null || !_db!.isOpen) {
      final activeVault = await ref.read(vaultServiceProvider.future);
      if (activeVault == null) {
        throw Exception('数据库未挂载，没有检测到可用的 Vault。');
      }
      await _initDatabase(activeVault.name);
    }
    return _db!;
  }

  /// 插入或更新单条日志索引记录
  Future<void> upsertJournalIndex({
    required int id,
    required String filePath,
    required String date,
    required String createdAt,
    required String updatedAt,
    required String contentHash,
    String? weather,
    String? mood,
    String? location,
    String? locationDetail,
    required bool isFavorite,
    required bool hasMedia,
    required String rawContent, // 用于 FTS
    required String tags, // 用于 FTS
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('journals_index', {
        'id': id,
        'file_path': filePath,
        'date': date,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'content_hash': contentHash,
        'weather': weather,
        'mood': mood,
        'location': location,
        'location_detail': locationDetail,
        'is_favorite': isFavorite ? 1 : 0,
        'has_media': hasMedia ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // FTS 相关表的同步 (先清洗旧记录，再拉取新记录)
      await txn.rawDelete('DELETE FROM journals_fts WHERE rowid = ?', [id]);
      await txn.rawInsert(
        'INSERT INTO journals_fts(rowid, content, tags) VALUES(?, ?, ?)',
        [id, rawContent, tags],
      );
    });
  }

  /// 从索引层删除一条记录
  Future<void> deleteJournalIndex(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('journals_index', where: 'id = ?', whereArgs: [id]);
      await txn.rawDelete('DELETE FROM journals_fts WHERE rowid = ?', [id]);
    });
  }

  /// [DEBUG/DEV] 强制关停释放资源
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
