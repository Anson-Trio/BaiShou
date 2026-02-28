import 'dart:io';

import 'package:baishou/core/storage/storage_path_provider.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

part 'journal_file_service.g.dart';

/// 物理文件层日志读写服务
/// 负责处理 Markdown + YAML Front Matter 格式文件的底层存储与提取。
/// 所有的 I/O 均受到当前活跃 Vault 边界的限制。
@Riverpod(keepAlive: true)
class JournalFileService extends _$JournalFileService {
  late final StoragePathService _pathProvider;

  @override
  FutureOr<void> build() async {
    _pathProvider = ref.read(storagePathServiceProvider);
    // 监听当前活跃的 Vault，切换时抛错重新挂载边界防线
    ref.watch(vaultServiceProvider);
  }

  /// 边界守卫 (Boundary Guard)
  /// 获取当前 Vault 的日志基目录，并确保其存在。
  Future<Directory> _getSecureJournalsBaseDir() async {
    final activeVault = await ref.read(vaultServiceProvider.future);
    if (activeVault == null) {
      throw Exception(t.common.errors.no_active_vault);
    }
    return await _pathProvider.getJournalsBaseDirectory(activeVault.name);
  }

  /// 获取或构建特定日期所对应的物理文件路径 (`Year/Month/yyyy-MM-dd.md`)
  Future<File> _resolveDateTargetFile(DateTime date) async {
    final baseDir = await _getSecureJournalsBaseDir();

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final fileName = '${DateFormat('yyyy-MM-dd').format(date)}.md';

    final monthDir = Directory(p.join(baseDir.path, year, month));
    if (!monthDir.existsSync()) {
      await monthDir.create(recursive: true);
    }

    return File(p.join(monthDir.path, fileName));
  }

  /// 获取某个月份的附件目录 (`Year/Month/Assets`)
  Future<Directory> _resolveMonthAssetsDir(DateTime date) async {
    final baseDir = await _getSecureJournalsBaseDir();
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');

    final assetsDir = Directory(p.join(baseDir.path, year, month, 'Assets'));
    if (!assetsDir.existsSync()) {
      await assetsDir.create(recursive: true);
    }
    return assetsDir;
  }

  /// 写入单个原子日记到物理文件
  /// 这个方法会将 Diary 对象序列化为包含 YAML Front Matter 的 Markdown 文本。
  Future<String> writeJournal(Diary diary) async {
    final file = await _resolveDateTargetFile(diary.createdAt);

    // 构建 YAML Front Matter
    final yamlWriter = YamlWriter();
    final metaData = {
      'id': diary.id,
      'createdAt': diary.createdAt.toIso8601String(),
      'updatedAt': diary.updatedAt.toIso8601String(),
      'weather': diary.weather,
      'mood': diary.mood,
      'location': diary.location,
      'locationDetail': diary.locationDetail,
      'isFavorite': diary.isFavorite,
      'tags': diary.tags,
      // 媒体资源如果是相对路径或网络 URL 会被保存，如果是新添加将被挪移到 Assets 待后续扩充逻辑
      'mediaPaths': diary.mediaPaths,
    };

    final yamlString = yamlWriter.write(metaData);

    // 拼装最终内容:
    // ---
    // yaml...
    // ---
    // content...
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.write(yamlString);
    if (!yamlString.endsWith('\n')) {
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.write(diary.content);

    // 文件操作锁控与刷入 (这里利用 Dart I/O 自身的异步写入阻塞)
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  /// 从物理物理文件读取日记实体
  Future<Diary?> readJournal(DateTime date) async {
    final file = await _resolveDateTargetFile(date);
    if (!file.existsSync()) return null;

    final content = await file.readAsString();

    // 解析 Front Matter
    final regex = RegExp(r'^---\r?\n(.*?)\r?\n---\r?\n(.*)$', dotAll: true);
    final match = regex.firstMatch(content);

    if (match == null) {
      // 降级处理：不包含标准 Front Matter 的散落 md
      return Diary(
        id: DateTime.now().millisecondsSinceEpoch,
        date: date,
        createdAt: date,
        updatedAt: date,
        content: content,
      );
    }

    final yamlStr = match.group(1) ?? '';
    final bodyStr = match.group(2) ?? '';

    try {
      final doc = loadYaml(yamlStr);
      final meta = Map<String, dynamic>.from(doc as Map);

      return Diary(
        id: meta['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.parse(
          meta['createdAt'] as String? ?? date.toIso8601String(),
        ),
        updatedAt: DateTime.parse(
          meta['updatedAt'] as String? ?? date.toIso8601String(),
        ),
        content: bodyStr.trim(),
        weather: meta['weather'] as String?,
        mood: meta['mood'] as String?,
        location: meta['location'] as String?,
        locationDetail: meta['locationDetail'] as String?,
        isFavorite: meta['isFavorite'] as bool? ?? false,
        tags: meta['tags'] != null
            ? List<String>.from(meta['tags'] as Iterable)
            : const [],
        mediaPaths: meta['mediaPaths'] != null
            ? List<String>.from(meta['mediaPaths'] as Iterable)
            : const [],
        date: null,
      );
    } catch (e) {
      // Yaml 抛出异常的防崩退逻辑
      return Diary(
        id: DateTime.now().millisecondsSinceEpoch,
        date: date,
        createdAt: date,
        updatedAt: date,
        content: content,
      );
    }
  }

  /// 从物理磁盘删除特定的日记文件
  Future<void> deleteJournalFile(DateTime date) async {
    final file = await _resolveDateTargetFile(date);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
