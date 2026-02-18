import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/theme/theme_service.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:flutter/foundation.dart' hide Summary;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 导入结果
class ImportResult {
  final int diariesImported;
  final int summariesImported;
  final bool profileRestored;
  final Map<String, dynamic>? configData;
  final String? error;

  const ImportResult({
    this.diariesImported = 0,
    this.summariesImported = 0,
    this.profileRestored = false,
    this.configData,
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
  final UserProfileNotifier _profileNotifier;
  final ThemeNotifier _themeNotifier;
  final ApiConfigService _apiConfig;

  ImportService({
    required DiaryRepository diaryRepository,
    required SummaryRepository summaryRepository,
    required UserProfileNotifier profileNotifier,
    required ThemeNotifier themeNotifier,
    required ApiConfigService apiConfig,
  }) : _diaryRepository = diaryRepository,
       _summaryRepository = summaryRepository,
       _profileNotifier = profileNotifier,
       _themeNotifier = themeNotifier,
       _apiConfig = apiConfig;

  /// 从 ZIP 文件导入备份
  /// [merge] 为 true 时跳过已存在的日记（按日期判断），false 时不做去重直接写入
  Future<ImportResult> importFromZip(File zipFile, {bool merge = true}) async {
    try {
      // 1. 传递文件路径给 isolate (避免主线程读取大文件)
      final parsedData = await compute(parseZipData, zipFile.path);

      // 2. 验证版本
      final schemaVersion = parsedData.manifest['schema_version'] as int? ?? 0;
      if (schemaVersion > 1) {
        return ImportResult(error: '备份版本过高 (v$schemaVersion)，请升级白守后再导入');
      }

      // 3. 导入日记 (IO/DB 操作)
      int diariesImported = 0;
      if (parsedData.diaries != null) {
        diariesImported = await _importDiaries(
          parsedData.diaries!,
          merge: merge,
        );
      }

      // 4. 导入总结
      int summariesImported = 0;
      if (parsedData.summaries != null) {
        summariesImported = await _importSummaries(parsedData.summaries!);
      }

      // 5. 返回结果 (不在此处恢复配置，避免在 dialog 未关闭时触发主题变更导致崩溃)
      return ImportResult(
        diariesImported: diariesImported,
        summariesImported: summariesImported,
        profileRestored: parsedData.config != null,
        configData: parsedData.config,
      );
    } catch (e) {
      debugPrint('Import error: $e');
      // 捕获 compute 抛出的异常
      if (e.toString().contains('manifest.json')) {
        // 提取我们自己的错误信息
        return ImportResult(error: '无效的备份文件：缺少 manifest.json');
      }
      return ImportResult(error: '导入失败: $e');
    }
  }

  // --- 私有方法 ---

  Future<int> _importDiaries(
    List<dynamic> diariesJson, {
    required bool merge,
  }) async {
    // 1. 解析所有日记对象
    final parsedDiaries = <Diary>[];
    for (final item in diariesJson) {
      final map = item as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      parsedDiaries.add(
        Diary(
          id: 0, // 占位 ID，不使用
          date: date,
          content: map['content'] as String? ?? '',
          tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    // 2. 过滤需要插入的日记
    final diariesToInsert = <Diary>[];
    if (merge) {
      // 获取现有日记的日期集合用于去重 (内存去重比逐条查库快)
      final existing = await _diaryRepository.getAllDiaries();
      final existingDates = existing
          .map(
            (d) =>
                '${d.date.year}-${d.date.month}-${d.date.day}-${d.date.hour}-${d.date.minute}',
          )
          .toSet();

      for (final diary in parsedDiaries) {
        final dateKey =
            '${diary.date.year}-${diary.date.month}-${diary.date.day}-${diary.date.hour}-${diary.date.minute}';
        if (!existingDates.contains(dateKey)) {
          diariesToInsert.add(diary);
        }
      }
    } else {
      diariesToInsert.addAll(parsedDiaries);
    }

    // 3. 批量插入
    if (diariesToInsert.isNotEmpty) {
      // 分批执行，防止一次性事务过大 (如一次 500 条)
      const batchSize = 500;
      for (var i = 0; i < diariesToInsert.length; i += batchSize) {
        final end = (i + batchSize < diariesToInsert.length)
            ? i + batchSize
            : diariesToInsert.length;
        await _diaryRepository.batchSaveDiaries(
          diariesToInsert.sublist(i, end),
        );
      }
    }

    return diariesToInsert.length;
  }

  Future<int> _importSummaries(List<dynamic> summariesJson) async {
    final summariesToInsert = <Summary>[];

    // 为了去重，我们需要检查每一条。
    // 如果数据量大，逐条检查 getSummaryByTypeAndDate 可能会慢。
    // 优化：一次性拉取所有 Summary (通常 Summary 数量不多)，在内存比对。
    final allExisting = await _summaryRepository.getSummaries();

    // 构建查找表: type_start_end -> true
    final existingMap = <String, bool>{};
    for (final s in allExisting) {
      final key =
          '${s.type.name}_${s.startDate.millisecondsSinceEpoch}_${s.endDate.millisecondsSinceEpoch}';
      existingMap[key] = true;
    }

    for (final item in summariesJson) {
      final map = item as Map<String, dynamic>;
      final typeStr = map['type'] as String? ?? 'weekly';
      final type = SummaryType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => SummaryType.weekly,
      );
      final startDate = DateTime.parse(map['start_date'] as String);
      final endDate = DateTime.parse(map['end_date'] as String);

      final key =
          '${type.name}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';

      if (existingMap.containsKey(key)) continue;

      summariesToInsert.add(
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

    // 3. 批量插入
    if (summariesToInsert.isNotEmpty) {
      const batchSize = 100;
      for (var i = 0; i < summariesToInsert.length; i += batchSize) {
        final end = (i + batchSize < summariesToInsert.length)
            ? i + batchSize
            : summariesToInsert.length;
        await _summaryRepository.batchAddSummaries(
          summariesToInsert.sublist(i, end),
        );
      }
    }

    return summariesToInsert.length;
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
    profileNotifier: ref.watch(userProfileProvider.notifier),
    themeNotifier: ref.watch(themeProvider.notifier),
    apiConfig: ref.watch(apiConfigServiceProvider),
  );
});
