import 'dart:convert';
import 'dart:io';

import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_service.g.dart';

/// 描述空间库的元信息
class VaultInfo {
  final String name;
  final String path;
  final DateTime createdAt;
  final DateTime lastAccessedAt;

  VaultInfo({
    required this.name,
    required this.path,
    required this.createdAt,
    required this.lastAccessedAt,
  });

  factory VaultInfo.fromJson(Map<String, dynamic> json) {
    return VaultInfo(
      name: json['name'] as String,
      path: json['path'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
  };
}

/// 全局 Vault 管理服务
/// 负责读取 `vault_registry.json`，并对外暴露活跃 Vault 的状态。
@Riverpod(keepAlive: true)
class VaultService extends _$VaultService {
  late final StoragePathService _pathProvider;
  File? _registryFile;

  List<VaultInfo> _vaults = [];

  @override
  Future<VaultInfo?> build() async {
    _pathProvider = ref.read(storagePathServiceProvider);
    await _initRegistry();
    return _getActiveVault();
  }

  Future<void> _initRegistry() async {
    final globalDir = await _pathProvider.getGlobalRegistryDirectory();
    _registryFile = File(p.join(globalDir.path, 'vault_registry.json'));

    if (!_registryFile!.existsSync()) {
      // 首次启动，创建一个名为 "Personal" 的默认空间
      final defaultVault = VaultInfo(
        name: 'Personal',
        path: (await _pathProvider.getVaultDirectory('Personal')).path,
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
      _vaults = [defaultVault];
      await _saveRegistry();
    } else {
      final content = await _registryFile!.readAsString();
      if (content.trim().isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(content);
        _vaults = jsonList.map((e) => VaultInfo.fromJson(e)).toList();
      }
    }
  }

  Future<void> _saveRegistry() async {
    if (_registryFile != null) {
      final jsonString = jsonEncode(_vaults.map((v) => v.toJson()).toList());
      await _registryFile!.writeAsString(jsonString);
    }
  }

  /// 获取最后访问的有效 Vault
  VaultInfo? _getActiveVault() {
    if (_vaults.isEmpty) return null;

    // 找出 lastAccessedAt 最大的那个，如果物理文件丢失，则在未来实现里剔除。
    _vaults.sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return _vaults.first;
  }

  /// 获取所有注册的 Vault 列表
  List<VaultInfo> getAllVaults() => List.unmodifiable(_vaults);

  /// 切换或创建空间库 (Vault)
  ///
  /// 该方法是白守多库架构的核心：
  /// 1. 如果空间已存在，则更新其“最后访问时间”。
  /// 2. 如果是新空间，则在物理磁盘上创建对应的目录结构，并存入注册表。
  Future<void> switchVault(String vaultName) async {
    // 首先检查目标空间是否已经在我们的注册中心记录在案
    final existingIndex = _vaults.indexWhere((v) => v.name == vaultName);

    if (existingIndex != -1) {
      // --- 情况 A: 空间已存在 ---
      // 我们只需要更新它的 lastAccessedAt，这样 getActiveVault() 排序时它就会排到第一位
      final updated = VaultInfo(
        name: _vaults[existingIndex].name,
        path: _vaults[existingIndex].path,
        createdAt: _vaults[existingIndex].createdAt,
        lastAccessedAt: DateTime.now(),
      );
      _vaults[existingIndex] = updated;
    } else {
      // --- 情况 B: 创建全新的空间 ---
      // 1. 调用路径服务在本地磁盘创建物理文件夹
      final newVaultDir = await _pathProvider.getVaultDirectory(vaultName);

      // 2. 初始化该空间的物理基建：系统配置文件夹 (.baishou) 和 日志文件夹 (Journals)
      await _pathProvider.getVaultSystemDirectory(vaultName);
      await _pathProvider.getJournalsBaseDirectory(vaultName);

      // 3. 将新空间信息加入内存列表
      final newVault = VaultInfo(
        name: vaultName,
        path: newVaultDir.path,
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
      _vaults.add(newVault);
    }

    // 无论哪种情况，都需要持久化更新后的注册表文件，确保下次启动能恢复状态
    await _saveRegistry();

    // ==========================================
    // 【关键疑问解答】：为什么要在这里手动给 state 赋值？
    // ==========================================
    // 1. 通知 UI 重绘：Riverpod 的 state 改变会触发监听了这个 Provider 的所有 Widget 重建。
    //    比如顶部标题栏显示的“当前库：Personal”，如果不刷新，它就不会变。
    //
    // 2. 级联重载 Provider (Cascade Refresh)：
    //    在白守架构中，诸如 `ShadowIndexDatabase` 或 `DiaryRepository` 都极度依赖“当前活跃 Vault”的路径。
    //    只要这里 state 一变，依赖它的其他下游 Provider 就会自动重新计算（执行 watch 逻辑），
    //    从而实现“切换库”的一瞬间，底层数据库也跟着无缝切换的效果。
    state = AsyncData(_getActiveVault());
  }
}
