import 'dart:io';
import 'dart:typed_data';
import 'package:minio/minio.dart';
import 'package:path/path.dart' as p;
import 'package:baishou/i18n/strings.g.dart';

/// S3 同步记录详情类
/// 封装了存储在 S3 上的备份文件的基本元数据
class S3SyncRecord {
  final String filename; // 文件名 (通常是 baishou_backup_xxx.zip)
  final DateTime lastModified; // 最后修改时间
  final int sizeInBytes; // 文件大小（字节）

  S3SyncRecord({
    required this.filename,
    required this.lastModified,
    required this.sizeInBytes,
  });
}

/// S3 客户端服务类
/// 封装了与 Amazon S3 或 兼容的对象存储（如腾讯云 COS, 阿里云 OSS, Cloudflare R2）的交互逻辑
class S3ClientService {
  final String endpoint; // API 访问端点 (例如: cos.ap-shanghai.myqcloud.com)
  final String region; // 区域 (例如: ap-shanghai)
  final String bucket; // 存储桶名称
  final String accessKey; // 访问密钥 ID
  final String secretKey; // 私有访问密钥
  final String basePath; // 存储桶内的基础路径 (前缀)

  S3ClientService({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    required this.basePath,
  });

  /// 创建底层 Minio 客户端实例
  Minio _createClient() {
    final uri = Uri.parse(endpoint);
    return Minio(
      endPoint: uri.host,
      // 如果未指定端口，根据协议自动推断
      port: uri.port == 0 ? (uri.scheme == 'https' ? 443 : 80) : uri.port,
      useSSL: uri.scheme == 'https',
      accessKey: accessKey,
      secretKey: secretKey,
      region: region.isNotEmpty ? region : 'us-east-1',
      // 重要: 关闭 Path-Style 访问以兼容腾讯云 COS 的域名寻址规范 (COS 要求 Virtual-hosted style)
      pathStyle: false,
    );
  }

  /// 将本地文件上传到 S3 存储
  Future<void> uploadFile(File file) async {
    final client = _createClient();
    final filename = p.basename(file.path);

    // 标准化路径，确保不会出现双斜杠
    String targetPath = basePath;
    if (!targetPath.endsWith('/')) {
      targetPath += '/';
    }
    if (targetPath.startsWith('/')) {
      targetPath = targetPath.substring(1);
    }
    final objectName = '$targetPath$filename';

    final length = await file.length();
    final stream = file.openRead().cast<Uint8List>();

    // 直接上传流数据
    await client.putObject(bucket, objectName, stream, size: length);
  }

  /// 从 S3 下载文件到本地指定路径
  Future<void> downloadFile(
    String targetFilename,
    String localDestinationPath,
  ) async {
    final client = _createClient();

    String targetPath = basePath;
    if (!targetPath.endsWith('/')) {
      targetPath += '/';
    }
    if (targetPath.startsWith('/')) {
      targetPath = targetPath.substring(1);
    }
    final objectName = '$targetPath$targetFilename';

    // 由于部分版本的 Minio SDK 中 fGetObject 存在兼容性问题，这里直接使用 getObject 流并手动写入文件
    final stream = await client.getObject(bucket, objectName);
    final outFile = File(localDestinationPath);
    final sink = outFile.openWrite();
    await stream.pipe(sink);
    await sink.close();
  }

  /// 列出配置的 S3 桶/路径下的所有备份记录
  Future<List<S3SyncRecord>> listFiles() async {
    final client = _createClient();

    String targetPath = basePath;
    if (!targetPath.endsWith('/') &&
        targetPath.isNotEmpty &&
        targetPath != '/') {
      targetPath += '/';
    }
    if (targetPath.startsWith('/')) {
      targetPath = targetPath.substring(1);
    }

    final records = <S3SyncRecord>[];

    try {
      // 分页列出对象
      await for (var obj in client.listObjectsV2(bucket, prefix: targetPath)) {
        if (obj.objects.isNotEmpty) {
          for (var item in obj.objects) {
            // 忽略文件夹标记（以 / 结尾的键）
            if (item.key != null && item.key!.endsWith('/')) continue;

            records.add(
              S3SyncRecord(
                filename: p.basename(item.key!),
                lastModified: item.lastModified ?? DateTime.now(),
                sizeInBytes: item.size ?? 0,
              ),
            );
          }
        }
      }

      // 按时间戳倒序排列，确保最新的备份在最前面
      records.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    } catch (e) {
      // 捕获异常并包装成更具描述性的错误
      throw Exception(t.data_sync.list_s3_failed(e: e.toString()));
    }

    return records;
  }

  /// 删除指定的对象
  Future<void> deleteObject(String filename) async {
    final client = _createClient();
    String targetPath = basePath;
    if (!targetPath.endsWith('/')) targetPath += '/';
    if (targetPath.startsWith('/')) targetPath = targetPath.substring(1);
    final objectName = '$targetPath$filename';

    await client.removeObject(bucket, objectName);
  }

  /// 重命名对象 (S3 没有直接 rename，通常通过 copy + delete 实现)
  Future<void> renameObject(String oldFilename, String newFilename) async {
    final client = _createClient();
    String targetPath = basePath;
    if (!targetPath.endsWith('/')) targetPath += '/';
    if (targetPath.startsWith('/')) targetPath = targetPath.substring(1);

    final oldObjectName = '$targetPath$oldFilename';
    final newObjectName = '$targetPath$newFilename';

    // 1. 复制对象到新位置
    await client.copyObject(bucket, newObjectName, '$bucket/$oldObjectName');
    // 2. 删除旧对象
    await client.removeObject(bucket, oldObjectName);
  }
}
