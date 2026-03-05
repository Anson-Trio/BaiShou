import 'dart:io';

import 'package:baishou/features/diary/data/vault_index_notifier.dart';
import 'package:baishou/features/index/data/shadow_index_sync_service.dart';
import 'package:baishou/features/settings/domain/services/export_service.dart';
import 'package:baishou/features/settings/domain/services/import_service.dart';
import 'package:baishou/features/storage/domain/services/journal_file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:intl/intl.dart';

part 'data_archive_manager.g.dart';

/// 全局数据归档管理器
/// 统一收口导出、导入、快照操作。协调各底层服务的数据流转与状态同步。
@riverpod
class DataArchiveManager extends _$DataArchiveManager {
  ImportService get _importService => ref.read(importServiceProvider);
  ExportService get _exportService => ref.read(exportServiceProvider);
  JournalFileService get _journalFileService =>
      ref.read(journalFileServiceProvider.notifier);
  VaultIndex get _vaultIndex => ref.read(vaultIndexProvider.notifier);
  ShadowIndexSyncService get _shadowIndexSyncService =>
      ref.read(shadowIndexSyncServiceProvider.notifier);

  @override
  void build() {}

  /// 导出为本地 ZIP 文件（提供给用户选择保存位置）
  Future<File?> exportToUserDevice() async {
    return await _exportService.exportToZip(share: false);
  }

  /// 隐式导出至系统临时目录，用于局域网快传或云同步
  Future<File?> exportToTempFile() async {
    return await _exportService.exportToZip(share: true);
  }

  /// 从 ZIP 导入数据，并彻底重置所有的本地状态与 UI
  Future<ImportResult> importFromZip(
    File zipFile, {
    bool createSnapshotBefore = true,
  }) async {
    try {
      String? snapshotPath;
      if (createSnapshotBefore) {
        final snapshotFile = await createSnapshot();
        snapshotPath = snapshotFile?.path;
      }

      // 1. 先清空 UI 内存，防止脏读并在视觉上快速切断
      _vaultIndex.clear();

      // 2. 清空物理文件
      await _journalFileService.clearAllJournals();

      // 3. 执行核心导入逻辑 (内含 SQLite 日志索引清空及写入)
      final result = await _importService.importFromZip(zipFile);

      // 4. 重建索引、恢复配置并加载到 UI
      if (result.success) {
        if (result.configData != null) {
          await _importService.restoreConfig(result.configData!);
        }
        await _shadowIndexSyncService.fullScanVault();
        await _vaultIndex.forceReload();
      }

      return ImportResult(
        diariesImported: result.diariesImported,
        summariesImported: result.summariesImported,
        profileRestored: result.profileRestored,
        configData: result.configData,
        snapshotPath: snapshotPath ?? result.snapshotPath,
        error: result.error,
      );
    } catch (e) {
      debugPrint('DataArchiveManager Import Error: $e');
      // 即使发生异常也尽力去恢复并重建索引，避免状态进入死锁
      await _shadowIndexSyncService.fullScanVault();
      await _vaultIndex.forceReload();
      rethrow;
    }
  }

  /// 主动生成系统快照，存入应用的私有 snapshots 目录
  Future<File?> createSnapshot() async {
    try {
      final snapshotFile = await exportToTempFile();
      if (snapshotFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final snapshotDir = Directory(p.join(appDir.path, 'snapshots'));
        if (!snapshotDir.existsSync()) {
          await snapshotDir.create(recursive: true);
        }
        final now = DateTime.now();
        final snapshotName =
            'snapshot_${DateFormat('yyyyMMdd_HHmmss').format(now)}.zip';
        final destFile = File(p.join(snapshotDir.path, snapshotName));
        await snapshotFile.copy(destFile.path);

        try {
          await snapshotFile.delete();
        } catch (_) {}

        debugPrint('DataArchiveManager: Snapshot created at ${destFile.path}');
        return destFile;
      }
    } catch (e) {
      debugPrint('DataArchiveManager: Failed to create snapshot: $e');
    }
    return null;
  }

  /// 获取历史快照列表 (可限定返回的最大数量)
  Future<List<File>> listSnapshots({int maxCount = 5}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final snapshotDir = Directory(p.join(appDir.path, 'snapshots'));
    if (!snapshotDir.existsSync()) {
      return [];
    }

    final entities = snapshotDir.listSync().whereType<File>().toList();
    // 按修改时间降序排列 (最新的在前)
    entities.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );

    // 如果超过最大数量，自动清理旧快照
    if (entities.length > maxCount) {
      final toDelete = entities.sublist(maxCount);
      for (final file in toDelete) {
        try {
          await file.delete();
        } catch (_) {}
      }
      return entities.sublist(0, maxCount);
    }

    return entities;
  }
}
