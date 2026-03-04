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
      if (next.value != null && next.value?.name != previous?.value?.name) {
        startWatchingVault();
      }
    });

    ref.onDispose(() {
      _watchSubscription?.cancel();
      _debouncedSubscription?.cancel();
      _rawEventSubject.close();
      _cleanEventController?.close();
    });

    // 启动即拉起 Watcher
    startWatchingVault();
  }

  /// 暴露给下一层（同步器或 UI）的纯净文件变动流
  Stream<String> get cleanFileEvents {
    _cleanEventController ??= StreamController<String>.broadcast();
    return _cleanEventController!.stream;
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

    final journalsDir = Directory(p.join(activeVault.path, 'Journals'));
    if (!journalsDir.existsSync()) return;

    _watchSubscription = journalsDir.watch(recursive: true).listen((
      event,
    ) async {
      // 核心修复：Move 事件中，目标路径在 destination 属性里
      final String path = (event is FileSystemMoveEvent)
          ? (event.destination ?? event.path)
          : event.path;

      if (!path.endsWith('.md')) return;

      // 验证这确实是合法格式的日记文件 (YYYY-MM-DD.md)
      final fileName = p.basename(path);
      final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
      if (!dateFileRegex.hasMatch(fileName)) return;

      if (event.type == FileSystemEvent.delete ||
          event.type == FileSystemEvent.modify ||
          event.type == FileSystemEvent.create ||
          event.type == FileSystemEvent.move) {
        // Windows 可能会有一瞬间连发好几个这样的事件（甚至由于系统缓存，Move 后可能还会再发个 Modify）
        // 这里只是无脑把路径塞进 Subject，剩下的交由 debounce 管道去过滤
        _rawEventSubject.add(path);
      }
    });

    debugPrint(
      'FileStateScheduler: Started deeply watching directory: ${journalsDir.path}',
    );
  }
}
