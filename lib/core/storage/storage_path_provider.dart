import 'dart:io';
import 'package:baishou/i18n/strings.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_path_provider.g.dart';

/// 白守核心存储路径服务
/// 遵循 "物理文件 + SQLite 影子索引" 架构，统管数据的根目录与空间目录。
class StoragePathService {
  static const String rootFolderName = 'BaiShou_Root';
  static const String systemFolderName = '.baishou';

  /// 获取白守数据的绝对物理根目录
  ///
  /// 该方法定义了白守在不同平台下的数据归宿：
  /// - **Android**: 尝试使用外部存储的应用专属目录。这样做的好处是即便应用卸载，
  ///   如果用户手动备份了该目录，数据依然存在，且用户可以通过系统文件管理器直接查看 Markdown 文件。
  /// - **iOS/桌面端**: 使用标准的文档目录 (Documents)，确保数据的私密性与系统级备份。
  Future<Directory> getRootDirectory() async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      // 尝试获取可公开访问的外部存储，这是白守“数据主权”在 Android 上的体现
      baseDir = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else {
      // Windows, macOS, Linux 默认放在用户的文档目录下，方便用户直接通过电脑浏览日记物理文件
      baseDir = await getApplicationDocumentsDirectory();
    }

    if (baseDir == null) {
      // [国际化改造]：利用 i18n 强类型 Key 替代硬编码错误提示
      throw Exception(t.common.errors.storage_path_not_found);
    }

    // 拼装最终的 BaiShou_Root 路径，所有 Vault 都会在这个目录下并列存储
    final rootDir = Directory(p.join(baseDir.path, rootFolderName));
    if (!rootDir.existsSync()) {
      await rootDir.create(recursive: true);
    }
    return rootDir;
  }

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
    // 基础防呆校验：移除可能导致目录跃迁的恶意字符
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
  /// 分析文件在 `Year` 目录，日记详情在 `Year/Month` 目录。
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
  return StoragePathService();
}
