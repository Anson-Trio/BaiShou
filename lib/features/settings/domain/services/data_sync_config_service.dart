import 'package:baishou/core/providers/shared_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncTarget { local, s3, webdav }

/// 数据同步配置服务
/// 负责管理同步目标的持久化存储（Local, S3, WebDAV）及其对应的凭据。
class DataSyncConfigService {
  final SharedPreferences _prefs;

  // 配置键名
  static const String _keySyncTarget = 'sync_target';

  // S3 配置项键名
  static const String _keyS3Endpoint = 's3_endpoint';
  static const String _keyS3Region = 's3_region';
  static const String _keyS3Bucket = 's3_bucket';
  static const String _keyS3Path = 's3_path';
  static const String _keyS3AccessKey = 's3_access_key';
  static const String _keyS3SecretKey = 's3_secret_key';

  // WebDAV 配置项键名
  static const String _keyWebdavUrl = 'webdav_url';
  static const String _keyWebdavUsername = 'webdav_username';
  static const String _keyWebdavPassword = 'webdav_password';
  static const String _keyWebdavPath = 'webdav_path';

  DataSyncConfigService(this._prefs);

  // --- 同步目标管理 ---

  /// 获取当前设定的同步目标
  SyncTarget get syncTarget {
    final index = _prefs.getInt(_keySyncTarget) ?? 0;
    if (index >= 0 && index < SyncTarget.values.length) {
      return SyncTarget.values[index];
    }
    return SyncTarget.local;
  }

  /// 切换同步目标
  Future<void> setSyncTarget(SyncTarget target) async {
    await _prefs.setInt(_keySyncTarget, target.index);
  }

  // --- S3 配置管理 ---

  String get s3Endpoint => _prefs.getString(_keyS3Endpoint) ?? 'https://';
  String get s3Region => _prefs.getString(_keyS3Region) ?? '';
  String get s3Bucket => _prefs.getString(_keyS3Bucket) ?? '';
  String get s3Path => _prefs.getString(_keyS3Path) ?? '/baishou_backup';
  String get s3AccessKey => _prefs.getString(_keyS3AccessKey) ?? '';
  String get s3SecretKey => _prefs.getString(_keyS3SecretKey) ?? '';

  /// 保存 S3 相关的各项配置
  Future<void> saveS3Config({
    required String endpoint,
    required String region,
    required String bucket,
    required String path,
    required String accessKey,
    required String secretKey,
  }) async {
    await _prefs.setString(_keyS3Endpoint, endpoint);
    await _prefs.setString(_keyS3Region, region);
    await _prefs.setString(_keyS3Bucket, bucket);
    await _prefs.setString(_keyS3Path, path);
    await _prefs.setString(_keyS3AccessKey, accessKey);
    await _prefs.setString(_keyS3SecretKey, secretKey);
  }

  // --- WebDAV 配置管理 ---

  String get webdavUrl => _prefs.getString(_keyWebdavUrl) ?? 'https://';
  String get webdavUsername => _prefs.getString(_keyWebdavUsername) ?? '';
  String get webdavPassword => _prefs.getString(_keyWebdavPassword) ?? '';
  String get webdavPath =>
      _prefs.getString(_keyWebdavPath) ?? '/baishou_backup';

  /// 保存 WebDAV 相关的各项配置
  Future<void> saveWebdavConfig({
    required String url,
    required String username,
    required String password,
    required String path,
  }) async {
    await _prefs.setString(_keyWebdavUrl, url);
    await _prefs.setString(_keyWebdavUsername, username);
    await _prefs.setString(_keyWebdavPassword, password);
    await _prefs.setString(_keyWebdavPath, path);
  }
}

final dataSyncConfigServiceProvider = Provider<DataSyncConfigService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DataSyncConfigService(prefs);
});
