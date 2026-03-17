import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:baishou/features/diary/domain/entities/diary_meta.dart';
import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/index/data/shadow_index_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vault_index_notifier.g.dart';

/// VaultIndex —— 全量日记元数据的内存单一数据源
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
  FutureOr<List<DiaryMeta>> build() async {
    // 监听活跃 Vault 的变化
    ref.watch(vaultServiceProvider);

    // 异步初始化：从 SQLite 加载所有元数据
    final metas = await _loadFromDb();

    // 订阅文件 Watcher 事件：只处理外部变化
    final syncService = ref.read(shadowIndexSyncServiceProvider.notifier);
    _syncSubscription?.cancel();
    _syncSubscription = syncService.syncEvents.listen((event) {
      _onExternalChange(event);
    });

    ref.onDispose(() {
      _syncSubscription?.cancel();
    });

    return metas;
  }

  /// 从 SQLite 加载所有元数据
  Future<List<DiaryMeta>> _loadFromDb() async {
    try {
      final dbService = ref.read(shadowIndexDatabaseProvider.notifier);
      final db = dbService.database;
      final rows = db.select('''
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

      debugPrint('VaultIndex: Loaded ${metas.length} entries from DB');
      return metas;
    } catch (e) {
      debugPrint('VaultIndex: Failed to load from DB: $e');
      rethrow;
    }
  }

  /// 接收由 SyncService 传递过来的外部变更事件
  void _onExternalChange(JournalSyncEvent event) {
    debugPrint('VaultIndex: Received external change event for ${event.path}');
    final result = event.result;

    if (result.isChanged) {
      if (result.meta != null) {
        upsert(result.meta!);
        debugPrint('VaultIndex: Memory updated via event for ${event.path}');
      } else {
        // 如果 meta 为 null 且 isChanged 为 true，说明是删除了
        final fileName = p.basename(event.path);
        final dateStr = fileName.replaceAll('.md', '');

        state.whenData((list) {
          final newList = List<DiaryMeta>.from(list);
          // 关键修复：找出所有在该日期下的内存条目 ID
          final idsToRemove = newList
              .where((m) {
                final entryDateStr =
                    "${m.date.year}-${m.date.month.toString().padLeft(2, '0')}-${m.date.day.toString().padLeft(2, '0')}";
                return entryDateStr == dateStr;
              })
              .map((m) => m.id)
              .toSet();

          if (idsToRemove.isNotEmpty) {
            state = AsyncValue.data(
              newList.where((m) => !idsToRemove.contains(m.id)).toList(),
            );
            debugPrint(
              'VaultIndex: Memory removed (${idsToRemove.length} entries) via event for $dateStr',
            );
          }
        });
      }
    } else {
      debugPrint('VaultIndex: Non-diary external change, reloading from DB');
      ref.invalidateSelf();
    }
  }

  // ──────────────────────────────────────────────
  // CRUD 操作（App 内调用，直接更新内存，不触发重载）
  // ──────────────────────────────────────────────

  /// 添加或更新一条日记元数据
  void upsert(DiaryMeta meta) {
    state.whenData((list) {
      final newList = List<DiaryMeta>.from(list);
      final idx = newList.indexWhere((m) => m.id == meta.id);
      if (idx != -1) {
        newList[idx] = meta;
      } else {
        // 找到正确插入位置（date DESC, id DESC）
        final insertAt = newList.indexWhere(
          (m) =>
              m.date.isBefore(meta.date) ||
              (m.date.isAtSameMomentAs(meta.date) && m.id < meta.id),
        );
        if (insertAt == -1) {
          newList.add(meta);
        } else {
          newList.insert(insertAt, meta);
        }
      }
      state = AsyncValue.data(newList);
      debugPrint('VaultIndex: upsert id=${meta.id} date=${meta.date}');
    });
  }

  /// 删除一条日记元数据
  void remove(int id) {
    state.whenData((list) {
      state = AsyncValue.data(list.where((m) => m.id != id).toList());
      debugPrint('VaultIndex: removed id=$id');
    });
  }

  /// 强制从 DB 重新加载
  Future<void> forceReload() => _loadFromDb().then((metas) {
    state = AsyncValue.data(metas);
  });

  /// 清空内存中的所有日记元数据
  void clear() {
    state = const AsyncValue.data([]);
    debugPrint('VaultIndex: Memory cleared');
  }
}
