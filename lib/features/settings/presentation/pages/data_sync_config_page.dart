import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/domain/services/data_sync_config_service.dart';
import 'package:baishou/features/settings/presentation/widgets/config_form_field.dart';
import 'package:baishou/features/settings/presentation/widgets/sync_target_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataSyncConfigPage extends ConsumerStatefulWidget {
  const DataSyncConfigPage({super.key});

  @override
  ConsumerState<DataSyncConfigPage> createState() => _DataSyncConfigPageState();
}

class _DataSyncConfigPageState extends ConsumerState<DataSyncConfigPage> {
  int _selectedTarget = 0; // 0: Local, 1: S3, 2: WebDAV

  // S3 控制器
  final _endpointController = TextEditingController();
  final _bucketController = TextEditingController();
  final _regionController = TextEditingController();
  final _akController = TextEditingController();
  final _skController = TextEditingController();
  final _pathController = TextEditingController();

  // WebDAV 控制器
  final _webdavUrlController = TextEditingController();
  final _webdavUserController = TextEditingController();
  final _webdavPwdController = TextEditingController();
  final _webdavPathController = TextEditingController();

  bool _isObscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  void _loadConfig() {
    final service = ref.read(dataSyncConfigServiceProvider);
    setState(() {
      _selectedTarget = service.syncTarget.index;

      _endpointController.text = service.s3Endpoint;
      _regionController.text = service.s3Region;
      _bucketController.text = service.s3Bucket;
      _pathController.text = service.s3Path;
      _akController.text = service.s3AccessKey;
      _skController.text = service.s3SecretKey;

      _webdavUrlController.text = service.webdavUrl;
      _webdavUserController.text = service.webdavUsername;
      _webdavPwdController.text = service.webdavPassword;
      _webdavPathController.text = service.webdavPath;
    });
  }

  Future<void> _saveConfig() async {
    final service = ref.read(dataSyncConfigServiceProvider);

    // 保存结构化目标
    await service.setSyncTarget(SyncTarget.values[_selectedTarget]);

    if (_selectedTarget == 1) {
      // S3
      await service.saveS3Config(
        endpoint: _endpointController.text,
        region: _regionController.text,
        bucket: _bucketController.text,
        path: _pathController.text,
        accessKey: _akController.text,
        secretKey: _skController.text,
      );
    } else if (_selectedTarget == 2) {
      // WebDAV
      await service.saveWebdavConfig(
        url: _webdavUrlController.text,
        username: _webdavUserController.text,
        password: _webdavPwdController.text,
        path: _webdavPathController.text,
      );
    }

    if (mounted) {
      AppToast.showSuccess(context, '配置已保存');
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _bucketController.dispose();
    _regionController.dispose();
    _akController.dispose();
    _skController.dispose();
    _pathController.dispose();

    _webdavUrlController.dispose();
    _webdavUserController.dispose();
    _webdavPwdController.dispose();
    _webdavPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('数据同步配置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          final padding = isMobile ? 16.0 : 32.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择同步目标',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (isMobile)
                  Column(
                    children: [
                      _buildTargetCard(
                        index: 0,
                        icon: Icons.folder_outlined,
                        title: '本地存储',
                        description: '备份到设备本地目录',
                      ),
                      const SizedBox(height: 12),
                      _buildTargetCard(
                        index: 1,
                        icon: Icons.cloud_outlined,
                        title: 'S3 对象存储',
                        description: '兼容 AWS S3 的云存储服务',
                      ),
                      const SizedBox(height: 12),
                      _buildTargetCard(
                        index: 2,
                        icon: Icons.public_outlined,
                        title: 'WebDAV',
                        description: '通用网络文件存储协议',
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildTargetCard(
                          index: 0,
                          icon: Icons.folder_outlined,
                          title: '本地存储',
                          description: '备份到设备本地目录',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTargetCard(
                          index: 1,
                          icon: Icons.cloud_outlined,
                          title: 'S3 对象存储',
                          description: '兼容 AWS S3 的云存储服务',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTargetCard(
                          index: 2,
                          icon: Icons.public_outlined,
                          title: 'WebDAV',
                          description: '通用网络文件存储协议',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildConfigForm(isMobile: isMobile),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTargetCard({
    required int index,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SyncTargetCard(
      index: index,
      icon: icon,
      title: title,
      description: description,
      isSelected: _selectedTarget == index,
      onTap: () {
        setState(() {
          _selectedTarget = index;
        });
      },
    );
  }

  Widget _buildConfigForm({bool isMobile = false}) {
    if (_selectedTarget == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('本地存储不需要额外配置。保存后生效。'),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _saveConfig,
                child: const Text('设为本地同步目标'),
              ),
            ],
          ),
        ),
      );
    } else if (_selectedTarget == 1) {
      return _buildS3ConfigForm(isMobile: isMobile);
    } else if (_selectedTarget == 2) {
      return _buildWebDavConfigForm(isMobile: isMobile);
    }
    return const SizedBox.shrink();
  }

  Widget _buildS3ConfigForm({bool isMobile = false}) {
    Widget buildRow(List<Widget> children) {
      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: c,
                ),
              )
              .toList(),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            children
                .expand((c) => [Expanded(child: c), const SizedBox(width: 16)])
                .toList()
              ..removeLast(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'S3 存储配置',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.tonal(
              onPressed: _saveConfig,
              child: const Text('保存配置'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        buildRow([
          ConfigFormField(
            title: 'Endpoint 服务地址',
            controller: _endpointController,
            icon: Icons.api_outlined,
          ),
          ConfigFormField(
            title: 'Region 区域名',
            controller: _regionController,
            icon: Icons.map_outlined,
          ),
        ]),
        if (!isMobile) const SizedBox(height: 16),
        buildRow([
          ConfigFormField(
            title: 'Bucket 存储桶',
            controller: _bucketController,
            icon: Icons.data_usage_outlined,
          ),
          ConfigFormField(
            title: 'Path 子路径',
            controller: _pathController,
            icon: Icons.folder_open_outlined,
          ),
        ]),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        buildRow([
          ConfigFormField(
            title: 'Access Key (AK)',
            controller: _akController,
            icon: Icons.vpn_key_outlined,
            obscure: _isObscure,
            trailing: IconButton(
              icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            ),
          ),
          ConfigFormField(
            title: 'Secret Key (SK)',
            controller: _skController,
            icon: Icons.key_outlined,
            obscure: _isObscure,
            trailing: IconButton(
              icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildWebDavConfigForm({bool isMobile = false}) {
    Widget buildRow(List<Widget> children) {
      if (isMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: c,
                ),
              )
              .toList(),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            children
                .expand((c) => [Expanded(child: c), const SizedBox(width: 16)])
                .toList()
              ..removeLast(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'WebDAV 存储配置',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.tonal(
              onPressed: _saveConfig,
              child: const Text('保存配置'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        buildRow([
          ConfigFormField(
            title: 'Server URL 服务地址',
            controller: _webdavUrlController,
            icon: Icons.api_outlined,
          ),
          ConfigFormField(
            title: 'Path 子路径',
            controller: _webdavPathController,
            icon: Icons.folder_open_outlined,
          ),
        ]),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        buildRow([
          ConfigFormField(
            title: 'Username 用户名',
            controller: _webdavUserController,
            icon: Icons.person_outline,
          ),
          ConfigFormField(
            title: 'Password 密码',
            controller: _webdavPwdController,
            icon: Icons.key_outlined,
            obscure: _isObscure,
            trailing: IconButton(
              icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            ),
          ),
        ]),
      ],
    );
  }

  // --- 表单项构建已交由 ConfigFormField 处理 ---
}
