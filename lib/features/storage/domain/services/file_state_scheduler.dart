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
    await _watchSubscription?.cancel();
    final activeVault = await ref.read(vaultServiceProvider.future);
    if (activeVault == null) return;

    // 关键修复：监听 Vault 根目录而非 Journals 子目录
    // 原因：若监听 Journals 目录，删除 Journals 本身会导致 Watcher 静默失效
    // 监听父级目录，可以捕获 Journals 目录自身的创建/删除事件
    final vaultDir = Directory(activeVault.path);
    if (!vaultDir.existsSync()) return;

    _watchSubscription = vaultDir.watch(recursive: true).listen((event) async {
      final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
      final String sourcePath = event.path;

      // 过滤 .baishou 系统目录下的事件（SQLite WAL/SHM 等内部文件）
      final normalizedSource = sourcePath.replaceAll('\\', '/');
      if (normalizedSource.contains('/.baishou')) return;

      // 日志记录最原生的 Watcher 事件（帮助排错 Windows 回收站行为）
      debugPrint('FileStateScheduler RawEvent: [${event.type}] $sourcePath');

      // 路径已在上方规范化为 normalizedSource
      final isJournalsScope = normalizedSource.contains('/Journals');
      final isJournalsDirItself = normalizedSource.endsWith('/Journals');
      final isArchivesScope = normalizedSource.contains('/Archives');
      final isArchivesDirItself = normalizedSource.endsWith('/Archives');

      // 非 Journals 且非 Archives 范畴内的事件，直接忽略
      if (!isJournalsScope &&
          !isJournalsDirItself &&
          !isArchivesScope &&
          !isArchivesDirItself) {
        return;
      }

      if (sourcePath.endsWith('.md') &&
          (dateFileRegex.hasMatch(p.basename(sourcePath)) || isArchivesScope)) {
        // 普通日记文件或归档总结文件变化：塞进防抖流
        _rawEventSubject.add(sourcePath);
      } else if (!sourcePath.endsWith('.md') &&
          (event.type == FileSystemEvent.delete ||
              event.type == FileSystemEvent.create ||
              event.type == FileSystemEvent.move)) {
        // 核心修复：目录层面的拓扑架构变动（包括：删除、恢复/创建、重命名/移动 整个月份、Journals 或 Archives 根目录）
        // 外部强行改变目录结构时，系统底层不会逐个文件发送事件，此时必须直接进行全量扫描！
        debugPrint(
          'FileStateScheduler: Directory topology change detected at $sourcePath (type: ${event.type}), requesting full scan.',
        );
        _dirDeleteEventController?.add(null);
      }

      // Move 事件：也检查目标路径（处理同 Vault 内的重命名）
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
    });

    debugPrint(
      'FileStateScheduler: Started watching vault root: ${vaultDir.path}',
    );
  }
}
