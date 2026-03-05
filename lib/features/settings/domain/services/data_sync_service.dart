import 'dart:io';
import 'package:baishou/core/storage/data_archive_manager.dart';
import 'package:baishou/features/settings/domain/services/import_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 数据同步服务类
/// 核心逻辑复用 DataArchiveManager 和 ImportService，确保与数据导出/导入/局域网传输的格式完全一致。
class DataSyncService {
  final DataArchiveManager _dataArchiveManager;
  final ImportService _importService;

  DataSyncService({
    required DataArchiveManager dataArchiveManager,
    required ImportService importService,
  }) : _dataArchiveManager = dataArchiveManager,
       _importService = importService;

  /// 创建一个包含所有数据的备份 ZIP 文件。
  /// 创建一个包含所有数据的备份 ZIP 文件。
  /// 复用 DataArchiveManager 的逻辑——通过 Repository 读取日记和总结，
  /// 而不是直接操作 SQLite 文件，确保与手动导出、局域网传输的格式一致。
  Future<String> createBackupZip() async {
    // 生成临时文件，不弹系统分享
    final zipFile = await _dataArchiveManager.exportToTempFile();
    if (zipFile == null) {
      throw Exception(t.settings.backup_create_failed);
    }
    return zipFile.path;
  }

  /// 从指定的 ZIP 文件路径还原数据。
  /// 从指定的 ZIP 文件路径还原数据。
  /// 复用 DataArchiveManager 的逻辑——覆盖模式导入，自动创建快照并清除原有物理文件。
  Future<void> restoreFromZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception(t.settings.backup_zip_not_found(path: zipPath));
    }

    final result = await _dataArchiveManager.importFromZip(
      zipFile,
      createSnapshotBefore: true,
    );
    if (!result.success) {
      throw Exception(result.error ?? t.settings.restore_failed_generic);
    }

    // 如果有配置数据，也一并恢复
    if (result.configData != null) {
      await _importService.restoreConfig(result.configData!);
    }
  }
}

/// Riverpod Provider 定义
/// Riverpod Provider 定义
final dataSyncServiceProvider = Provider<DataSyncService>((ref) {
  return DataSyncService(
    dataArchiveManager: ref.watch(dataArchiveManagerProvider.notifier),
    importService: ref.watch(importServiceProvider),
  );
});
