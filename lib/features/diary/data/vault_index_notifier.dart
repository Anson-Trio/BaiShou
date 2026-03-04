import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:baishou/features/diary/domain/entities/diary_meta.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/index/data/shadow_index_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_index_notifier.g.dart';

/// VaultIndex —— 全量日记元数据的内存单一数据源（仿 Obsidian Vault）
///
/// 核心原则：
/// 1. 所有 DiaryMeta 常驻内存（不分页），UI 直接绑定这个列表。
/// 2. App 内 CRUD 操作直接调用 add/update/remove，零延迟刷新 UI。
/// 3. 文件 Watcher 的外部事件（真正的外部删除/修改）才触发重新从 SQLite 加载。
/// 4. 内部写入触发的 Watcher 事件通过"suppress"时间窗口忽略，不重置 UI。
@Riverpod(keepAlive: true)
class VaultIndex extends _$VaultIndex {
  StreamSubscription<JournalSyncEvent>? _syncSubscription;

  @override
  List<DiaryMeta> build() {
    // 异步初始化：从 SQLite 加载所有元数据
    _init();
    return []; // 初始空列表，_init 完成后通过 state = ... 更新
  }

  Future<void> _init() async {
    await _loadFromDb();
    // 订阅文件 Watcher 事件：只处理外部变化
    final syncService = ref.read(shadowIndexSyncServiceProvider.notifier);
    _syncSubscription = syncService.syncEvents.listen((path) {
      _onExternalChange(path);
    });
    ref.onDispose(() {
      _syncSubscription?.cancel();
    });
  }

  /// 从 SQLite 加载所有元数据（仅启动 + 外部文件变化时调用）
  Future<void> _loadFromDb() async {
    try {
      final dbService = ref.read(shadowIndexDatabaseProvider.notifier);
      final db = await dbService.database;
      final rows = await db.rawQuery('''
        SELECT i.id, i.date, i.updated_at, f.content, f.tags
        FROM journals_index i
        LEFT JOIN journals_fts f ON i.id = f.rowid
        ORDER BY i.date DESC, i.id DESC
      ''');

      final metas = rows.map((row) {
        final content = row['content'] as String? ?? '';
        final tagStr = row['tags'] as String?;
        return DiaryMeta(
          id: row['id'] as int,
          date: DateTime.parse(row['date'] as String),
          preview: content.length > 120 ? content.substring(0, 120) : content,
          tags: tagStr != null && tagStr.isNotEmpty
              ? tagStr.split(',').map((t) => t.trim()).toList()
              : [],
          updatedAt: DateTime.parse(row['updated_at'] as String),
        );
      }).toList();

      state = metas;
      debugPrint('VaultIndex: Loaded ${metas.length} entries from DB');
    } catch (e) {
      debugPrint('VaultIndex: Failed to load from DB: $e');
    }
  }

  /// 接收由 SyncService 传递过来的外部变更事件
  /// 此时由于 Scheduler 已经拦截了自身写入产生的回声，这里的事件100%是真正的外部变更
  void _onExternalChange(JournalSyncEvent event) {
    debugPrint('VaultIndex: Received external change event for ${event.path}');
    final result = event.result;

    if (result.isChanged) {
      if (result.meta != null) {
        upsert(result.meta!);
        debugPrint('VaultIndex: Memory updated via event for ${event.path}');
      } else {
        // 如果 meta 为 null 且 isChanged 为 true，说明是删除了
        // 我们从内存中找到对应路径的日记并移除
        final fileName = p.basename(event.path);
        final dateStr = fileName.replaceAll('.md', '');

        final list = List<DiaryMeta>.from(state);
        final idx = list.indexWhere((m) {
          return m.date.toIso8601String().startsWith(dateStr);
        });

        if (idx != -1) {
          remove(list[idx].id);
          debugPrint('VaultIndex: Memory removed via event for $dateStr');
        }
      }
    } else {
      // 如果不是日记文件（可能是注册表或其他），降级为全量重载
      debugPrint('VaultIndex: Non-diary external change, reloading from DB');
      _loadFromDb();
    }
  }

  // ──────────────────────────────────────────────
  // CRUD 操作（App 内调用，直接更新内存，不触发重载）
  // ──────────────────────────────────────────────

  /// 添加或更新一条日记元数据
  void upsert(DiaryMeta meta) {
    final list = List<DiaryMeta>.from(state);
    final idx = list.indexWhere((m) => m.id == meta.id);
    if (idx != -1) {
      list[idx] = meta;
    } else {
      // 找到正确插入位置（date DESC, id DESC）
      final insertAt = list.indexWhere(
        (m) =>
            m.date.isBefore(meta.date) ||
            (m.date.isAtSameMomentAs(meta.date) && m.id < meta.id),
      );
      if (insertAt == -1) {
        list.add(meta);
      } else {
        list.insert(insertAt, meta);
      }
    }
    state = list;
    debugPrint('VaultIndex: upsert id=${meta.id} date=${meta.date}');
  }

  /// 删除一条日记元数据
  void remove(int id) {
    state = state.where((m) => m.id != id).toList();
    debugPrint('VaultIndex: removed id=$id');
  }

  /// 强制从 DB 重新加载（用于开发者选项或调试）
  Future<void> forceReload() => _loadFromDb();
}
