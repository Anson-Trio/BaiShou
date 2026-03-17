import 'package:baishou/i18n/strings.g.dart';
import 'package:intl/intl.dart';

import 'package:baishou/features/diary/data/vault_index_notifier.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/entities/diary_meta.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/index/data/shadow_index_sync_service.dart';
import 'package:baishou/features/storage/domain/services/journal_file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_repository_impl.g.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  final ShadowIndexDatabase _dbService;
  final JournalFileService _fileService;
  final ShadowIndexSyncService _syncService;
  final VaultIndex _vaultIndex;

  DiaryRepositoryImpl(
    this._dbService,
    this._fileService,
    this._syncService,
    this._vaultIndex,
  ) {
    // 仓库初始化时，立即执行一次全量扫描，确保物理文件和数据库影子索引一致（支持手动删除同步）
    _initRepositoryData();
  }

  Future<void> _initRepositoryData() async {
    try {
      await _syncService.fullScanVault();
    } catch (e) {
      debugPrint('DiaryRepository: Full scan failed on startup: $e');
    }
  }

  /// 从 SQLite 查询数据列表并转换为实体 (高速无头查询)
  Future<List<Diary>> _queryDiaries({
    String? where,
    List<Object?>? whereArgs,
    int? limit,
    int? offset,
  }) async {
    final db = _dbService.database;
    // 联合查询 FTS 获取文本与标签
    String sql =
        '''
      SELECT i.*, f.content, f.tags
      FROM journals_index i
      LEFT JOIN journals_fts f ON i.id = f.rowid
      ${where != null ? 'WHERE $where' : ''}
      ORDER BY i.date DESC, i.id DESC
    ''';

    if (limit != null) {
      sql += ' LIMIT $limit';
      if (offset != null) {
        sql += ' OFFSET $offset';
      }
    }

    final rows = db.select(sql, whereArgs ?? []);

    return rows.map((row) {
      final tagStr = row['tags'] as String?;
      return Diary(
        id: row['id'] as int,
        date: DateTime.parse(row['date'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        content: row['content'] as String? ?? '',
        weather: row['weather'] as String?,
        mood: row['mood'] as String?,
        location: row['location'] as String?,
        locationDetail: row['location_detail'] as String?,
        isFavorite: (row['is_favorite'] as int?) == 1,
        // media 暂未在列表页全解析，如果后续需要可以通过读取文件补全
        tags: tagStr != null && tagStr.isNotEmpty
            ? tagStr.split(',')
            : const [],
      );
    }).toList();
  }

  @override
  Future<List<Diary>> getAllDiaries({int? limit, int? offset}) async {
    return _queryDiaries(limit: limit, offset: offset);
  }

  @override
  Future<Diary?> getDiaryById(int id) async {
    // 先查数据库获取这个文件的基本元数据
    final db = _dbService.database;
    final rows = db.select(
      'SELECT * FROM journals_index WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final dateStr = row['date'] as String;
    final logicalDate = DateTime.parse(dateStr);

    // [关键边界]：使用逻辑日期查找物理文件
    final diary = await _fileService.readJournal(logicalDate);
    return diary;
  }

  @override
  Future<Diary> saveDiary({
    int? id,
    required DateTime date,
    required String content,
    List<String> tags = const [],
    String? weather,
    String? mood,
    String? location,
    String? locationDetail,
    bool isFavorite = false,
    List<String> mediaPaths = const [],
  }) async {
    final targetId = id ?? DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();

    // 如果是更新操作，需要检查日期是否发生变化，以便清理旧的物理文件
    DateTime? oldFileDate;
    DateTime? existingCreatedAt;
    if (id != null) {
      final db = _dbService.database;
      final rows = db.select(
        'SELECT created_at, date FROM journals_index WHERE id = ?',
        [id],
      );
      if (rows.isNotEmpty) {
        final oldDateStr = rows.first['date'] as String;
        final oldCreatedAtStr = rows.first['created_at'] as String;
        existingCreatedAt = DateTime.parse(oldCreatedAtStr);

        final fmt = DateFormat('yyyy-MM-dd');
        if (oldDateStr != fmt.format(date)) {
          oldFileDate = DateTime.parse(oldDateStr);
        }
      }
    }

    final diary = Diary(
      id: targetId,
      date: date,
      createdAt: existingCreatedAt ?? now,
      updatedAt: now,
      content: content,
      tags: tags,
      weather: weather,
      mood: mood,
      location: location,
      locationDetail: locationDetail,
      isFavorite: isFavorite,
      mediaPaths: mediaPaths,
    );

    try {
      // --- 核心逻辑开始 ---

      if (oldFileDate != null) {
        try {
          await _fileService.deleteJournalFile(oldFileDate);
        } catch (e) {
          debugPrint('DiaryRepository: Failed to delete old file: $e');
        }
      }

      // 1. 物理写入（内部会根据物理文件是否存在来锁定 ID）
      // suppress 已内置于 writeJournal 内部，Watcher 会自动屏蔽
      debugPrint('DiaryRepository: Writing journal file...');
      final savedDiary = await _fileService.writeJournal(diary);

      // 2. 强同步 SQLite
      debugPrint('DiaryRepository: Syncing to SQLite...');
      await _syncService.syncJournal(savedDiary.date);

      // 3. 更新内存索引 (确保使用的是 savedDiary.id，即物理磁盘上的真实 ID)
      // 注意：syncJournal 也会触发事件更新 VaultIndex，这里手动呼叫 upsert 是为了 UI 响应更及时
      _vaultIndex.upsert(
        DiaryMeta(
          id: savedDiary.id,
          date: savedDiary.date,
          preview: savedDiary.content.length > 120
              ? savedDiary.content.substring(0, 120)
              : savedDiary.content,
          tags: savedDiary.tags,
          updatedAt: savedDiary.updatedAt,
        ),
      );

      return savedDiary;
    } catch (e) {
      debugPrint('DiaryRepository: Critical error during saveDiary: $e');
      rethrow;
    }
  }

  @override
  Future<void> batchSaveDiaries(List<Diary> diaries) async {
    for (final d in diaries) {
      await _fileService.writeJournal(d);
      await _syncService.syncJournal(d.date);
    }
    // 批量写完后强制刷新 VaultIndex 内存
    await _vaultIndex.forceReload();
  }

  @override
  Future<void> deleteDiary(int id) async {
    final db = _dbService.database;
    // 1. 首先查询数据库，获取该日记的创建时间，以便定位物理文件
    final rows = db.select(
      'SELECT date FROM journals_index WHERE id = ?',
      [id],
    );

    if (rows.isNotEmpty) {
      // 2. 尝试同步删除物理磁盘上的 Markdown 文件
      // suppress 已内置于 deleteJournalFile 内部
      final dateStr = rows.first['date'] as String;
      try {
        final logicalDate = DateTime.parse(dateStr);
        await _fileService.deleteJournalFile(logicalDate);
      } catch (e) {
        // 物理删除失败后，我们依然继续删除索引，但需要把这个“部分失效”的信息传给 UI
        await _dbService.deleteJournalIndex(id);
        _vaultIndex.remove(id);
        throw Exception(t.common.errors.physical_delete_failed);
      }
    }

    // 3. 删除影子索引表中的记录
    await _dbService.deleteJournalIndex(id);

    // 4. 直接从 VaultIndex 内存删除（UI 立即响应）
    _vaultIndex.remove(id);
  }

  @override
  Future<void> deleteAllDiaries() async {
    final db = _dbService.database;
    db.execute('DELETE FROM journals_index');
    db.execute('DELETE FROM journals_fts');
    _vaultIndex.clear();
  }

  @override
  Future<List<Diary>> getDiariesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return _queryDiaries(
      where: 'i.date >= ? AND i.date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
  }

  @override
  Future<List<Diary>> getDiariesInRange(DateTime start, DateTime end) {
    return getDiariesByDateRange(start, end);
  }

  @override
  Future<DateTime?> getOldestDiaryDate() async {
    final db = _dbService.database;
    final result = db.select(
      'SELECT MIN(date) as min_date FROM journals_index',
    );
    if (result.isNotEmpty && result.first['min_date'] != null) {
      return DateTime.tryParse(result.first['min_date'] as String);
    }
    return null;
  }

  @override
  Future<List<Diary>> getDiariesAfter({
    DateTime? dateCursor,
    int? idCursor,
    int limit = 50,
  }) async {
    // 如果没有游标，则直接从头开始获取
    if (dateCursor == null || idCursor == null) {
      return getAllDiaries(limit: limit);
    }

    // 使用联合游标查询：
    // 1. 日期比游标早的
    // 2. 日期相同但 ID 比游标小的 (处理同日期多条)
    // 【关键修复】：这里不能用 yyyy-MM-dd 截断，因为数据库里存的是完整的 ISO8601。
    // 如果截断了，会导致相同日期的项在逻辑上被判定为“相等”或因格式不匹配而失效。
    final dateStr = dateCursor.toIso8601String();

    return _queryDiaries(
      where: 'i.date < ? OR (i.date = ? AND i.id < ?)',
      whereArgs: [dateStr, dateStr, idCursor],
      limit: limit,
    );
  }
}

@Riverpod(keepAlive: true)
DiaryRepository diaryRepository(Ref ref) {
  final dbService = ref.watch(shadowIndexDatabaseProvider.notifier);
  final fileService = ref.watch(journalFileServiceProvider.notifier);
  final syncService = ref.watch(shadowIndexSyncServiceProvider.notifier);
  final vaultIndex = ref.watch(vaultIndexProvider.notifier);

  final repo = DiaryRepositoryImpl(
    dbService,
    fileService,
    syncService,
    vaultIndex,
  );

  return repo;
}
