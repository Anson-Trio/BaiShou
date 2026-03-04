import 'package:baishou/i18n/strings.g.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import 'package:baishou/features/diary/data/vault_index_notifier.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/entities/diary_meta.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/index/data/shadow_index_sync_service.dart';
import 'package:baishou/features/storage/domain/services/journal_file_service.dart';
import 'package:baishou/features/storage/domain/services/file_state_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_repository_impl.g.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  final ShadowIndexDatabase _dbService;
  final JournalFileService _fileService;
  final ShadowIndexSyncService _syncService;
  final VaultIndex _vaultIndex;
  final FileStateScheduler _fileStateScheduler;

  // ==========================================
  // 响应式流处理部分 (Reactive Stream)
  // ==========================================

  // 使用 BroadcastStreamController 来模拟原来数据库(如 drift)的实时监听机制。
  // 它作为一个中转站：底层数据发生任何变动时，我们手动向这个流中“喂”一份最新的列表数据，
  // 订阅了这个流的 UI 界面（如日记列表页）就会自动接收到推送并完成重绘。
  final _streamController = StreamController<List<Diary>>.broadcast();

  DiaryRepositoryImpl(
    this._dbService,
    this._fileService,
    this._syncService,
    this._vaultIndex,
    this._fileStateScheduler,
  ) {
    // 仓库初始化时，立即执行一次全量扫描，确保物理文件和数据库影子索引一致（支持手动删除同步）
    _initRepositoryData();
  }

  Future<void> _initRepositoryData() async {
    try {
      // 1. 初始化时先执行一次全量扫描，拉平现有状态
      await _syncService.fullScanVault();

      // 2. 挂载实时文件系统监听器事件流
      _syncService.syncEvents.listen((event) {
        debugPrint(
          'DiaryRepository: External sync event for ${event.path}, refreshing list.',
        );
        _emitAllDiaries();
      });
    } catch (e) {
      debugPrint('DiaryRepository: Full scan failed on startup: $e');
    } finally {
      // 2. 无论如何都触发一次流推送，确保 UI 有数据显示
      _emitAllDiaries();
    }
  }

  void dispose() {
    _streamController.close();
  }

  // 简单的扩展：为了支持带 limit 的 watch，我们维护一个当前的 limit 状态
  int? _currentWatchLimit;

  /// 【内部方法】：触发数据更新推送
  /// 它会从极速读取的 SQLite 影子表中抓取最新列表，并塞入广播流中。
  Future<void> _emitAllDiaries() async {
    try {
      final list = await getAllDiaries(limit: _currentWatchLimit);
      if (!_streamController.isClosed) {
        _streamController.add(list);
      }
    } catch (e, stack) {
      debugPrint('DiaryRepository: Failed to emit diaries. Error: $e');
      if (!_streamController.isClosed) {
        _streamController.addError(e, stack);
      }
    }
  }

  /// 【核心监听入口】：供 UI 层订阅
  @override
  Stream<List<Diary>> watchAllDiaries() {
    _currentWatchLimit = null;
    _emitAllDiaries();
    return _streamController.stream;
  }

  @override
  Stream<List<Diary>> watchDiaries({int? limit}) {
    _currentWatchLimit = limit;
    _emitAllDiaries();
    return _streamController.stream;
  }

  /// 从 SQLite 查询数据列表并转换为实体 (高速无头查询)
  Future<List<Diary>> _queryDiaries({
    String? where,
    List<Object?>? whereArgs,
    int? limit,
    int? offset,
  }) async {
    final db = await _dbService.database;
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

    final rows = await db.rawQuery(sql, whereArgs);

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
    final db = await _dbService.database;
    final rows = await db.query(
      'journals_index',
      where: 'id = ?',
      whereArgs: [id],
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
  Future<void> saveDiary({
    int? id,
    required DateTime date,
    required String content,
    List<String> tags = const [],
    // 扩展字段可以通过可选参数传，这里暂时保持和原 Repository 接口一致以防外部调用报错
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
      final db = await _dbService.database;
      final rows = await db.query(
        'journals_index',
        columns: ['created_at', 'date'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty) {
        final oldDateStr = rows.first['date'] as String;
        final oldCreatedAtStr = rows.first['created_at'] as String;
        existingCreatedAt = DateTime.parse(oldCreatedAtStr);

        // 比较逻辑日期 YYYY-MM-DD
        final fmt = DateFormat('yyyy-MM-dd');
        if (oldDateStr != fmt.format(date)) {
          // 如果逻辑日期变了，我们需要记录旧日期以便删除旧文件
          oldFileDate = DateTime.parse(oldDateStr);
        }
      }
    }

    final diary = Diary(
      id: targetId,
      date: date,
      createdAt: existingCreatedAt ?? now, // 保持真实的创建时间
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
      // --- 核心"双写"逻辑开始 ---

      // 第一步：如果日期发生变化，先行清理旧物理文件
      if (oldFileDate != null) {
        try {
          await _fileService.deleteJournalFile(oldFileDate);
        } catch (e) {
          debugPrint(
            'DiaryRepository: Failed to delete old file during move: $e',
          );
        }
      }

      // 第二步：给调度器发送 suppress 信号，防止 Watcher 回声
      final filePath = await _fileService.getExactFilePath(diary.date);
      _fileStateScheduler.suppressPath(filePath);

      // 第三步：保存物理文件 (Markdown)
      await _fileService.writeJournal(diary);

      // 第三步：将这次保存操作强同步给 SQLite 影子图谱
      await _syncService.syncJournal(diary.date);

      // 第四步：直接更新 VaultIndex（UI 立即响应）
      _vaultIndex.upsert(
        DiaryMeta(
          id: diary.id,
          date: diary.date,
          preview: diary.content.length > 120
              ? diary.content.substring(0, 120)
              : diary.content,
          tags: diary.tags,
          updatedAt: diary.updatedAt,
        ),
      );

      // 兼容旧流
      _emitAllDiaries();

      // --- 核心“双写”逻辑结束 ---
    } catch (e) {
      debugPrint(
        'DiaryRepository: Failed to save diary (hybrid mode). Error: $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> batchSaveDiaries(List<Diary> diaries) async {
    for (final d in diaries) {
      await _fileService.writeJournal(d);
      await _syncService.syncJournal(d.date);
    }
    _emitAllDiaries();
  }

  @override
  Future<void> deleteDiary(int id) async {
    final db = await _dbService.database;
    // 1. 首先查询数据库，获取该日记的创建时间，以便定位物理文件
    final rows = await db.query(
      'journals_index',
      columns: ['date'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (rows.isNotEmpty) {
      // 2. suppress 路径，再尝试同步删除物理磁盘上的 Markdown 文件
      final dateStr = rows.first['date'] as String;
      try {
        final logicalDate = DateTime.parse(dateStr);
        // 借用调度器屏蔽这条路径后续不可预测的监听杂音
        final filePath = await _fileService.getExactFilePath(logicalDate);
        _fileStateScheduler.suppressPath(filePath);
        // 第一步：清理物理文件和缓存
        await _fileService.deleteJournalFile(logicalDate);
      } catch (e) {
        // 物理删除失败后，我们依然继续删除索引，但需要把这个“部分失效”的信息传给 UI
        await _dbService.deleteJournalIndex(id);
        _emitAllDiaries();
        throw Exception(t.common.errors.physical_delete_failed);
      }
    }

    // 3. 删除影子索引表中的记录
    await _dbService.deleteJournalIndex(id);

    // 4. 直接从 VaultIndex 内存删除（UI 立即响应）
    _vaultIndex.remove(id);

    // 5. 兼容旧流
    _emitAllDiaries();
  }

  @override
  Future<void> deleteAllDiaries() async {
    final db = await _dbService.database;
    await db.delete('journals_index');
    await db.rawDelete('DELETE FROM journals_fts');
    _emitAllDiaries();
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
    final db = await _dbService.database;
    final result = await db.rawQuery(
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
  final fileStateScheduler = ref.watch(fileStateSchedulerProvider.notifier);

  final repo = DiaryRepositoryImpl(
    dbService,
    fileService,
    syncService,
    vaultIndex,
    fileStateScheduler,
  );

  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
}
