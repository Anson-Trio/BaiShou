import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permission_service.g.dart';

/// 权限管理服务
/// 主要处理 Android 的全文件访问权限 (MANAGE_EXTERNAL_STORAGE)
@Riverpod(keepAlive: true)
class PermissionService extends _$PermissionService {
  @override
  void build() {}

  /// 检查是否有存储权限
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 11 (API 30) 及以上需要 MANAGE_EXTERNAL_STORAGE
    // 较低版本通常只需要 STORAGE 权限，但白守推荐使用内部存储或特定的外部根目录
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // 兼容较低版本的存储权限检查
    if (await Permission.storage.isGranted) {
      return true;
    }

    return false;
  }

  /// 请求存储权限
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    debugPrint('PermissionService: Requesting storage permissions...');

    // 优先尝试请求全文件访问权限 (针对自定义路径需求)
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      debugPrint('PermissionService: MANAGE_EXTERNAL_STORAGE granted');
      return true;
    }

    // 兜底尝试普通存储权限
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      debugPrint('PermissionService: STORAGE permission granted');
      return true;
    }

    debugPrint('PermissionService: Permissions denied');
    return false;
  }
}
