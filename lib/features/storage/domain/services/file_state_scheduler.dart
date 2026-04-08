import 'dart:async';
import 'dart:io';

import 'package:baishou/core/storage/vault_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'file_state_scheduler.g.dart';

/// 纯粹的外部文件状态指挥官
/// 专职负责：系统级的 Watcher、防抖 (Debounce)、去重，以及过滤内部保存事件 (Suppress)
@Riverpod(keepAlive: true)
class FileStateScheduler extends _$FileStateScheduler {
  StreamSubscription<FileSystemEvent>? _watchSubscription;
  bool _isStarting = false; // 防止并发调用 startWatchingVault

  // 内部写入红绿灯 (屏蔽名单)：[绝对路径] -> [屏蔽截止时间]
  final Map<String, DateTime> _suppressedPaths = {};

  // 用一个 Subject 来收集所有原始的、乱七八糟的底层系统事件
  final _rawEventSubject = PublishSubject<String>();
  StreamSubscription<String>? _debouncedSubscription;

  // 这是清洗过后的、对外暴露的、纯净的同步指令流
  StreamController<String>? _cleanEventController;

  // 目录删除事件流：用于通知上层执行全量扫描（删整个月份文件夹时触发）
  StreamController<void>? _dirDeleteEventController;

  @override
  FutureOr<void> build() async {
    // 设置防抖流，过滤同一文件在 200ms 内的连续变动（如移动+修改+创建）
    _debouncedSubscription = _rawEventSubject.stream
        // 以文件路径为分组
        .groupBy((path) => path)
        .flatMap((groupStream) {
          // 每个文件路径，合并 200ms 内的所有事件脉冲，只输出最后一次
          return groupStream.debounceTime(const Duration(milliseconds: 200));
        })
        .listen(_processCleanPath);

    // 监听 vault 变化重新绑定 watcher
    ref.listen(vaultServiceProvider, (previous, next) {
      if (next.value != null &&
          (next.value?.name != previous?.value?.name ||
              next.value?.path != previous?.value?.path)) {
        startWatchingVault();
      }
    });

    ref.onDispose(() {
      _watchSubscription?.cancel();
      _debouncedSubscription?.cancel();
      _rawEventSubject.close();
      _cleanEventController?.close();
      _dirDeleteEventController?.close();
    });

    // 启动即拉起 Watcher
    startWatchingVault();
  }

  /// 暴露给下一层（同步器或 UI）的纯净文件变动流
  Stream<String> get cleanFileEvents {
    _cleanEventController ??= StreamController<String>.broadcast();
    return _cleanEventController!.stream;
  }

  /// 目录删除事件流：当整个目录被删除时发出通知，供上层做全量扫描
  Stream<void> get dirDeleteEvents {
    _dirDeleteEventController ??= StreamController<void>.broadcast();
    return _dirDeleteEventController!.stream;
  }

  /// 注册一个 "suppress" 时间窗口：在此时间内忽略该路径产生的所有 Watcher 事件（用于内部 Save）
  void suppressPath(
    String path, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _suppressedPaths[path] = DateTime.now().add(duration);
    debugPrint('FileStateScheduler: Supressed internal write for 2s: $path');
  }

  /// 处理经过防抖后的文件路径
  void _processCleanPath(String changedPath) {
    // 检查这个路径此刻是不是处于“红灯”状态（我们 App 刚刚写入的，不要去反应）
    final now = DateTime.now();
    final expiry = _suppressedPaths[changedPath];

    if (expiry != null && expiry.isAfter(now)) {
      debugPrint(
        'FileStateScheduler: Ignored internal event (Suppressed) for $changedPath',
      );
      return; // 依然是红灯，直接抛弃
    }

    // 清理掉过期名单，防止内存泄露
    _suppressedPaths.removeWhere((k, v) => v.isBefore(now));

    // 这是一个真实的、需要处理的外部变动，通知下游干活
    debugPrint(
      'FileStateScheduler: Emitting clean external change: $changedPath',
    );
    _cleanEventController?.add(changedPath);
  }

  /// 启动底层的神经元触手 (Directory Watcher)
  Future<void> startWatchingVault() async {
    // 防止并发重入：build() 和 ref.listen 几乎同时触发时，
    // 第一个 cancel 还没完成第二个就 watch，导致 Android assertion 失败
    if (_isStarting) return;
    _isStarting = true;

    try {
      await _watchSubscription?.cancel();
      _watchSubscription = null;
      final activeVault = await ref.read(vaultServiceProvider.future);
      if (activeVault == null) return;

      // 监听 Vault 根目录而非 Journals 子目录
      final vaultDir = Directory(activeVault.path);
      if (!vaultDir.existsSync()) return;

      final stream = vaultDir.watch(recursive: true);
      _watchSubscription = stream
          .listen(
            (event) async {
              final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
              final String sourcePath = event.path;

              // 过滤 .baishou 系统目录下的事件（SQLite WAL/SHM 等内部文件）
              final normalizedSource = sourcePath.replaceAll('\\', '/');
              if (normalizedSource.contains('/.baishou')) return;

              debugPrint(
                'FileStateScheduler RawEvent: [${event.type}] $sourcePath',
              );

              final isJournalsScope = normalizedSource.contains('/Journals');
              final isJournalsDirItself = normalizedSource.endsWith(
                '/Journals',
              );
              final isArchivesScope = normalizedSource.contains('/Archives');
              final isArchivesDirItself = normalizedSource.endsWith(
                '/Archives',
              );

              if (!isJournalsScope &&
                  !isJournalsDirItself &&
                  !isArchivesScope &&
                  !isArchivesDirItself) {
                return;
              }

              if (sourcePath.endsWith('.md') &&
                  (dateFileRegex.hasMatch(p.basename(sourcePath)) ||
                      isArchivesScope)) {
                _rawEventSubject.add(sourcePath);
              } else if (!sourcePath.endsWith('.md') &&
                  (event.type == FileSystemEvent.delete ||
                      event.type == FileSystemEvent.move)) {
                // 注意：CREATE 类型的目录事件（如新建空文件夹）不触发全量扫描。
                // 新增的 .md 文件会由 cleanFileEvents 自动捕获，无需全量。
                // 只有 delete/move（可能导致孤立索引）才需要执行全量清理。
                debugPrint(
                  'FileStateScheduler: Directory topology change detected at $sourcePath (type: ${event.type}), requesting full scan.',
                );
                _dirDeleteEventController?.add(null);
              }

              if (event is FileSystemMoveEvent && event.destination != null) {
                final String destPath = event.destination!;
                final normalizedDest = destPath.replaceAll('\\', '/');

                if ((normalizedDest.contains('/Journals') ||
                        normalizedDest.contains('/Archives')) &&
                    destPath.endsWith('.md') &&
                    (dateFileRegex.hasMatch(p.basename(destPath)) ||
                        normalizedDest.contains('/Archives'))) {
                  _rawEventSubject.add(destPath);
                }
              }
            },
            onError: (e) {
              debugPrint('FileStateScheduler: Watcher stream error: $e');
            },
          );

      debugPrint(
        'FileStateScheduler: Started watching vault root: ${vaultDir.path}',
      );
    } catch (e) {
      debugPrint(
        'FileStateScheduler: Failed to start file watcher (degraded mode): $e',
      );
    } finally {
      _isStarting = false;
    }
  }
}
