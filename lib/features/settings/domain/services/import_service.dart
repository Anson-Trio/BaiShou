import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/theme/theme_service.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/settings/domain/services/export_service.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:flutter/foundation.dart' hide Summary;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 导入结果
class ImportResult {
  final int diariesImported;
  final int summariesImported;
  final bool profileRestored;
  final Map<String, dynamic>? configData;
  final String? snapshotPath;
  final String? error;

  const ImportResult({
    this.diariesImported = 0,
    this.summariesImported = 0,
    this.profileRestored = false,
    this.configData,
    this.snapshotPath,
    this.error,
  });

  bool get success => error == null;
}

/// 解析后的导入数据 (用于 isolate 传输)
class ParsedImportData {
  final Map<String, dynamic> manifest;
  final List<dynamic>? diaries;
  final List<dynamic>? summaries;
  final Map<String, dynamic>? config;

  ParsedImportData({
    required this.manifest,
    this.diaries,
    this.summaries,
    this.config,
  });
}

/// 在 Isolate 中运行的解析函数
/// 使用 extractFileToDisk 解压到临时目录，再读取文件，避免 OOM
Future<ParsedImportData> parseZipData(String zipFilePath) async {
  // 创建临时目录
  final tempDir = Directory.systemTemp.createTempSync('baishou_import_');

  try {
    // 使用 archive_io 的 extractFileToDisk 直接解压到磁盘
    // 这不会将整个 ZIP 加载到内存，非常高效
    await extractFileToDisk(zipFilePath, tempDir.path);

    // 辅助函数：读取并解析 JSON 文件
    dynamic parseJsonFile(String relativePath) {
      final file = File(path.join(tempDir.path, relativePath));
      if (!file.existsSync()) return null;
      try {
        final content = file.readAsStringSync();
        return jsonDecode(content);
      } catch (_) {
        return null;
      }
    }

    // 1. 读取并验证 manifest
    final manifest = parseJsonFile('manifest.json');
    if (manifest == null) {
      throw Exception('无效的备份文件：缺少 manifest.json');
    }

    // 2. 读取其他数据
    final diaries = parseJsonFile('data/diaries.json') as List<dynamic>?;
    final summaries = parseJsonFile('data/summaries.json') as List<dynamic>?;
    final config =
        parseJsonFile('config/user_profile.json') as Map<String, dynamic>?;

    return ParsedImportData(
      manifest: manifest as Map<String, dynamic>,
      diaries: diaries,
      summaries: summaries,
      config: config,
    );
  } finally {
    // 清理临时目录
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

class ImportService {
  final DiaryRepository _diaryRepository;
  final SummaryRepository _summaryRepository;
  final ExportService _exportService;
  final UserProfileNotifier _profileNotifier;
  final ThemeNotifier _themeNotifier;
  final ApiConfigService _apiConfig;

  ImportService({
    required DiaryRepository diaryRepository,
    required SummaryRepository summaryRepository,
    required ExportService exportService,
    required UserProfileNotifier profileNotifier,
    required ThemeNotifier themeNotifier,
    required ApiConfigService apiConfig,
  }) : _diaryRepository = diaryRepository,
       _summaryRepository = summaryRepository,
       _exportService = exportService,
       _profileNotifier = profileNotifier,
       _themeNotifier = themeNotifier,
       _apiConfig = apiConfig;

  /// 从 ZIP 文件导入备份（覆盖模式：先自动创建快照，再清空数据，最后写入）
  Future<ImportResult> importFromZip(File zipFile) async {
    try {
      // 1. 传递文件路径给 isolate (避免主线程读取大文件)
      final parsedData = await compute(parseZipData, zipFile.path);

      // 2. 验证版本
      final schemaVersion = parsedData.manifest['schema_version'] as int? ?? 0;
      if (schemaVersion > 1) {
        return ImportResult(error: '备份版本过高 (v$schemaVersion)，请升级白守后再导入');
      }

      // 3. 创建导入前快照（用户可恢复到此节点）
      String? snapshotPath;
      try {
        final snapshotFile = await _exportService.exportToZip(share: true);
        if (snapshotFile != null) {
          // 将快照移动到持久化目录
          final appDir = await getApplicationDocumentsDirectory();
          final snapshotDir = Directory(path.join(appDir.path, 'snapshots'));
          if (!snapshotDir.existsSync()) {
            await snapshotDir.create(recursive: true);
          }
          final now = DateTime.now();
          final snapshotName =
              'pre_import_${DateFormat('yyyyMMdd_HHmmss').format(now)}.zip';
          final destFile = File(path.join(snapshotDir.path, snapshotName));
          await snapshotFile.copy(destFile.path);
          snapshotPath = destFile.path;
          debugPrint('Import: Snapshot created at $snapshotPath');
        }
      } catch (e) {
        debugPrint('Import: Failed to create snapshot, proceeding anyway: $e');
      }

      // 4. 清空现有数据（覆盖模式）
      await _diaryRepository.deleteAllDiaries();
      await _summaryRepository.deleteAllSummaries();

      // 5. 导入日记
      int diariesImported = 0;
      if (parsedData.diaries != null) {
        diariesImported = await _importDiaries(parsedData.diaries!);
      }

      // 6. 导入总结
      int summariesImported = 0;
      if (parsedData.summaries != null) {
        summariesImported = await _importSummaries(parsedData.summaries!);
      }

      // 7. 返回结果
      return ImportResult(
        diariesImported: diariesImported,
        summariesImported: summariesImported,
        profileRestored: parsedData.config != null,
        configData: parsedData.config,
        snapshotPath: snapshotPath,
      );
    } catch (e) {
      debugPrint('Import error: $e');
      if (e.toString().contains('manifest.json')) {
        return ImportResult(error: '无效的备份文件：缺少 manifest.json');
      }
      return ImportResult(error: '导入失败: $e');
    }
  }

  // --- 私有方法 ---

  Future<int> _importDiaries(List<dynamic> diariesJson) async {
    // 1. 解析所有日记对象
    final parsedDiaries = <Diary>[];
    for (final item in diariesJson) {
      final map = item as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      parsedDiaries.add(
        Diary(
          id: 0,
          date: date,
          content: map['content'] as String? ?? '',
          tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    // 2. 批量插入（数据已被清空，无需去重）
    if (parsedDiaries.isNotEmpty) {
      const batchSize = 500;
      for (var i = 0; i < parsedDiaries.length; i += batchSize) {
        final end = (i + batchSize < parsedDiaries.length)
            ? i + batchSize
            : parsedDiaries.length;
        await _diaryRepository.batchSaveDiaries(parsedDiaries.sublist(i, end));
      }
    }

    return parsedDiaries.length;
  }

  Future<int> _importSummaries(List<dynamic> summariesJson) async {
    final parsedSummaries = <Summary>[];

    for (final item in summariesJson) {
      final map = item as Map<String, dynamic>;
      final typeStr = map['type'] as String? ?? 'weekly';
      final type = SummaryType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => SummaryType.weekly,
      );
      final startDate = DateTime.parse(map['start_date'] as String);
      final endDate = DateTime.parse(map['end_date'] as String);

      parsedSummaries.add(
        Summary(
          id: 0,
          type: type,
          startDate: startDate,
          endDate: endDate,
          content: map['content'] as String? ?? '',
          sourceIds:
              (map['source_ids'] as List<dynamic>?)?.cast<String>() ?? [],
          generatedAt: DateTime.now(),
        ),
      );
    }

    // 批量插入（数据已被清空，无需去重）
    if (parsedSummaries.isNotEmpty) {
      const batchSize = 100;
      for (var i = 0; i < parsedSummaries.length; i += batchSize) {
        final end = (i + batchSize < parsedSummaries.length)
            ? i + batchSize
            : parsedSummaries.length;
        await _summaryRepository.batchAddSummaries(
          parsedSummaries.sublist(i, end),
        );
      }
    }

    return parsedSummaries.length;
  }

  /// 恢复用户配置（主题、API Key 等）
  /// 注意：此方法会触发主题变更，必须在所有 Dialog 关闭后再调用
  Future<void> restoreConfig(Map<String, dynamic> config) async {
    // 恢复昵称
    final nickname = config['nickname'] as String?;
    if (nickname != null && nickname.isNotEmpty) {
      await _profileNotifier.updateNickname(nickname);
    }

    // 恢复主题色
    final seedColorValue = config['seed_color'] as int?;
    if (seedColorValue != null) {
      await _themeNotifier.setSeedColor(Color(seedColorValue));
    }

    // 恢复深色模式
    final themeModeIndex = config['theme_mode'] as int?;
    if (themeModeIndex != null &&
        themeModeIndex >= 0 &&
        themeModeIndex < ThemeMode.values.length) {
      await _themeNotifier.setThemeMode(ThemeMode.values[themeModeIndex]);
    }

    // 恢复 AI 配置
    final aiProvider = config['ai_provider'] as String?;
    if (aiProvider != null) {
      final provider = AiProvider.values.firstWhere(
        (p) => p.name == aiProvider,
        orElse: () => AiProvider.gemini,
      );
      await _apiConfig.setProvider(provider);
    }

    final geminiApiKey = config['gemini_api_key'] as String?;
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      await _apiConfig.setGeminiApiKey(geminiApiKey);
    }

    final geminiBaseUrl = config['gemini_base_url'] as String?;
    if (geminiBaseUrl != null && geminiBaseUrl.isNotEmpty) {
      await _apiConfig.setGeminiBaseUrl(geminiBaseUrl);
    }

    final openAiApiKey = config['openai_api_key'] as String?;
    if (openAiApiKey != null && openAiApiKey.isNotEmpty) {
      await _apiConfig.setOpenAiApiKey(openAiApiKey);
    }

    final openAiBaseUrl = config['openai_base_url'] as String?;
    if (openAiBaseUrl != null && openAiBaseUrl.isNotEmpty) {
      await _apiConfig.setOpenAiBaseUrl(openAiBaseUrl);
    }

    final aiModel = config['ai_model'] as String?;
    if (aiModel != null && aiModel.isNotEmpty) {
      await _apiConfig.setModel(aiModel);
    }

    // 恢复头像（Base64 解码后保存到本地）
    final avatarBase64 = config['avatar_base64'] as String?;
    final avatarExt = config['avatar_ext'] as String? ?? 'jpg';
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        final avatarBytes = base64Decode(avatarBase64);
        final appDir = await getApplicationDocumentsDirectory();
        final avatarDir = Directory(path.join(appDir.path, 'avatars'));
        if (!avatarDir.existsSync()) {
          await avatarDir.create(recursive: true);
        }
        final avatarFile = File(
          path.join(
            avatarDir.path,
            'avatar_imported_${DateTime.now().millisecondsSinceEpoch}.$avatarExt',
          ),
        );
        await avatarFile.writeAsBytes(avatarBytes);
        await _profileNotifier.updateAvatar(avatarFile);
      } catch (_) {
        // 头像恢复失败不影响整体导入
      }
    }
  }
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    diaryRepository: ref.watch(diaryRepositoryProvider),
    summaryRepository: ref.watch(summaryRepositoryProvider),
    exportService: ref.watch(exportServiceProvider),
    profileNotifier: ref.watch(userProfileProvider.notifier),
    themeNotifier: ref.watch(themeProvider.notifier),
    apiConfig: ref.watch(apiConfigServiceProvider),
  );
});
