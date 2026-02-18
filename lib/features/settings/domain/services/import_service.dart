import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/theme/theme_service.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 导入结果
class ImportResult {
  final int diariesImported;
  final int summariesImported;
  final bool profileRestored;
  final String? error;

  const ImportResult({
    this.diariesImported = 0,
    this.summariesImported = 0,
    this.profileRestored = false,
    this.error,
  });

  bool get success => error == null;
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
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. 读取并验证 manifest
      final manifestFile = _findFile(archive, 'manifest.json');
      if (manifestFile == null) {
        return const ImportResult(error: '无效的备份文件：缺少 manifest.json');
      }

      final manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;
      final schemaVersion = manifest['schema_version'] as int? ?? 0;

      if (schemaVersion > 1) {
        return ImportResult(error: '备份版本过高 (v$schemaVersion)，请升级白守后再导入');
      }

      // 2. 导入日记
      int diariesImported = 0;
      final diariesFile = _findFile(archive, 'data/diaries.json');
      if (diariesFile != null) {
        final diariesJson =
            jsonDecode(utf8.decode(diariesFile.content as List<int>))
                as List<dynamic>;
        diariesImported = await _importDiaries(diariesJson, merge: merge);
      }

      // 3. 导入总结
      int summariesImported = 0;
      final summariesFile = _findFile(archive, 'data/summaries.json');
      if (summariesFile != null) {
        final summariesJson =
            jsonDecode(utf8.decode(summariesFile.content as List<int>))
                as List<dynamic>;
        summariesImported = await _importSummaries(summariesJson);
      }

      // 4. 恢复用户配置
      bool profileRestored = false;
      final configFile = _findFile(archive, 'config/user_profile.json');
      if (configFile != null) {
        final config =
            jsonDecode(utf8.decode(configFile.content as List<int>))
                as Map<String, dynamic>;
        await _restoreConfig(config, archive);
        profileRestored = true;
      }

      return ImportResult(
        diariesImported: diariesImported,
        summariesImported: summariesImported,
        profileRestored: profileRestored,
      );
    } catch (e) {
      return ImportResult(error: '导入失败: $e');
    }
  }

  // --- 私有方法 ---

  ArchiveFile? _findFile(Archive archive, String filePath) {
    try {
      return archive.files.firstWhere((f) => f.name == filePath && f.isFile);
    } catch (_) {
      return null;
    }
  }

  Future<int> _importDiaries(
    List<dynamic> diariesJson, {
    required bool merge,
  }) async {
    int count = 0;

    // 如果是合并模式，获取现有日记的日期集合用于去重
    Set<String> existingDates = {};
    if (merge) {
      final existing = await _diaryRepository.getAllDiaries();
      existingDates = existing
          .map(
            (d) =>
                '${d.date.year}-${d.date.month}-${d.date.day}-${d.date.hour}-${d.date.minute}',
          )
          .toSet();
    }

    for (final item in diariesJson) {
      final map = item as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      final dateKey =
          '${date.year}-${date.month}-${date.day}-${date.hour}-${date.minute}';

      // 合并模式下跳过已存在的日记
      if (merge && existingDates.contains(dateKey)) continue;

      await _diaryRepository.saveDiary(
        date: date,
        content: map['content'] as String? ?? '',
        tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      );
      count++;
    }
    return count;
  }

  Future<int> _importSummaries(List<dynamic> summariesJson) async {
    int count = 0;
    for (final item in summariesJson) {
      final map = item as Map<String, dynamic>;
      final typeStr = map['type'] as String? ?? 'weekly';
      final type = SummaryType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => SummaryType.weekly,
      );
      final startDate = DateTime.parse(map['start_date'] as String);
      final endDate = DateTime.parse(map['end_date'] as String);

      // 检查是否已存在相同类型和时间范围的总结
      final existing = await _summaryRepository.getSummaryByTypeAndDate(
        type,
        startDate,
        endDate,
      );
      if (existing != null) continue;

      await _summaryRepository.addSummary(
        type: type,
        startDate: startDate,
        endDate: endDate,
        content: map['content'] as String? ?? '',
        sourceIds: (map['source_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      );
      count++;
    }
    return count;
  }

  Future<void> _restoreConfig(
    Map<String, dynamic> config,
    Archive archive,
  ) async {
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
