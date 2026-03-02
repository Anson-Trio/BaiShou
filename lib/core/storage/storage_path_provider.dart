import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baishou/core/providers/shared_preferences_provider.dart';

part 'storage_path_provider.g.dart';

/// 白守核心存储路径服务
/// 遵循 "物理文件 + SQLite 索引" 架构，统管数据的根目录与空间目录。
class StoragePathService {
  final SharedPreferences _prefs;
  StoragePathService(this._prefs);

  static const String rootFolderName = 'BaiShou_Root';
  static const String systemFolderName = '.baishou';
  static const String _customRootKey = 'custom_storage_root';

  /// 获取白守数据的绝对物理根目录
  Future<Directory> getRootDirectory() async {
    // 优先尝试获取用户自定义的存储路径
    final customPath = _prefs.getString(_customRootKey);
    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      try {
        if (!customDir.existsSync()) {
          await customDir.create(recursive: true);
        }
        // 增加一個簡單的可寫性檢查：嘗試在目錄下創建一個臨時文件
        final testFile = File(p.join(customDir.path, '.write_test'));
        await testFile.writeAsString('test');
        // 嘗試刪除測試文件，如果失敗（如在 Windows 上被鎖定）也不影響「可寫」的判定
        try {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        } catch (e) {
          // debugPrint(
          //   'StoragePathService: Cleanup of test file failed (non-critical): $e',
          // );
        }

        return customDir;
      } catch (e) {
        // 如果自定義路徑不可寫（如 Scoped Storage 限制或權限不足），則退回到預設邏輯
        debugPrint(
          'StoragePathService: Custom path $customPath is not writable: $e',
        );
      }
    }

    Directory? baseDir;

    if (Platform.isAndroid) {
      // 默认使用內部存儲的 Documents 目录，这是最安全且不需要额外權限的
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final rootDir = Directory(p.join(baseDir.path, rootFolderName));
    if (!rootDir.existsSync()) {
      await rootDir.create(recursive: true);
    }
    return rootDir;
  }

  /// 更新自定义根路径
  Future<void> updateRootDirectory(String path) async {
    await _prefs.setString(_customRootKey, path);
  }

  /// 获取当前配置的原始根路径字符串 (用于 UI 显示)
  String? getCustomRootPath() => _prefs.getString(_customRootKey);

  /// 获取全局注册中心目录 (`<Root>/.baishou/`)
  Future<Directory> getGlobalRegistryDirectory() async {
    final root = await getRootDirectory();
    final globalDir = Directory(p.join(root.path, systemFolderName));
    if (!globalDir.existsSync()) {
      await globalDir.create(recursive: true);
    }
    return globalDir;
  }

  /// 获取特定 Vault 的物理根目录 (`<Root>/VaultName/`)
  Future<Directory> getVaultDirectory(String vaultName) async {
    final safeName = vaultName.replaceAll(RegExp(r'[/\\]'), '_');
    final root = await getRootDirectory();
    final vaultDir = Directory(p.join(root.path, safeName));
    if (!vaultDir.existsSync()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// 获取特定 Vault 的系统级元数据目录 (`<Vault>/.baishou/`)
  Future<Directory> getVaultSystemDirectory(String vaultName) async {
    final vaultDir = await getVaultDirectory(vaultName);
    final vaultSysDir = Directory(p.join(vaultDir.path, systemFolderName));
    if (!vaultSysDir.existsSync()) {
      await vaultSysDir.create(recursive: true);
    }
    return vaultSysDir;
  }

  /// 获取特定 Vault 下日志存放的物理基础路径 (`<Vault>/Journals`)
  Future<Directory> getJournalsBaseDirectory(String vaultName) async {
    final vaultDir = await getVaultDirectory(vaultName);
    final journalsDir = Directory(p.join(vaultDir.path, 'Journals'));
    if (!journalsDir.existsSync()) {
      await journalsDir.create(recursive: true);
    }
    return journalsDir;
  }
}

@Riverpod(keepAlive: true)
StoragePathService storagePathService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StoragePathService(prefs);
}
