import 'package:baishou/i18n/strings.g.dart';
import 'dart:async';

import 'package:baishou/features/diary/domain/entities/diary.dart';
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

  // ==========================================
  // 响应式流处理部分 (Reactive Stream)
  // ==========================================

  // 使用 BroadcastStreamController 来模拟原来数据库(如 drift)的实时监听机制。
  // 它作为一个中转站：底层数据发生任何变动时，我们手动向这个流中“喂”一份最新的列表数据，
  // 订阅了这个流的 UI 界面（如日记列表页）就会自动接收到推送并完成重绘。
  final _streamController = StreamController<List<Diary>>.broadcast();

  DiaryRepositoryImpl(this._dbService, this._fileService, this._syncService) {
    // 仓库初始化时，立即执行一次全量拉取，确保订阅流的 UI 能第一时间拿到数据
    _emitAllDiaries();
  }

  void dispose() {
    _streamController.close();
  }

  /// 【内部方法】：触发数据更新推送
  /// 它会从极速读取的 SQLite 影子表中抓取最新列表，并塞入广播流中。
  Future<void> _emitAllDiaries() async {
    try {
      final list = await getAllDiaries();
      if (!_streamController.isClosed) {
        _streamController.add(list);
      }
    } catch (e) {
      // 这里的错误通常不应该中断主流程，仅作为调试日志记录
      debugPrint('DiaryRepository: Failed to emit diaries. Error: $e');
    }
  }

  /// 【核心监听入口】：供 UI 层订阅
  /// 当 UI 层调用 watchAllDiaries().listen(...) 时，
  /// 1. 它会立即触发一次 _emitAllDiaries() 抓取当前快照。
  /// 2. 之后只要有任何写操作（save/delete）成功，都会再次触发 _emitAllDiaries()。
  /// 这种机制保证了物理文件存储也能拥有像数据库一样的实时响应体验。
  @override
  Stream<List<Diary>> watchAllDiaries() {
    _emitAllDiaries();
    return _streamController.stream;
  }

  /// 从 SQLite 查询数据列表并转换为实体 (高速无头查询)
  Future<List<Diary>> _queryDiaries({
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await _dbService.database;
    // 联合查询 FTS 获取文本与标签
    final sql =
        '''
      SELECT i.*, f.content, f.tags
      FROM journals_index i
      LEFT JOIN journals_fts f ON i.id = f.rowid
      ${where != null ? 'WHERE $where' : ''}
      ORDER BY i.date DESC, i.created_at DESC
    ''';

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
  Future<List<Diary>> getAllDiaries() async {
    return _queryDiaries();
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
    final createdAtStr = row['created_at'] as String;
    final createTarget = DateTime.parse(createdAtStr);

    // [关键边界]：为了获得完整的结构（含附件），使用物理文件直接解析以获取全真实例
    final diary = await _fileService.readJournal(createTarget);
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

    final diary = Diary(
      id: targetId,
      date: date,
      createdAt: id == null ? now : date, // 如果是强补更新，应该读出再写，这里简化处理 createdAt
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
      // --- 核心“双写”逻辑开始 ---

      // 第一步：保存物理文件 (Markdown)
      // 这是“数据主权”的物理载体。即使应用没了，这行代码产生的文件也是你永恒的记忆备份。
      await _fileService.writeJournal(diary);

      // 第二步：将这次保存操作强同步给 SQLite 影子图谱
      // 影子索引不存储正文（只存搜索分词），它是物理文件的镜像，用于支撑高性能的列表展示和全文搜索。
      // 我们以 createdAt 为基准路径查找物理文件并进行索引同步。
      await _syncService.syncJournal(diary.createdAt);

      // 第三步：刷新 UI 流
      // 完成“双写”后，最后一步就是通过广播流通知所有正在展示日记列表的 UI：
      // “喂，数据变了，赶紧重新加载并显示最新的一条吧！”
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
      await _syncService.syncJournal(d.createdAt);
    }
    _emitAllDiaries();
  }

  @override
  Future<void> deleteDiary(int id) async {
    final db = await _dbService.database;
    // 1. 首先查询数据库，获取该日记的创建时间，以便定位物理文件
    final rows = await db.query(
      'journals_index',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (rows.isNotEmpty) {
      // 2. 尝试同步删除物理磁盘上的 Markdown 文件
      final createdAtStr = rows.first['created_at'] as String;
      try {
        final createdAt = DateTime.parse(createdAtStr);
        await _fileService.deleteJournalFile(createdAt);
      } catch (e) {
        // 物理删除失败后，我们依然继续删除索引，但需要把这个“部分失效”的信息传给 UI
        await _dbService.deleteJournalIndex(id);
        _emitAllDiaries();
        throw Exception(t.common.errors.physical_delete_failed);
      }
    }

    // 3. 删除影子索引表中的记录
    await _dbService.deleteJournalIndex(id);

    // 4. 发送流通知，触发 UI 刷新
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
}

@Riverpod(keepAlive: true)
DiaryRepository diaryRepository(Ref ref) {
  final dbService = ref.watch(shadowIndexDatabaseProvider.notifier);
  final fileService = ref.watch(journalFileServiceProvider.notifier);
  final syncService = ref.watch(shadowIndexSyncServiceProvider.notifier);

  final repo = DiaryRepositoryImpl(dbService, fileService, syncService);

  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
}
