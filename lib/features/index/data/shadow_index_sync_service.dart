import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:baishou/features/diary/domain/entities/diary_meta.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:yaml/yaml.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/storage/domain/services/journal_file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/agent/rag/embedding_service.dart';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:baishou/features/storage/domain/services/file_state_scheduler.dart';
import 'package:baishou/features/diary/data/vault_index_notifier.dart';
import 'package:baishou/core/router/app_router.dart';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/i18n/strings.g.dart';

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

/// 全局 RAG 队列任务实体
class _RagTask {
  final Diary diary;
  final DateTime queuedAt;
  _RagTask(this.diary) : queuedAt = DateTime.now();
}


/// 影子同步器 (Shadow Index Sync Service)
/// 负责将外部清洗过的路径变动，同步到 SQLite 数据库中，并通知给 VaultIndex
@Riverpod(keepAlive: true)
class ShadowIndexSyncService extends _$ShadowIndexSyncService {
  StreamController<JournalSyncEvent>? _syncEventController;
  StreamSubscription<String>? _schedulerSubscription;
  StreamSubscription<void>? _dirDeleteSubscription;

  bool _isScanning = false;
  bool _isSyncDisabled = false;

  /// 用于追踪当前正在进行的扫描任务，供外部等待
  Completer<void>? _currentScanCompleter;

  // 异步 RAG 嵌入队列管理
  final List<_RagTask> _ragQueue = [];
  bool _isProcessingRag = false;
  int _consecutiveFailures = 0;

  /// 等待当前正在进行的全量扫描完成
  Future<void> waitForScan() async {
    if (_currentScanCompleter != null && !_currentScanCompleter!.isCompleted) {
      debugPrint(
        'ShadowIndexSyncService: Waiting for ongoing scan to complete...',
      );
      await _currentScanCompleter!.future;
      debugPrint('ShadowIndexSyncService: Ongoing scan completed.');
    }
  }

  /// 外部手动开启或关闭自动同步功能 (例如导入期间暂停同步)
  void setSyncEnabled(bool enabled) {
    _isSyncDisabled = !enabled;
    debugPrint('ShadowIndexSyncService: Sync enabled set to $enabled');
  }

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

    // 订阅目录删除信号：整个月份文件夹被删除时，执行全量扫描清理孤立索引
    _dirDeleteSubscription = scheduler.dirDeleteEvents.listen((_) async {
      if (_isSyncDisabled) return; // 关键修复：导入恢复期间忽略目录拓扑事件，防止海量无用的 DB reload
      debugPrint(
        'ShadowIndexSyncService: Dir delete detected, triggering fullScanVault.',
      );
      // skipRag: true — 目录拓扑变更时的全扫仅用于清理孤立索引/补录新文件元数据，
      // 不重新触发 Embedding，避免在删除/移动文件夹时引发 RAG 请求风暴。
      await fullScanVault(skipRag: true);
      // 扫描完成后，强制刷新 VaultIndex 内存让 UI 同步
      final vaultIndex = ref.read(vaultIndexProvider.notifier);
      await vaultIndex.forceReload();
    });

    ref.onDispose(() {
      _schedulerSubscription?.cancel();
      _dirDeleteSubscription?.cancel();
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
  Future<JournalSyncResult> syncJournal(
    DateTime date, {
    bool skipRag = false,
    File? actualFile,
  }) async {
    if (_isSyncDisabled) {
      debugPrint(
        'ShadowIndexSyncService: Skipped syncJournal because sync is disabled.',
      );
      return JournalSyncResult(isChanged: false);
    }

    final journalService = ref.read(journalFileServiceProvider.notifier);
    final dbService = ref.read(shadowIndexDatabaseProvider.notifier);

    // 1. 获取物理文件对象
    final File file;
    if (actualFile != null) {
      file = actualFile;
    } else {
      final p = await journalService.getExactFilePath(date);
      file = File(p);
    }

    final db = dbService.database;
    final dateStr = date.toIso8601String();

    // 2. 如果文件不存在，检查数据库中是否还有索引（如果是，则说明是外部删除了）
    if (!file.existsSync()) {
      final dayStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final existingRows = db.select(
        'SELECT id FROM journals_index WHERE date LIKE ?',
        ['$dayStr%'],
      );
      if (existingRows.isNotEmpty) {
        // 发现孤儿索引，执行物理清理。
        // 这里循环删除该日期下的所有索引（理论上按天切分只有一条，但为了鲁棒性全删）
        for (final row in existingRows) {
          final idToRemove = row['id'] as int;
          await dbService.deleteJournalIndex(idToRemove);

          try {
            // 同步清理 RAG 记忆中这篇日记留下的碎片
            final agentDb = ref.read(agentDatabaseProvider);
            await agentDb.deleteEmbeddingsBySource(
              'diary',
              idToRemove.toString(),
            );
          } catch (e) {
            debugPrint('ShadowIndexSyncService: Failed removing vectors: $e');
          }

          debugPrint(
            'ShadowIndexSyncService: Deleted index ID $idToRemove for missing file $dayStr',
          );
        }
        return JournalSyncResult(isChanged: true); // 标记变更（删除）
      }
      return JournalSyncResult(isChanged: false);
    }

    // 3. 检查数据库中已有的 Hash，避免无意义的解析和 UI 重绘
    final existingRows = db.select(
      'SELECT content_hash FROM journals_index WHERE date = ?',
      [dateStr],
    );

    final currentHash = await _computeFileHash(file);
    if (existingRows.isNotEmpty) {
      final oldHash = existingRows.first['content_hash'] as String;
      if (oldHash == currentHash) {
        return JournalSyncResult(isChanged: false);
      }
    }

    debugPrint(
      'ShadowIndexSyncService: Hash mismatch or new, performing full parse and upsert for ${date.toIso8601String()}',
    );

    // 4. 有变动（新增或修改），执行完整解析
    // 注意：这里需要通过实际的文件路径去读取（journalService.readJournal 原本也是用 getExactFilePath）
    // 因此我们需要扩展或者手动复用 readJournal 的逻辑。如果使用 actualFile，确保传入其内容。
    Diary? diary;
    if (actualFile != null) {
      // 这里的 file 就是 actualFile，且已经通过上面转为非空
      final content = await file.readAsString();
      // 这里可以复用从内容中解析的逻辑，因为 readJournal 主要是针对确定的 date 和 content 日期处理
      // 我们可以临时借助 journalService.readJournal (由于 readJournal 用的是 getExactFilePath)
      // 为保证一致，如果它是非标准路径，可以直接构造（降级处理）或者复用 parse 逻辑。我们这里不改变原先架构：
      // 由于 _resolveDateTargetFile 可能读取不到非标准路径的内容，最好是在本服务内或扩展 journalService
      // 为了安全，如果文件路径不同，这里使用临时拦截解析
      diary = await _parseDiaryFromFile(file, date);
    } else {
      diary = await journalService.readJournal(date);
    }

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

    debugPrint('ShadowIndexSyncService: Upsert complete for ID ${diary.id}');

    // 5. 异步触发 RAG 向量嵌入（统一入口，无论是 UI、Agent 还是外部修改）
    if (!skipRag) {
      _triggerEmbeddingAsync(diary);
    }

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

  /// 异步触发日记内容的 RAG 向量嵌入（加入队列串行处理防爆破）
  ///
  /// 这是整个系统中日记 Embedding 的**唯一触发源**。
  /// 无论日记是通过 UI 编辑器、Agent diary_edit 工具、局域网同步、
  /// 还是用户用外部编辑器手动修改 .md 文件，都会经过此方法。
  void _triggerEmbeddingAsync(dynamic diary) {
    _ragQueue.add(_RagTask(diary as Diary));
    _processRagQueue();
  }

  Future<void> _processRagQueue() async {
    if (_isProcessingRag) return;
    _isProcessingRag = true;

    try {
      final apiConfig = ref.read(apiConfigServiceProvider);
      final embeddingService = ref.read(embeddingServiceProvider);
      
      while (_ragQueue.isNotEmpty) {
        if (!apiConfig.ragEnabled || !embeddingService.isConfigured) {
          _ragQueue.clear();
          break;
        }

        final task = _ragQueue.removeAt(0);
        final diary = task.diary;

        final dateLabel =
            '${diary.date.year}-${diary.date.month.toString().padLeft(2, '0')}-${diary.date.day.toString().padLeft(2, '0')}';
        final tagList = (diary.tags as List?)?.cast<String>() ?? [];
        final tagPrefix = tagList.isNotEmpty
            ? '[标签: ${tagList.join(', ')}] '
            : '';
            
        try {
          await embeddingService.reEmbedText(
            text: diary.content,
            sourceType: 'diary',
            sourceId: diary.id.toString(),
            groupId: 'diary_auto',
            sourceCreatedAt: diary.date.millisecondsSinceEpoch,
            chunkPrefix: '$tagPrefix[$dateLabel 日记] ',
            metadataJson:
                '{"updated_at":${diary.updatedAt.millisecondsSinceEpoch}}',
          );
          _consecutiveFailures = 0;
          debugPrint('ShadowIndexSyncService: RAG embedded for $dateLabel');
        } catch (e) {
          _consecutiveFailures++;
          debugPrint('ShadowIndexSyncService: RAG embedding failed: $e');

          if (_consecutiveFailures >= 1) {
            await apiConfig.setRagEnabled(false);
            _ragQueue.clear();
            
            try {
              final context = ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;
              if (context != null && context.mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    final colorScheme = Theme.of(ctx).colorScheme;
                    return AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Text(t.agent.rag.circuit_breaker_title, style: TextStyle(color: colorScheme.error)),
                        ],
                      ),
                      content: Text(t.agent.rag.circuit_breaker_content),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(t.common.ok),
                        ),
                      ],
                    );
                  },
                );
              }
            } catch (_) {}
            
            break;
          }
        }

        // 处理完每一条主动休眠延迟，避免批量拉入时打爆大模型并发限制（特别是 Gemini 有严苛的单分钟额度）
        if (_ragQueue.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    } finally {
      _isProcessingRag = false;
    }
  }

  /// 全量空间扫描
  ///
  /// 这是“影子索引”架构的兜底同步机制：
  /// 当用户更换设备拷入文件、或者数据库意外损坏时，
  /// 该方法会递归物理磁盘，将所有 Markdown 文件重新解析并强行对齐到 SQLite 中。
  /// [skipRag] 是否跳过触发 RAG 同步（大批量数据还原时必带以防止请求风暴）
  Future<void> fullScanVault({bool skipRag = false}) async {
    if (_isSyncDisabled) {
      debugPrint(
        'ShadowIndexSyncService: Skipped fullScanVault because sync is disabled.',
      );
      return;
    }

    if (_isScanning) {
      debugPrint(
        'ShadowIndexSyncService: Skipped fullScanVault because another scan is already in progress.',
      );
      return;
    }

    _isScanning = true;
    _currentScanCompleter = Completer<void>();

    try {
      final activeVault = await ref.read(vaultServiceProvider.future);
      if (activeVault == null) return;

      final journalsDir = Directory(p.join(activeVault.path, 'Journals'));

      // 1. 获取所有待同步的物理文件列表
      // 匹配 yyyy-MM-dd.md 格式
      final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
      final List<File> targetFiles = [];

      // 关键修复：如果目录不存在，不直接 return，而是跳过遍历，让空列表进入后续清理逻辑
      if (journalsDir.existsSync()) {
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
      }

      // 2. 预读取 DB 所有现存内容 Hash，实现内存瞬间比对
      final dbService = ref.read(shadowIndexDatabaseProvider.notifier);
      final journalService = ref.read(journalFileServiceProvider.notifier);
      final db = dbService.database;

      final existingHashes = <String, String>{};
      final existingRows = db.select('SELECT date, content_hash FROM journals_index');
      for (final row in existingRows) {
        final dateIso = (row['date'] as String).split('T').first;
        final hash = row['content_hash'] as String;
        existingHashes[dateIso] = hash;
      }

      // 3. 高并发并行处理：每次并发处理 32 个文件，将单线程阻塞时间大大缩短
      final List<_UpsertTask> diariesToUpsert = [];
      final List<Diary> syncedDiaries = [];
      const int chunkSize = 32;

      for (int i = 0; i < targetFiles.length; i += chunkSize) {
        final chunk = targetFiles.sublist(
            i, i + chunkSize > targetFiles.length ? targetFiles.length : i + chunkSize);

        await Future.wait(chunk.map((file) async {
          try {
            final fileName = p.basename(file.path);
            final dateStr = dateFileRegex.firstMatch(fileName)?.group(1);
            if (dateStr == null) return;
            final date = DateTime.parse(dateStr);

            // 物理收纳逻辑
            final expectedPath = await journalService.getExpectedFilePath(date);
            File finalFile = file;

            if (p.normalize(file.absolute.path) != p.normalize(File(expectedPath).absolute.path)) {
              final expectedDir = Directory(p.dirname(expectedPath));
              try {
                if (!expectedDir.existsSync()) await expectedDir.create(recursive: true);
              } catch (_) {}
              if (!File(expectedPath).existsSync()) {
                try {
                  finalFile = await file.rename(expectedPath);
                } catch (_) {
                  finalFile = await file.copy(expectedPath);
                  try { await file.delete(); } catch (_) {}
                }
              }
            }

            if (!finalFile.existsSync()) return;

            final content = await finalFile.readAsString();
            final bytes = utf8.encode(content);
            final currentHash = md5.convert(bytes).toString();

            // Hash 拦截：如果已有并未变更，跳过
            if (existingHashes[dateStr] == currentHash) return;

            // 内容变更了，快速解析
            final diary = await _parseDiaryFromContent(content, date);
            
            // 加入批量写队列（在 Dart 单线程内同步操作是线程安全的）
            diariesToUpsert.add(_UpsertTask(diary, currentHash, expectedPath));
            
            if (!skipRag) {
               syncedDiaries.add(diary);
            }
          } catch (e) {
            debugPrint('ShadowIndexSyncService: Failed to process chunk file $file: $e');
          }
        }));
      }

      // 4. 重火力入库：开启大事务一次性批量存储，将数万条 I/O 压缩为一秒。
      if (diariesToUpsert.isNotEmpty) {
        try {
          db.execute('BEGIN TRANSACTION;');
          for (final task in diariesToUpsert) {
            await dbService.upsertJournalIndex(
              id: task.diary.id ?? task.diary.date.millisecondsSinceEpoch,
              filePath: task.diary.date.toIso8601String(), // 历史遗留规范代理
              date: task.diary.date.toIso8601String(),
              createdAt: task.diary.createdAt.toIso8601String(),
              updatedAt: task.diary.updatedAt.toIso8601String(),
              contentHash: task.hash,
              rawContent: task.diary.content,
              tags: task.diary.tags.join(','),
              weather: task.diary.weather,
              mood: task.diary.mood,
              location: task.diary.location,
              locationDetail: task.diary.locationDetail,
              isFavorite: task.diary.isFavorite,
              hasMedia: task.diary.mediaPaths.isNotEmpty,
            );
          }
          db.execute('COMMIT;');
        } catch (e) {
          try { db.execute('ROLLBACK;'); } catch (_) {}
          debugPrint('ShadowIndexSyncService: Mass upsert transaction failed: $e');
        }
      }

      // 5. 【关键修复】：清理孤立索引 (Orphaned Index)
      final rows = db.select('SELECT id, date FROM journals_index');
      final List<_OrphanEntry> orphans = [];

      for (final row in rows) {
        final id = row['id'] as int;
        final logicalDate = DateTime.parse(row['date'] as String);
        final filePath = await journalService.getExpectedFilePath(logicalDate);
        if (!File(filePath).existsSync()) {
          orphans.add(_OrphanEntry(id, (row['date'] as String).split('T').first));
        }
      }

      if (orphans.isNotEmpty) {
        try {
          db.execute('BEGIN TRANSACTION;');
          for (final orphan in orphans) {
            await dbService.deleteJournalIndex(orphan.id);
            debugPrint(
              'ShadowIndexSyncService: Cleaned orphaned index for date ${orphan.dateStr} (ID: ${orphan.id})',
            );
          }
          db.execute('COMMIT;');
        } catch (e) {
          try { db.execute('ROLLBACK;'); } catch (_) {}
          debugPrint('ShadowIndexSyncService: Orphan cleanup transaction failed: $e');
        }

        // 事务外再清理 RAG 向量（agentDatabase 是独立库，不在同一事务内）
        for (final orphan in orphans) {
          try {
            final agentDb = ref.read(agentDatabaseProvider);
            await agentDb.deleteEmbeddingsBySource('diary', orphan.id.toString());
          } catch (_) {}
        }
      }

      // 6. 全量扫描完毕后统一批量触发 RAG 嵌入
      // 串行入队，由 _processRagQueue 内部控制 1500ms 间隔，不会打爆大模型限额。
      if (!skipRag && syncedDiaries.isNotEmpty) {
        debugPrint(
          'ShadowIndexSyncService: Batch triggering RAG for ${syncedDiaries.length} changed diaries after full scan.',
        );
        for (final diary in syncedDiaries) {
          _triggerEmbeddingAsync(diary);
        }
      }
    } finally {
      _isScanning = false;
      if (_currentScanCompleter != null &&
          !_currentScanCompleter!.isCompleted) {
        _currentScanCompleter!.complete();
      }

      // 确保启动扫描或挂载完成时，UI 内存能同步刷新显示新收纳的海量文件
      try {
        final vaultIndex = ref.read(vaultIndexProvider.notifier);
        await vaultIndex.forceReload();
      } catch (_) {}
    }
  }

  /// 快速从字符串直接解析为 Diary 实体（省去二次文件读取）
  Future<Diary> _parseDiaryFromContent(String content, DateTime date) async {
    final regex = RegExp(r'^---\r?\n(.*?)\r?\n---\r?\n(.*)$', dotAll: true);
    final match = regex.firstMatch(content);

    if (match == null) {
      return Diary(
        id: date.millisecondsSinceEpoch,
        date: date,
        createdAt: date,
        updatedAt: date,
        content: content,
      );
    }

    final yamlStr = match.group(1) ?? '';
    final bodyStr = match.group(2) ?? '';
    try {
      final doc = loadYaml(yamlStr);
      final meta = Map<String, dynamic>.from(doc as Map);
      return Diary(
        id: meta['id'] as int? ?? date.millisecondsSinceEpoch,
        createdAt:
            DateTime.tryParse(meta['createdAt'] as String? ?? '') ?? date,
        updatedAt:
            DateTime.tryParse(meta['updatedAt'] as String? ?? '') ?? date,
        content: bodyStr.trim(),
        weather: meta['weather'] as String?,
        mood: meta['mood'] as String?,
        location: meta['location'] as String?,
        locationDetail: meta['locationDetail'] as String?,
        isFavorite: meta['isFavorite'] as bool? ?? false,
        tags: meta['tags'] != null
            ? List<String>.from(meta['tags'] as Iterable)
            : const [],
        mediaPaths: meta['mediaPaths'] != null
            ? List<String>.from(meta['mediaPaths'] as Iterable)
            : const [],
        date: date,
      );
    } catch (_) {
      return Diary(
        id: date.millisecondsSinceEpoch,
        date: date,
        createdAt: date,
        updatedAt: date,
        content: content,
      );
    }
  }

  /// 内部解析任意物理路径的文件为 Diary 实体，复用上述逻辑
  Future<Diary?> _parseDiaryFromFile(File file, DateTime date) async {
    if (!file.existsSync()) return null;
    final content = await file.readAsString();
    return _parseDiaryFromContent(content, date);
  }

}

/// 孤立索引条目，用于两阶段清理（事务删 DB + 独立删 RAG 向量）
class _OrphanEntry {
  final int id;
  final String dateStr;
  _OrphanEntry(this.id, this.dateStr);
}

/// 批量 Upsert 任务实体
class _UpsertTask {
  final Diary diary;
  final String hash;
  final String expectedPath;
  _UpsertTask(this.diary, this.hash, this.expectedPath);
}
