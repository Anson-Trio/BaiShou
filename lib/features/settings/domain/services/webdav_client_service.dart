import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;

/// WebDAV 同步记录详情类
/// 封装了存储在 WebDAV 服务器上的备份文件的元数据
class WebDavSyncRecord {
  final String filename; // 文件名
  final DateTime lastModified; // 最后修改时间
  final int sizeInBytes; // 文件大小（字节）

  WebDavSyncRecord({
    required this.filename,
    required this.lastModified,
    required this.sizeInBytes,
  });
}

/// WebDAV 客户端服务类
/// 处理与 WebDAV 兼容服务器（如坚果云、Nextcloud 或私有群晖 NAS）的交互
class WebDavClientService {
  final String url; // WebDAV 服务的完整 URL 地址
  final String username; // 用户名
  final String password; // 密码或应用授权码
  final String basePath; // 远程同步的基础目录

  WebDavClientService({
    required this.url,
    required this.username,
    required this.password,
    required this.basePath,
  });

  /// 创建底层 WebDAV 客户端实例
  webdav.Client _createClient() {
    return webdav.newClient(
      url,
      user: username,
      password: password,
      debug: false,
    );
  }

  /// 递归确保远程目录路径存在
  /// WebDAV 的 mkdir 通常是一级一级创建的
  Future<void> _ensureDirExists(webdav.Client client, String path) async {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    String currentPath = '';

    for (final part in parts) {
      currentPath += '/$part';
      try {
        await client.mkdir(currentPath);
      } catch (e) {
        // 通常如果目录已存在会报错，这里忽略错误继续执行
      }
    }
  }

  /// 将本地文件上传到 WebDAV 服务器
  Future<void> uploadFile(File file) async {
    final client = _createClient();
    final filename = p.basename(file.path);

    // 标准化目标路径
    String targetPath = basePath;
    if (!targetPath.endsWith('/')) {
      targetPath += '/';
    }

    // 确保远程目录层级已创建
    await _ensureDirExists(client, targetPath);

    final remotePath = '$targetPath$filename';

    // 读取本地文件字节流并写入远程路径
    final bytes = await file.readAsBytes();
    await client.write(remotePath, bytes);
  }

  /// 从 WebDAV 服务器下载文件到本地路径
  Future<void> downloadFile(
    String targetFilename,
    String localDestinationPath,
  ) async {
    final client = _createClient();

    String targetPath = basePath;
    if (!targetPath.endsWith('/')) {
      targetPath += '/';
    }
    final remotePath = '$targetPath$targetFilename';

    // 读取远程文件内容并写入本地
    final bytes = await client.read(remotePath);
    final outFile = File(localDestinationPath);
    await outFile.writeAsBytes(bytes, flush: true);
  }

  /// 列出配置的 WebDAV 路径下的所有备份记录
  Future<List<WebDavSyncRecord>> listFiles() async {
    final client = _createClient();

    String targetPath = basePath;
    if (!targetPath.endsWith('/')) {
      targetPath += '/';
    }

    final records = <WebDavSyncRecord>[];

    try {
      // 读取目录下的所有条目
      final list = await client.readDir(targetPath);

      for (final item in list) {
        final name = item.name;
        // 忽略父目录链接、当前目录链接以及任何子文件夹
        if (name == null || item.isDir == true) continue;

        records.add(
          WebDavSyncRecord(
            filename: name,
            lastModified: item.mTime ?? DateTime.now(),
            sizeInBytes: item.size ?? 0,
          ),
        );
      }

      // 按时间戳倒序排列
      records.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    } catch (e) {
      // 如果目录不存在，WebDAV 可能抛出 404 错误
      // 这种情况下我们视为空列表而不是抛出异常
      if (e.toString().contains('404')) {
        return [];
      }
      throw Exception('列出 WebDAV 文件失败: $e');
    }

    return records;
  }

  /// 删除文件
  Future<void> delete(String filename) async {
    final client = _createClient();
    String targetPath = basePath;
    if (!targetPath.endsWith('/')) targetPath += '/';
    final remotePath = '$targetPath$filename';

    await client.remove(remotePath);
  }

  /// 重命名/移动文件
  Future<void> rename(String oldFilename, String newFilename) async {
    final client = _createClient();
    String targetPath = basePath;
    if (!targetPath.endsWith('/')) targetPath += '/';
    final oldPath = '$targetPath$oldFilename';
    final newPath = '$targetPath$newFilename';

    // 如果 client.move 不存在，尝试 copy + remove
    try {
      await client.copy(oldPath, newPath, false); // Add overwrite param
      await client.remove(oldPath);
    } catch (e) {
      throw Exception('重命名 WebDAV 文件失败: $e');
    }
  }
}
