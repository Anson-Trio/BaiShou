import 'dart:async';
import 'dart:io';

import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/storage/domain/services/journal_file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shadow_index_sync_service.g.dart';

/// 影子同步器 (Shadow Index Sync Service)
/// 负责扫描并建立/更新物理文件夹和 SQLite 数据之间的一致性
@Riverpod(keepAlive: true)
class ShadowIndexSyncService extends _$ShadowIndexSyncService {
  StreamController<void>? _syncEventController;
  StreamSubscription<FileSystemEvent>? _watchSubscription;

  @override
  FutureOr<void> build() {
    // 监听 vault 变化重新绑定 watcher
    ref.listen(vaultServiceProvider, (previous, next) {
      if (next.value != null && next.value?.name != previous?.value?.name) {
        startWatchingVault();
      }
    });
  }

  /// 对外暴露的同步事件流，用于通知 Repository 刷新 UI
  Stream<void> get syncEvents {
    _syncEventController ??= StreamController<void>.broadcast();
    return _syncEventController!.stream;
  }

  /// 启动实时文件系统监视器 (类似 Obsidian)
  Future<void> startWatchingVault() async {
    await _watchSubscription?.cancel();
    final activeVault = await ref.read(vaultServiceProvider.future);
    if (activeVault == null) return;

    final journalsDir = Directory(p.join(activeVault.path, 'Journals'));
    if (!journalsDir.existsSync()) return;

    // 监听文件夹变动
    _watchSubscription = journalsDir.watch(recursive: true).listen((
      event,
    ) async {
      final path = event.path;
      if (!path.endsWith('.md')) return;

      final fileName = p.basename(path);
      final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
      final match = dateFileRegex.firstMatch(fileName);
      if (match == null) return;

      final dateStr = match.group(1)!;

      try {
        if (event.type == FileSystemEvent.delete) {
          // 外部删除了文件，查找数据库中对应的日期并删除
          final dbService = ref.read(shadowIndexDatabaseProvider.notifier);
          final db = await dbService.database;
          final rows = await db.query(
            'journals_index',
            columns: ['id'],
            where: 'date LIKE ?',
            whereArgs: ['$dateStr%'],
          );
          for (var row in rows) {
            await dbService.deleteJournalIndex(row['id'] as int);
            debugPrint(
              'ShadowIndexSyncService: Watcher detected delete, cleaned index for $dateStr',
            );
          }
        } else if (event.type == FileSystemEvent.modify ||
            event.type == FileSystemEvent.create) {
          // 外部修改或新建了文件，重新解析并同步
          final date = DateTime.parse(dateStr);
          await syncJournal(date);
          debugPrint(
            'ShadowIndexSyncService: Watcher detected update, synced index for $dateStr',
          );
        }

        // 触发 UI 刷新流
        _syncEventController?.add(null);
      } catch (e) {
        debugPrint('ShadowIndexSyncService: Watch error - $e');
      }
    });

    debugPrint(
      'ShadowIndexSyncService: Started watching directory: ${journalsDir.path}',
    );
  }

  /// 计算文件的 Hash 用以后续对比是否有脏数据
  Future<String> _computeFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 触发单条目标日记的强同步 (通常在 UI 执行 Save 操作后被调用)
  Future<void> syncJournal(DateTime date) async {
    final journalService = ref.read(journalFileServiceProvider.notifier);
    final dbService = ref.read(shadowIndexDatabaseProvider.notifier);

    final diary = await journalService.readJournal(date);
    if (diary == null) {
      // 如果文件不存在，可能是删除了
      return;
    }

    // 重新获取一下那个真实的文件句柄，由于写锁在这个上下文无法暴露，此处假设 readJournal 反推出其安全路径
    final mockHash = md5.convert(diary.content.codeUnits).toString();

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
