import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

part 'shadow_index_database.g.dart';

/// 影子索引库服务 (Shadow Index Database)
/// 负责操作当前活跃 Vault 专属的 `.baishou/shadow_index.db`
///
/// 使用 sqlite3 包直接操作，统一白守 SQLite 技术栈。
@Riverpod(keepAlive: true)
class ShadowIndexDatabase extends _$ShadowIndexDatabase {
  sql.Database? _db;

  @override
  FutureOr<void> build() async {
    final vaultState = ref.watch(vaultServiceProvider);

    if (vaultState.value != null) {
      await _initDatabase(vaultState.value!.name);
    }

    ref.onDispose(() async {
      close();
    });
  }

  Future<void> _initDatabase(String vaultName) async {
    final pathProvider = ref.read(storagePathServiceProvider);
    final sysDir = await pathProvider.getVaultSystemDirectory(vaultName);
    final dbPath = p.join(sysDir.path, 'shadow_index.db');

    try {
      _db = sql.sqlite3.open(dbPath);
      _db!.execute('PRAGMA journal_mode=WAL');

      // 获取当前版本
      final versionResult = _db!.select('PRAGMA user_version');
      final currentVersion =
          versionResult.isNotEmpty ? versionResult.first['user_version'] as int : 0;

      if (currentVersion < 1) {
        _onCreate();
        _db!.execute('PRAGMA user_version = 2');
      } else if (currentVersion < 2) {
        _onUpgrade();
        _db!.execute('PRAGMA user_version = 2');
      }
    } catch (e) {
      debugPrint('ShadowIndexDatabase: Critical error opening database: $e');
      // 影子索引库可以安全地重建
      final file = File(dbPath);
      if (file.existsSync()) {
        debugPrint(
          'ShadowIndexDatabase: Destroying corrupted database at $dbPath and retrying...',
        );
        close();
        file.deleteSync();
        await _initDatabase(vaultName);
      } else {
        rethrow;
      }
    }
  }

  void _onCreate() {
    _db!.execute('''
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

    try {
      _db!.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS journals_fts USING fts5(
          content,
          tags,
          tokenize = 'unicode61'
        )
      ''');
    } catch (e) {
      debugPrint(
        'ShadowIndexDatabase: FTS5 not supported, falling back to standard table: $e',
      );
      _db!.execute('''
        CREATE TABLE IF NOT EXISTS journals_fts (
          rowid INTEGER PRIMARY KEY,
          content TEXT,
          tags TEXT
        )
      ''');
    }
  }

  void _onUpgrade() {
    try {
      _db!.execute('DROP TABLE IF EXISTS journals_fts');
    } catch (e) {
      debugPrint(
        'ShadowIndexDatabase: Failed to drop old FTS table: $e',
      );
    }

    try {
      _db!.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS journals_fts USING fts5(
          content,
          tags,
          tokenize = 'unicode61'
        )
      ''');
    } catch (e) {
      debugPrint('ShadowIndexDatabase: FTS5 fallback during upgrade: $e');
      try {
        _db!.execute('DROP TABLE IF EXISTS journals_fts');
      } catch (_) {}

      _db!.execute('''
        CREATE TABLE IF NOT EXISTS journals_fts (
          rowid INTEGER PRIMARY KEY,
          content TEXT,
          tags TEXT
        )
      ''');
    }
  }

  /// 提供对外安全的 DB 访问句柄
  sql.Database get database {
    if (_db == null) {
      throw Exception('数据库未挂载，没有检测到可用的 Vault。');
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
    required String rawContent,
    required String tags,
  }) async {
    final db = database;

    final stmt = db.prepare('''
      INSERT OR REPLACE INTO journals_index
        (id, file_path, date, created_at, updated_at, content_hash,
         weather, mood, location, location_detail, is_favorite, has_media)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      id, filePath, date, createdAt, updatedAt, contentHash,
      weather, mood, location, locationDetail,
      isFavorite ? 1 : 0, hasMedia ? 1 : 0,
    ]);
    stmt.dispose();

    // FTS 同步
    db.execute('DELETE FROM journals_fts WHERE rowid = ?', [id]);
    final ftsStmt = db.prepare(
      'INSERT INTO journals_fts(rowid, content, tags) VALUES(?, ?, ?)',
    );
    ftsStmt.execute([id, rawContent, tags]);
    ftsStmt.dispose();
  }

  /// 从索引层删除一条记录
  Future<void> deleteJournalIndex(int id) async {
    final db = database;
    db.execute('DELETE FROM journals_index WHERE id = ?', [id]);
    db.execute('DELETE FROM journals_fts WHERE rowid = ?', [id]);
  }

  /// 关闭数据库
  void close() {
    if (_db != null) {
      _db!.dispose();
      _db = null;
    }
  }
}
