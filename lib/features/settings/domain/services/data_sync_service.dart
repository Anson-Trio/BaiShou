import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 数据同步服务类
/// 核心逻辑包括将本地数据库和图片资源打包成 ZIP 文件，以及从 ZIP 文件还原数据。
class DataSyncService {
  /// 创建一个包含 SQLite 数据库和图片目录的备份 ZIP 文件。
  /// 返回生成的 ZIP 文件在本地临时目录下的完整路径。
  Future<String> createBackupZip() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDir.path, 'baishou.sqlite'); // 数据库路径
    final imagesDirPath = p.join(appDir.path, 'images'); // 图片存储目录路径

    // 获取系统临时目录用于存放生成的 ZIP 压缩包
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File(p.join(tempDir.path, 'baishou_backup_$timestamp.zip'));

    // 初始化 ZIP 编码器
    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);

    // 将数据库文件添加到压缩包
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      encoder.addFile(dbFile);
    }

    // 将整个图片目录添加到压缩包
    final imagesDir = Directory(imagesDirPath);
    if (await imagesDir.exists()) {
      encoder.addDirectory(imagesDir);
    }

    // 完成编码
    encoder.close();

    return zipFile.path;
  }

  /// 从指定的 ZIP 文件路径还原数据。
  /// 注意：此操作会覆盖当前的 SQLite 数据库和 images 目录下的内容！
  Future<void> restoreFromZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('未找到备份文件：$zipPath');
    }

    final appDir = await getApplicationDocumentsDirectory();

    // 在还原之前，为了安全起见，先彻底清空当前的 images 目录
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    if (await imagesDir.exists()) {
      await imagesDir.delete(recursive: true);
    }

    // 读取压缩包字节码并进行解码
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 遍历压缩包内的每一个条目进行解压
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final targetPath = p.join(appDir.path, filename);
        final outFile = File(targetPath);

        // 递归确保父级目录存在 (例如 /images/xxx.jpg 需要先有 images 目录)
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(data, flush: true);
      } else {
        // 如果是目录条目，直接创建目录
        final targetDir = Directory(p.join(appDir.path, filename));
        await targetDir.create(recursive: true);
      }
    }
  }
}

/// Riverpod Provider 定义
final dataSyncServiceProvider = Provider<DataSyncService>((ref) {
  return DataSyncService();
});
