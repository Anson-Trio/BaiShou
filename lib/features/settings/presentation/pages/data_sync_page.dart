import 'dart:io';
import 'package:baishou/core/widgets/app_toast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
                      _buildStatCard(
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
                      _buildStatCard(
                        context,
                        title: '备份总大小',
                        value: sizeString,
                        icon: Icons.storage_outlined,
                        color: Colors.green.shade600,
                      ),
                      _buildStatCard(
                        context,
                        title: '备份数量',
                        value: '${_records.length} 个',
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
                    Text(
                      '最近同步记录',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _buildRecordItem(context, _records[index]);
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
        title: const Text('删除备份?'),
        content: Text('确定要删除备份文件 ${record.filename} 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
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
        title: const Text('重命名备份'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '新文件名',
            hintText: 'baishou_backup_xxx.zip',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == record.filename)
      return;

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
        title: const Text('还原备份?'),
        content: const Text('注意：还原将覆盖当前设备上的所有数据！建议还原前先进行一次当前数据的备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('开始还原'),
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
        AppToast.showSuccess(context, '还原成功！');
      }
    } catch (e) {
      AppToast.showError(context, '还原失败: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
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
          Flexible(
            child: Column(
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onSelected: (val) {
              if (val == 'restore') _restoreRecord(record);
              if (val == 'rename') _renameRecord(record);
              if (val == 'delete') _deleteRecord(record);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'restore', child: Text('还原此备份')),
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
