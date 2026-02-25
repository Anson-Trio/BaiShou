import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/settings/domain/services/data_sync_config_service.dart';
import 'package:baishou/core/theme/theme_service.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Summary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 备份包 schema 版本，每次修改格式时递增
const int _kSchemaVersion = 1;

/// 数据导出服务
/// 负责将日记、总结以及用户配置打包成 ZIP 备份，支持 MD 与 JSON 双格式导出。
class ExportService {
  final DiaryRepository _diaryRepository;
  final SummaryRepository _summaryRepository;
  final ApiConfigService _apiConfig;
  final DataSyncConfigService _dataSyncConfig;
  final UserProfile _userProfile;
  final AppThemeState _themeState;

  ExportService({
    required DiaryRepository diaryRepository,
    required SummaryRepository summaryRepository,
    required ApiConfigService apiConfig,
    required DataSyncConfigService dataSyncConfig,
    required UserProfile userProfile,
    required AppThemeState themeState,
  }) : _diaryRepository = diaryRepository,
       _summaryRepository = summaryRepository,
       _apiConfig = apiConfig,
       _dataSyncConfig = dataSyncConfig,
       _userProfile = userProfile,
       _themeState = themeState;

  /// 导出完整备份 ZIP
  /// [share] 是否调用系统分享（局域网传输时设为 false）
  Future<File?> exportToZip({bool share = true}) async {
    final archive = Archive();
    final now = DateTime.now();

    // 1. 获取所有数据
    final diaries = await _diaryRepository.getAllDiaries();
    final summaries = await _summaryRepository.getSummaries();
    final packageInfo = await PackageInfo.fromPlatform();

    // 2. 写入 manifest.json
    final manifest = {
      'schema_version': _kSchemaVersion,
      'app_version': packageInfo.version,
      'exported_at': now.toIso8601String(),
      'device_nickname': _userProfile.nickname,
      'counts': {'diaries': diaries.length, 'summaries': summaries.length},
    };
    _addJsonFile(archive, 'manifest.json', manifest);

    // 3. 写入 data/diaries.json
    final diariesJson = diaries.map((d) => _diaryToJson(d)).toList();
    _addJsonFile(archive, 'data/diaries.json', diariesJson);

    // 4. 写入 data/summaries.json
    final summariesJson = summaries.map((s) => _summaryToJson(s)).toList();
    _addJsonFile(archive, 'data/summaries.json', summariesJson);

    // 5. 写入 config/user_profile.json（含 API Key）
    final config = {
      'nickname': _userProfile.nickname,
      'theme_mode': _themeState.mode.index,
      'seed_color': _themeState.seedColor.toARGB32(),
      // AI 新架构配置
      'ai_providers_list': _apiConfig
          .getProviders()
          .map((p) => p.toMap())
          .toList(),
      'global_dialogue_provider_id': _apiConfig.globalDialogueProviderId,
      'global_dialogue_model_id': _apiConfig.globalDialogueModelId,
      'global_naming_provider_id': _apiConfig.globalNamingProviderId,
      'global_naming_model_id': _apiConfig.globalNamingModelId,
      'global_summary_provider_id': _apiConfig.globalSummaryProviderId,
      'global_summary_model_id': _apiConfig.globalSummaryModelId,
      // 保留旧字段以便向下兼容
      'ai_provider': _apiConfig.activeProviderId,
      'ai_model': _apiConfig.getActiveProvider()?.defaultDialogueModel ?? '',
      'ai_naming_model':
          _apiConfig.getActiveProvider()?.defaultNamingModel ?? '',
      'api_key': _apiConfig.getActiveProvider()?.apiKey ?? '',
      'base_url': _apiConfig.getActiveProvider()?.baseUrl ?? '',

      // 数据同步服务配置 (WebDAV, S3 等)
      'sync_target': _dataSyncConfig.syncTarget.index,
      'webdav_url': _dataSyncConfig.webdavUrl,
      'webdav_username': _dataSyncConfig.webdavUsername,
      'webdav_password': _dataSyncConfig.webdavPassword,
      'webdav_path': _dataSyncConfig.webdavPath,
      's3_endpoint': _dataSyncConfig.s3Endpoint,
      's3_access_key': _dataSyncConfig.s3AccessKey,
      's3_secret_key': _dataSyncConfig.s3SecretKey,
      's3_bucket': _dataSyncConfig.s3Bucket,
      's3_region': _dataSyncConfig.s3Region,
      's3_path': _dataSyncConfig.s3Path,
    };

    // 头像：如果存在则以 Base64 编码写入
    if (_userProfile.avatarPath != null) {
      final avatarFile = File(_userProfile.avatarPath!);
      if (avatarFile.existsSync()) {
        final avatarBytes = await avatarFile.readAsBytes();
        final avatarExt = _userProfile.avatarPath!.split('.').last;
        config['avatar_base64'] = base64Encode(avatarBytes);
        config['avatar_ext'] = avatarExt;
      }
    }

    _addJsonFile(archive, 'config/user_profile.json', config);

    // 6. 写入 markdown/ 目录（人类可读版本）
    _addMarkdownFiles(archive, diaries);

    // 7. 编码为 ZIP (移至 Isolate 避免主线程卡死)
    final zipData = await compute(_encodeZip, archive);

    final fileName =
        'BaiShou_Backup_${DateFormat('yyyyMMdd_HHmmss').format(now)}.zip';

    return _saveOrShare(zipData, fileName, share: share);
  }

  /// 在 Isolate 中运行的编码函数
  static List<int> _encodeZip(Archive archive) {
    return ZipEncoder().encode(archive);
  }

  // --- 私有辅助方法 ---

  void _addJsonFile(Archive archive, String path, dynamic data) {
    final bytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  void _addMarkdownFiles(Archive archive, List<Diary> diaries) {
    // 按日期分组
    final Map<String, List<Diary>> grouped = {};
    for (final diary in diaries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(diary.date);
      grouped.putIfAbsent(dateStr, () => []).add(diary);
    }

    for (final entry in grouped.entries) {
      final dateStr = entry.key;
      final dailyDiaries = entry.value;

      final sb = StringBuffer();
      sb.writeln('# $dateStr');
      sb.writeln();

      for (final diary in dailyDiaries) {
        sb.writeln('## ${DateFormat('HH:mm').format(diary.date)}');
        if (diary.tags.isNotEmpty) {
          sb.writeln('${t.diary.tag_label}: ${diary.tags.join(', ')}');
        }
        sb.writeln();
        sb.writeln(diary.content);
        sb.writeln();
        sb.writeln('---');
        sb.writeln();
      }

      final bytes = utf8.encode(sb.toString());
      archive.addFile(ArchiveFile('markdown/$dateStr.md', bytes.length, bytes));
    }
  }

  Map<String, dynamic> _diaryToJson(Diary diary) {
    return {
      'id': diary.id,
      'date': diary.date.toIso8601String(),
      'content': diary.content,
      'tags': diary.tags,
      'created_at': diary.createdAt.toIso8601String(),
      'updated_at': diary.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _summaryToJson(Summary summary) {
    return {
      'id': summary.id,
      'type': summary.type.name,
      'start_date': summary.startDate.toIso8601String(),
      'end_date': summary.endDate.toIso8601String(),
      'content': summary.content,
      'generated_at': summary.generatedAt.toIso8601String(),
      'source_ids': summary.sourceIds,
    };
  }

  Future<File?> _saveOrShare(
    List<int>? zipData,
    String fileName, {
    required bool share,
  }) async {
    if (zipData == null) return null;

    if (share) {
      // share: true 仅用于局域网传输——保存到临时目录后直接返回，不弹任何 UI
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(zipData);
      return file;
    }

    // share: false（用户手动导出）——弹出系统文件保存对话框，与导入体验一致
    // Android/iOS 需要传 bytes 参数，桌面端通过路径写入
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: t.settings.select_save_location,
      fileName: fileName,
      allowedExtensions: ['zip'],
      type: FileType.custom,
      bytes: Uint8List.fromList(zipData), // Android/iOS 必须传 bytes
    );

    if (outputPath != null) {
      final file = File(outputPath);

      // 桌面端：FilePicker 返回路径但不写入，需要手动写入
      // Android/iOS：FilePicker 已通过 bytes 写入，且返回的可能是 SAF URI (如 /document/516)，
      // 无法被 dart:io File 识别，因此跳过写入检查，直接返回
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (!file.existsSync()) {
          await file.writeAsBytes(zipData);
        }
      }
      return file;
    }
    return null; // 用户取消
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    diaryRepository: ref.watch(diaryRepositoryProvider),
    summaryRepository: ref.watch(summaryRepositoryProvider),
    apiConfig: ref.watch(apiConfigServiceProvider),
    dataSyncConfig: ref.watch(dataSyncConfigServiceProvider),
    userProfile: ref.watch(userProfileProvider),
    themeState: ref.watch(themeProvider),
  );
});
