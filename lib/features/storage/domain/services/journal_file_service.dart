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
  StoragePathService get _pathProvider => ref.read(storagePathServiceProvider);

  @override
  FutureOr<void> build() async {
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

  /// 写入日记到物理文件（覆盖写入当天全部内容）
  /// 日记按天切分，一天对应一个 `yyyy-MM-dd.md` 文件。
  Future<String> writeJournal(Diary diary) async {
    final file = await _resolveDateTargetFile(diary.createdAt);
    final isNewFile = !file.existsSync();

    Map<String, dynamic> existingMeta = {};

    if (!isNewFile) {
      final content = await file.readAsString();
      final regex = RegExp(r'^---\r?\n(.*?)\r?\n---\r?\n(.*)$', dotAll: true);
      final match = regex.firstMatch(content);
      if (match != null) {
        final yamlStr = match.group(1) ?? '';
        try {
          final doc = loadYaml(yamlStr);
          existingMeta = Map<String, dynamic>.from(doc as Map);
        } catch (_) {}
      }
    }

    final yamlWriter = YamlWriter();
    final metaData = {
      'id': isNewFile ? diary.id : existingMeta['id'] ?? diary.id,
      'createdAt': isNewFile
          ? diary.createdAt.toIso8601String()
          : existingMeta['createdAt'] ?? diary.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'weather': diary.weather ?? existingMeta['weather'],
      'mood': diary.mood ?? existingMeta['mood'],
      'location': diary.location ?? existingMeta['location'],
      'locationDetail': diary.locationDetail ?? existingMeta['locationDetail'],
      'isFavorite': diary.isFavorite,
      'tags': diary.tags,
      'mediaPaths': diary.mediaPaths,
    };

    final yamlString = yamlWriter.write(metaData);

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.write(yamlString);
    if (!yamlString.endsWith('\n')) {
      buffer.writeln();
    }
    buffer.writeln('---');
    buffer.write(diary.content.trim());

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
        date: date,
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
