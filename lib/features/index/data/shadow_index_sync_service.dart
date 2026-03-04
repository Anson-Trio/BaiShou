import 'dart:async';
import 'dart:io';

import 'package:baishou/features/diary/domain/entities/diary_meta.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/storage/domain/services/journal_file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:baishou/features/storage/domain/services/file_state_scheduler.dart';

part 'shadow_index_sync_service.g.dart';

/// 日记同步结果
class JournalSyncResult {
  final DiaryMeta? meta; // 最新元数据（如果是删除则为 null）
  final bool isChanged; // 是否发生了变动（内容更新或删除）

  JournalSyncResult({this.meta, this.isChanged = false});
}

/// 包装后的同步事件，包含路径和同步结果
class JournalSyncEvent {
  final String path;
  final JournalSyncResult result;

  JournalSyncEvent(this.path, this.result);
}

/// 影子同步器 (Shadow Index Sync Service)
/// 负责将外部清洗过的路径变动，同步到 SQLite 数据库中，并通知给 VaultIndex
@Riverpod(keepAlive: true)
class ShadowIndexSyncService extends _$ShadowIndexSyncService {
  StreamController<JournalSyncEvent>? _syncEventController;
  StreamSubscription<String>? _schedulerSubscription;

  @override
  FutureOr<void> build() async {
    final scheduler = ref.read(fileStateSchedulerProvider.notifier);

    // 订阅经过 FileStateScheduler 防抖和 Suppress 过滤后的纯净事件
    _schedulerSubscription = scheduler.cleanFileEvents.listen((
      changedPath,
    ) async {
      final fileName = p.basename(changedPath);
      final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
      final match = dateFileRegex.firstMatch(fileName);
      if (match == null) return;

      final dateStr = match.group(1)!;
      final date = DateTime.parse(dateStr);

      try {
        final result = await syncJournal(date);
        if (result.isChanged) {
          debugPrint(
            'ShadowIndexSyncService: Sync successful for $dateStr, emitting event.',
          );
          // 把处理结果直接发给上层，避免上层再次触发重复的 syncJournal (Hash 撞车)
          _syncEventController?.add(JournalSyncEvent(changedPath, result));
        } else {
          debugPrint(
            'ShadowIndexSyncService: Sync no-op (No change) for $dateStr',
          );
        }
      } catch (e) {
        debugPrint('ShadowIndexSyncService: Sync error for $dateStr - $e');
      }
    });

    ref.onDispose(() {
      _schedulerSubscription?.cancel();
      _syncEventController?.close();
    });
  }

  /// 对外暴露的同步事件流，用于通知 Repository 和 VaultIndex 刷新内容
  Stream<JournalSyncEvent> get syncEvents {
    _syncEventController ??= StreamController<JournalSyncEvent>.broadcast();
    return _syncEventController!.stream;
  }

  /// 计算文件的 Hash 用以后续对比是否有脏数据
  Future<String> _computeFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 触发单条目标日记的强同步 (通常在 UI 执行 Save 操作后被调用)
  /// 返回同步结果，供增量更新内存索引使用
  Future<JournalSyncResult> syncJournal(DateTime date) async {
    final journalService = ref.read(journalFileServiceProvider.notifier);
    final dbService = ref.read(shadowIndexDatabaseProvider.notifier);

    // 1. 获取物理文件对象
    final file = await journalService
        .getExactFilePath(date)
        .then((p) => File(p));

    final db = await dbService.database;
    final dateStr = date.toIso8601String();

    // 2. 如果文件不存在，检查数据库中是否还有索引（如果是，则说明是外部删除了）
    if (!file.existsSync()) {
      final existingRows = await db.query(
        'journals_index',
        columns: ['id'],
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      if (existingRows.isNotEmpty) {
        // 发现孤儿索引，执行物理清理
        await dbService.deleteJournalIndex(existingRows.first['id'] as int);
        debugPrint(
          'ShadowIndexSyncService: Deleted index for missing file $dateStr',
        );
        return JournalSyncResult(isChanged: true); // 标记变更（删除）
      }
      return JournalSyncResult(isChanged: false);
    }

    // 3. 检查数据库中已有的 Hash，避免无意义的解析和 UI 重绘
    final existingRows = await db.query(
      'journals_index',
      columns: ['content_hash'],
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    final currentHash = await _computeFileHash(file);
    if (existingRows.isNotEmpty) {
      final oldHash = existingRows.first['content_hash'] as String;
      if (oldHash == currentHash) {
        // 数据一致，无需任何操作
        return JournalSyncResult(isChanged: false);
      }
    }

    // 4. 有变动（新增或修改），执行完整解析
    final diary = await journalService.readJournal(date);
    if (diary == null) return JournalSyncResult(isChanged: false);

    final mockHash = currentHash;

    await dbService.upsertJournalIndex(
      id: diary.id,
      filePath: date.toIso8601String(),

      // ==========================================
      // 【疑问解答】：为什么这里是 ISO8601 而不是 UTF8？
      // ==========================================
      // 1. 概念层级不同：UTF8 是“序列化方案”（把字符变字节），而 ISO8601 是“内容格式”（一种标准时间字符串）。
      // 2. 数据库友好：SQLite 虽然不直接支持 DateTime 类型，但 ISO8601 字符串是文本可比、可排序的，
      //    方便我们执行 `ORDER BY createdAt` 这种 SQL 查询。
      // 3. 跨端一致性：ISO8601 是国际标准 (yyyy-MM-ddTHH:mm:ss)，无论在哪个时区解析都能保持一致。
      date: diary.date.toIso8601String(),
      createdAt: diary.createdAt.toIso8601String(),
      updatedAt: diary.updatedAt.toIso8601String(),

      contentHash: mockHash,
      weather: diary.weather,
      mood: diary.mood,
      location: diary.location,
      locationDetail: diary.locationDetail,
      isFavorite: diary.isFavorite,
      hasMedia: diary.mediaPaths.isNotEmpty,
      rawContent: diary.content,
      tags: diary.tags.join(','),
    );

    // 返回最新的元数据，方便上层更新内存状态
    final content = diary.content;
    return JournalSyncResult(
      isChanged: true,
      meta: DiaryMeta(
        id: diary.id,
        date: diary.date,
        preview: content.length > 120 ? content.substring(0, 120) : content,
        tags: diary.tags,
        updatedAt: diary.updatedAt,
      ),
    );
  }

  /// 全量空间扫描
  ///
  /// 这是“影子索引”架构的兜底同步机制：
  /// 当用户更换设备拷入文件、或者数据库意外损坏时，
  /// 该方法会递归物理磁盘，将所有 Markdown 文件重新解析并强行对齐到 SQLite 中。
  Future<void> fullScanVault() async {
    final activeVault = await ref.read(vaultServiceProvider.future);
    if (activeVault == null) return;

    final journalsDir = Directory(p.join(activeVault.path, 'Journals'));
    if (!journalsDir.existsSync()) return;

    // 1. 获取所有待同步的物理文件列表
    // 匹配 yyyy-MM-dd.md 格式
    final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
    final List<File> targetFiles = [];

    await for (final entity in journalsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        if (dateFileRegex.hasMatch(fileName)) {
          targetFiles.add(entity);
        }
      }
    }

    // 2. 串行执行同步，并记录所有扫描到的日期
    final Set<String> scannedDates = {};

    for (final file in targetFiles) {
      try {
        final fileName = p.basename(file.path);
        final dateStr = dateFileRegex.firstMatch(fileName)?.group(1);
        if (dateStr != null) {
          scannedDates.add(dateStr);
          final date = DateTime.parse(dateStr);
          await syncJournal(date);
        }
      } catch (e) {
        continue;
      }
    }

    // 3. 【核心修复】：清理孤立索引 (Orphaned Index)
    // 找出那些数据库里有，但物理磁盘上已经消失的日期条目
    final dbService = ref.read(shadowIndexDatabaseProvider.notifier);
    final db = await dbService.database;
    final rows = await db.query('journals_index', columns: ['id', 'date']);

    for (final row in rows) {
      final id = row['id'] as int;
      final dateStr = (row['date'] as String).split('T').first; // 提取 yyyy-MM-dd

      if (!scannedDates.contains(dateStr)) {
        // 物理文件已不存在，执行影子清理
        await dbService.deleteJournalIndex(id);
        debugPrint(
          'ShadowIndexSyncService: Cleaned orphaned index for date $dateStr (ID: $id)',
        );
      }
    }
  }
}
