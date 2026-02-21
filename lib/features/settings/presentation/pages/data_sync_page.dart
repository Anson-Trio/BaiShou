import 'dart:io';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/domain/services/data_sync_config_service.dart';
import 'package:baishou/features/settings/domain/services/data_sync_service.dart';
import 'package:baishou/features/settings/domain/services/s3_client_service.dart';
import 'package:baishou/features/settings/domain/services/webdav_client_service.dart';
import 'package:baishou/features/settings/presentation/pages/data_sync_config_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        AppToast.showError(context, '获取记录失败: $e');
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
      AppToast.showSuccess(context, '本地备份不需要通过此页面同步');
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
        AppToast.showSuccess(context, '同步成功！');
      }
      await _fetchRecords();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, '同步失败: $e');
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

    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: '同步目标',
                    value: config.syncTarget.name.toUpperCase(),
                    icon: config.syncTarget == SyncTarget.s3
                        ? Icons.cloud_done_outlined
                        : (config.syncTarget == SyncTarget.webdav
                              ? Icons.public
                              : Icons.folder),
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: '备份总大小',
                    value: sizeString,
                    icon: Icons.storage_outlined,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: '同步次数',
                    value: '${_records.length} 次',
                    icon: Icons.sync_alt_outlined,
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近同步记录',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DataSyncConfigPage(),
                          ),
                        ).then((_) => _fetchRecords());
                      },
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('同步设置'),
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
                      label: Text(_isSyncing ? '同步中...' : '立即同步'),
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无同步记录'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _records.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return _buildRecordItem(context, _records[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(BuildContext context, dynamic record) {
    final colorScheme = Theme.of(context).colorScheme;

    String filename = record.filename;
    DateTime lastModified = record.lastModified;
    int size = record.sizeInBytes;

    final sizeMb = (size / (1024 * 1024)).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 20,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '备份文件: $filename',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')} ${lastModified.hour.toString().padLeft(2, '0')}:${lastModified.minute.toString().padLeft(2, '0')} • 大小: $sizeMb MB',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () {
              AppToast.showSuccess(context, '恢复功能即将实现');
            },
            tooltip: '恢复此备份',
          ),
        ],
      ),
    );
  }
}
