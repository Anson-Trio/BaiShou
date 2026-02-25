import 'dart:io';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:baishou/features/settings/domain/services/data_sync_config_service.dart';
import 'package:baishou/features/settings/domain/services/data_sync_service.dart';
import 'package:baishou/features/settings/domain/services/s3_client_service.dart';
import 'package:baishou/features/settings/domain/services/webdav_client_service.dart';
import 'package:baishou/features/settings/presentation/pages/data_sync_config_page.dart';
import 'package:baishou/features/settings/presentation/widgets/sync_stat_card.dart';
import 'package:baishou/features/settings/presentation/widgets/sync_record_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/i18n/strings.g.dart';

class DataSyncPage extends ConsumerStatefulWidget {
  const DataSyncPage({super.key});

  @override
  ConsumerState<DataSyncPage> createState() => _DataSyncPageState();
}

class _DataSyncPageState extends ConsumerState<DataSyncPage> {
  bool _isSyncing = false;
  bool _isLoadingRecords = false;
  List<dynamic> _records = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRecords();
    });
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoadingRecords = true;
    });

    final config = ref.read(dataSyncConfigServiceProvider);
    try {
      if (config.syncTarget == SyncTarget.s3) {
        final client = S3ClientService(
          endpoint: config.s3Endpoint,
          region: config.s3Region,
          bucket: config.s3Bucket,
          accessKey: config.s3AccessKey,
          secretKey: config.s3SecretKey,
          basePath: config.s3Path,
        );
        _records = await client.listFiles();
      } else if (config.syncTarget == SyncTarget.webdav) {
        final client = WebDavClientService(
          url: config.webdavUrl,
          username: config.webdavUsername,
          password: config.webdavPassword,
          basePath: config.webdavPath,
        );
        _records = await client.listFiles();
      } else {
        _records = [];
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          t.data_sync.fetch_records_failed(e: e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecords = false;
        });
      }
    }
  }

  Future<void> _syncNow() async {
    final config = ref.read(dataSyncConfigServiceProvider);

    if (config.syncTarget == SyncTarget.local) {
      AppToast.showSuccess(context, t.data_sync.local_backup_hint);
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final syncService = ref.read(dataSyncServiceProvider);
      final zipPath = await syncService.createBackupZip();
      final zipFile = File(zipPath);

      if (config.syncTarget == SyncTarget.s3) {
        final client = S3ClientService(
          endpoint: config.s3Endpoint,
          region: config.s3Region,
          bucket: config.s3Bucket,
          accessKey: config.s3AccessKey,
          secretKey: config.s3SecretKey,
          basePath: config.s3Path,
        );
        await client.uploadFile(zipFile);
      } else if (config.syncTarget == SyncTarget.webdav) {
        final client = WebDavClientService(
          url: config.webdavUrl,
          username: config.webdavUsername,
          password: config.webdavPassword,
          basePath: config.webdavPath,
        );
        await client.uploadFile(zipFile);
      }

      await zipFile.delete();

      if (mounted) {
        AppToast.showSuccess(context, t.data_sync.sync_success);
      }
      await _fetchRecords();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, t.data_sync.sync_failed(e: e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(dataSyncConfigServiceProvider);
    final textTheme = Theme.of(context).textTheme;

    double totalSizeMb = 0;
    for (final record in _records) {
      if (record.sizeInBytes != null) {
        totalSizeMb += record.sizeInBytes / (1024 * 1024);
      }
    }
    final sizeString = totalSizeMb > 0
        ? '${totalSizeMb.toStringAsFixed(2)} MB'
        : '0 MB';

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final isPageMobile = outerConstraints.maxWidth < 500;
        return Container(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isPageMobile ? 16 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 500;
                    final cards = [
                      SyncStatCard(
                        title: t.data_sync.sync_target,
                        value: config.syncTarget.name.toUpperCase(),
                        icon: config.syncTarget == SyncTarget.s3
                            ? Icons.cloud_done_outlined
                            : (config.syncTarget == SyncTarget.webdav
                                  ? Icons.public
                                  : Icons.folder),
                        color: Colors.blue.shade600,
                      ),
                      SyncStatCard(
                        title: t.data_sync.total_backup_size,
                        value: sizeString,
                        icon: Icons.storage_outlined,
                        color: Colors.green.shade600,
                      ),
                      SyncStatCard(
                        title: t.data_sync.backup_count,
                        value: t.data_sync.backup_count_unit(
                          count: _records.length,
                        ),
                        icon: Icons.sync_alt_outlined,
                        color: Colors.purple.shade600,
                      ),
                    ];

                    if (isMobile) {
                      return Column(
                        children: cards
                            .map(
                              (card) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: card,
                              ),
                            )
                            .toList(),
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[2]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.data_sync.sync_records,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                config.syncTarget.name.toUpperCase(),
                                style: textTheme.labelSmall?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.data_sync.records_scope_hint,
                          style: textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DataSyncConfigPage(),
                              ),
                            ).then((_) => _fetchRecords());
                          },
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: Text(t.data_sync.sync_settings_button),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isSyncing ? null : _syncNow,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(
                            _isSyncing
                                ? t.data_sync.syncing_status
                                : t.data_sync.sync_now_button,
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isLoadingRecords)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_records.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(t.data_sync.no_records_hint),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _records.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return SyncRecordItem(
                        record: record,
                        onRestore: () => _restoreRecord(record),
                        onRename: () => _renameRecord(record),
                        onDelete: () => _deleteRecord(record),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteRecord(dynamic record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.data_sync.delete_backup_title),
        content: Text(t.data_sync.delete_backup_confirm(name: record.filename)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final config = ref.read(dataSyncConfigServiceProvider);
    try {
      if (config.syncTarget == SyncTarget.s3) {
        final client = S3ClientService(
          endpoint: config.s3Endpoint,
          region: config.s3Region,
          bucket: config.s3Bucket,
          accessKey: config.s3AccessKey,
          secretKey: config.s3SecretKey,
          basePath: config.s3Path,
        );
        await client.deleteObject(record.filename);
      } else if (config.syncTarget == SyncTarget.webdav) {
        final client = WebDavClientService(
          url: config.webdavUrl,
          username: config.webdavUsername,
          password: config.webdavPassword,
          basePath: config.webdavPath,
        );
        await client.delete(record.filename);
      }
      AppToast.showSuccess(context, '删除成功');
      _fetchRecords();
    } catch (e) {
      AppToast.showError(context, '删除失败: $e');
    }
  }

  Future<void> _renameRecord(dynamic record) async {
    final nameController = TextEditingController(text: record.filename);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.data_sync.rename_title),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: t.data_sync.new_filename_label,
            hintText: t.data_sync.backup_filename_hint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == record.filename) {
      return;
    }

    final config = ref.read(dataSyncConfigServiceProvider);
    try {
      if (config.syncTarget == SyncTarget.s3) {
        final client = S3ClientService(
          endpoint: config.s3Endpoint,
          region: config.s3Region,
          bucket: config.s3Bucket,
          accessKey: config.s3AccessKey,
          secretKey: config.s3SecretKey,
          basePath: config.s3Path,
        );
        await client.renameObject(record.filename, newName);
      } else if (config.syncTarget == SyncTarget.webdav) {
        final client = WebDavClientService(
          url: config.webdavUrl,
          username: config.webdavUsername,
          password: config.webdavPassword,
          basePath: config.webdavPath,
        );
        await client.rename(record.filename, newName);
      }
      AppToast.showSuccess(context, '重命名成功');
      _fetchRecords();
    } catch (e) {
      AppToast.showError(context, '重命名失败: $e');
    }
  }

  Future<void> _restoreRecord(dynamic record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.data_sync.restore_backup_title),
        content: Text(t.data_sync.restore_backup_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(t.data_sync.start_restore_button),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true); // 复用 同步中 状态

    try {
      final appDir = await getTemporaryDirectory();
      final localPath = p.join(
        appDir.path,
        'restore_${DateTime.now().millisecondsSinceEpoch}.zip',
      );

      final config = ref.read(dataSyncConfigServiceProvider);
      if (config.syncTarget == SyncTarget.s3) {
        final client = S3ClientService(
          endpoint: config.s3Endpoint,
          region: config.s3Region,
          bucket: config.s3Bucket,
          accessKey: config.s3AccessKey,
          secretKey: config.s3SecretKey,
          basePath: config.s3Path,
        );
        await client.downloadFile(record.filename, localPath);
      } else if (config.syncTarget == SyncTarget.webdav) {
        final client = WebDavClientService(
          url: config.webdavUrl,
          username: config.webdavUsername,
          password: config.webdavPassword,
          basePath: config.webdavPath,
        );
        await client.downloadFile(record.filename, localPath);
      }

      final syncService = ref.read(dataSyncServiceProvider);
      await syncService.restoreFromZip(localPath);

      if (mounted) {
        AppToast.showSuccess(context, t.common.success);
      }
    } catch (e) {
      AppToast.showError(context, t.common.error);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // --- 列表项构建已交由 SyncRecordItem 处理 ---
}
