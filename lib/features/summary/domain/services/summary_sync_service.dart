import 'dart:async';
import 'dart:io';

import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/storage/domain/services/summary_file_service.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:baishou/core/database/app_database.dart' as db;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' hide Summary;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:baishou/features/storage/domain/services/file_state_scheduler.dart';

import 'package:baishou/core/providers/shared_preferences_provider.dart';

part 'summary_sync_service.g.dart';

/// 总结同步服务 (Summary Sync Service)
/// 负责仅将物理 Archives 目录的文件同步至 SQLite 索引 (单向: 文件 -> DB)
@Riverpod(keepAlive: true)
class SummarySyncService extends _$SummarySyncService {
  bool _isMigrating = false;
  bool _isScanning = false;
  bool _isSyncDisabled = false;

  /// 用于追踪当前正在进行的扫描任务，供外部等待
  Completer<void>? _currentScanCompleter;

  /// 等待当前正在进行的全量扫描完成
  Future<void> waitForScan() async {
    if (_currentScanCompleter != null && !_currentScanCompleter!.isCompleted) {
      debugPrint('SummarySyncService: Waiting for ongoing scan to complete...');
      await _currentScanCompleter!.future;
      debugPrint('SummarySyncService: Ongoing scan completed.');
    }
  }

  /// 外部手动开启或关闭自动同步功能 (例如导入期间暂停同步)
  void setSyncEnabled(bool enabled) {
    _isSyncDisabled = !enabled;
    debugPrint('SummarySyncService: Sync enabled set to $enabled');
  }

  @override
  FutureOr<void> build() async {
    // 1. 监听 Vault 变化，重连时全量扫描（兜底）
    ref.listen(vaultServiceProvider, (previous, next) {
      if (next.hasValue &&
          (next.value?.name != previous?.value?.name ||
              next.value?.path != previous?.value?.path)) {
        final vault = next.value;
        if (vault != null) {
          _handleVaultChanged(vault);
        }
      }
    });

    // 4. 初次启动检查：如果 Vault 已经就绪，立即执行检查
    final currentVault = ref.read(vaultServiceProvider).value;
    if (currentVault != null) {
      _handleVaultChanged(currentVault);
    }
  }

  /// 处理 Vault 变化：判断迁移或扫描
  void _handleVaultChanged(VaultInfo vault) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool('is_legacy_sql_summary_migrated') != true) {
      if (_isMigrating) return;
      _isMigrating = true;
      _migrateLegacySqlSummaries().then((_) {
        prefs.setBool('is_legacy_sql_summary_migrated', true);
        _isMigrating = false;
        // 迁移完成后执行常态的文件到 DB 的拉平扫描
        fullScanArchives();
      });
    } else {
      fullScanArchives();
    }

    // 2. 订阅物理文件变动流
    final scheduler = ref.read(fileStateSchedulerProvider.notifier);
    scheduler.cleanFileEvents.listen((changedPath) {
      if (changedPath.contains('/Archives/')) {
        debugPrint(
          'SummarySyncService: Archive file changed at $changedPath, triggering sync.',
        );
        // 简单处理：任何归档变动都触发全量扫描
        fullScanArchives();
      }
    });

    // 3. 订阅目录删除事件
    scheduler.dirDeleteEvents.listen((_) {
      debugPrint(
        'SummarySyncService: Directory topology change, triggering full scan.',
      );
      fullScanArchives();
    });
  }

  /// 全量扫描归档目录并对齐索引
  Future<void> fullScanArchives() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final isMigrated = prefs.getBool('is_legacy_sql_summary_migrated') == true;

    if (_isMigrating || !isMigrated || _isSyncDisabled) {
      debugPrint(
        'SummarySyncService: Skipped full scan because migration/scan is in progress, not yet migrated, or sync is disabled.',
      );
      return;
    }

    if (_isScanning) {
      debugPrint(
        'SummarySyncService: Skipped full scan because another scan is already in progress.',
      );
      return;
    }

    _isScanning = true;
    _currentScanCompleter = Completer<void>();

    try {
      final activeVault = await ref.read(vaultServiceProvider.future);
      if (activeVault == null) return;

      final fileService = ref.read(summaryFileServiceProvider.notifier);
      final appDb = ref.read(db.appDatabaseProvider);

      debugPrint(
        'SummarySyncService: Starting File->DB sync for vault: ${activeVault.name}',
      );

      // 1. 获取所有物理总结文件
      final List<File> files = [];
      final archivesDir = Directory(p.join(activeVault.path, 'Archives'));

      if (archivesDir.existsSync()) {
        final entities = archivesDir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.md')) {
            files.add(entity);
          }
        }
      }

      // 2. 解析文件并准备数据 (带去重逻辑，防止物理路径重复导致 DB 冲突)
      final Map<String, Summary> deDuplicated = {};
      for (final file in files) {
        try {
          // 路径格式：Archives/{Type}/{yyyy-MM-dd}.md
          final parts = p.split(file.path);
          final typeStr = parts[parts.length - 2].toLowerCase();
          final dateStr = p.basenameWithoutExtension(file.path);

          final type = SummaryType.values.firstWhere(
            (t) => t.name == typeStr,
            orElse: () => SummaryType.weekly,
          );
          final startDate = DateTime.parse(dateStr);

          final summary = await fileService.readSummary(type, startDate);
          if (summary != null) {
            // 以 type + date 为联合 Key 唯一标识
            final key = '${type.name}_$dateStr';
            deDuplicated[key] = summary;
          }
        } catch (e) {
          debugPrint('SummarySyncService: Skip invalid file ${file.path}: $e');
        }
      }

      final List<Summary> summaries = deDuplicated.values.toList();

      // 3. 覆盖数据库记录 (单向写入 DB，绝不反向写回文件)
      await appDb.delete(appDb.summaries).go();

      if (summaries.isNotEmpty) {
        await appDb.batch((batch) {
          for (final summary in summaries) {
            batch.insert(
              appDb.summaries,
              db.SummariesCompanion(
                type: drift.Value(summary.type),
                startDate: drift.Value(summary.startDate),
                endDate: drift.Value(summary.endDate),
                content: drift.Value(summary.content),
                sourceIds: drift.Value(summary.sourceIds.join(',')),
                generatedAt: drift.Value(summary.generatedAt),
              ),
            );
          }
        });
      }

      debugPrint(
        'SummarySyncService: Sync complete. Updated DB with ${summaries.length} summaries from disk.',
      );
    } catch (e) {
      debugPrint('SummarySyncService: File->DB sync failed: $e');
    } finally {
      _isScanning = false;
      if (_currentScanCompleter != null &&
          !_currentScanCompleter!.isCompleted) {
        _currentScanCompleter!.complete();
      }
    }
  }

  /// 老用户(V2.1.0以前)：一次性数据库到物理文件的导出 (纯 DB 向物理化升级)
  Future<void> _migrateLegacySqlSummaries() async {
    try {
      final appDb = ref.read(db.appDatabaseProvider);
      final fileService = ref.read(summaryFileServiceProvider.notifier);

      debugPrint(
        'SummarySyncService: Starting Legacy SQL Migration (DB -> Disk)...',
      );

      // 获取所有老版本的遗留数据库总结记录
      final rows = await appDb.select(appDb.summaries).get();
      if (rows.isEmpty) {
        debugPrint(
          'SummarySyncService: No legacy SQL summaries found to migrate.',
        );
        return;
      }

      for (final row in rows) {
        final summary = Summary(
          id: row.id,
          type: row.type,
          startDate: row.startDate,
          endDate: row.endDate,
          content: row.content,
          generatedAt: row.generatedAt,
          sourceIds:
              row.sourceIds
                  ?.split(',')
                  .where((s) => s.trim().isNotEmpty)
                  .toList() ??
              [],
        );

        // 屏蔽物理文件的事件回声，防止触发 Watcher 导致未预期的并发全刷
        final filePath = await fileService.getSummaryFilePath(
          summary.type,
          summary.startDate,
        );
        ref.read(fileStateSchedulerProvider.notifier).suppressPath(filePath);

        // 将旧数据当作物理文件写入当前活跃区域
        await fileService.writeSummary(summary);
      }

      debugPrint(
        'SummarySyncService: Successfully migrated ${rows.length} legacy SQL summaries to disk.',
      );
    } catch (e) {
      debugPrint('SummarySyncService: Legacy SQL Migration failed: $e');
    }
  }
}
