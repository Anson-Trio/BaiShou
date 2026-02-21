import 'package:baishou/core/widgets/app_toast.dart';
import 'package:baishou/features/settings/domain/services/data_sync_config_service.dart';
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
      backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      appBar: AppBar(
        title: const Text('数据同步配置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
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
              padding: const EdgeInsets.all(32),
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
              child: _buildConfigForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard({
    required int index,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedTarget == index;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTarget = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withOpacity(0.4)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.1)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
    if (_selectedTarget == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Text('本地存储不需要额外配置。点击左上角返回即可。'),
        ),
      );
    } else if (_selectedTarget == 1) {
      return _buildS3ConfigForm();
    } else if (_selectedTarget == 2) {
      return _buildWebDavConfigForm();
    }
    return const SizedBox.shrink();
  }

  Widget _buildS3ConfigForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'S3 存储配置',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            FilledButton.tonal(
              onPressed: _saveConfig,
              child: const Text('保存配置'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildFormField(
                title: 'Endpoint 服务地址',
                controller: _endpointController,
                icon: Icons.api_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildFormField(
                title: 'Region 区域名',
                controller: _regionController,
                icon: Icons.map_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildFormField(
                title: 'Bucket 存储桶',
                controller: _bucketController,
                icon: Icons.data_usage_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _buildFormField(
                title: 'Path 子路径',
                controller: _pathController,
                icon: Icons.folder_open_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                title: 'Access Key (AK)',
                controller: _akController,
                icon: Icons.vpn_key_outlined,
                obscure: _isObscure,
                trailing: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFormField(
                title: 'Secret Key (SK)',
                controller: _skController,
                icon: Icons.key_outlined,
                obscure: _isObscure,
                trailing: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWebDavConfigForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WebDAV 存储配置',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            FilledButton.tonal(
              onPressed: _saveConfig,
              child: const Text('保存配置'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildFormField(
                title: 'Server URL 服务地址',
                controller: _webdavUrlController,
                icon: Icons.api_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _buildFormField(
                title: 'Path 子路径',
                controller: _webdavPathController,
                icon: Icons.folder_open_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(
                title: 'Username 用户名',
                controller: _webdavUserController,
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFormField(
                title: 'Password 密码',
                controller: _webdavPwdController,
                icon: Icons.key_outlined,
                obscure: _isObscure,
                trailing: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String title,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            suffixIcon: trailing,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
