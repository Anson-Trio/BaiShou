import 'dart:io';

import 'package:baishou/features/index/data/shadow_index_database.dart';
import 'package:baishou/features/storage/domain/services/journal_file_service.dart';
import 'package:baishou/core/storage/vault_service.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shadow_index_sync_service.g.dart';

/// 影子同步器 (Shadow Index Sync Service)
/// 负责扫描并建立/更新物理文件夹和 SQLite 数据之间的一致性
@Riverpod(keepAlive: true)
class ShadowIndexSyncService extends _$ShadowIndexSyncService {
  @override
  FutureOr<void> build() {
    // 【疑问解答】：为什么 build 里只有注释？
    // 1. 在 Riverpod 的 Notifier 中，build 方法主要用于“初始化状态”。
    // 2. 对于像同步器这种“纯触发型”的服务，它本身不需要持有一个持续变化的状态流。
    // 3. 我们声明 build 为 FutureOr<void>，是为了让 Riverpod 知道这是一个单例式的 Provider，
    //    它的真正逻辑体现在下面的异步方法（如 syncJournal）中。
  }

  /// 计算文件的 Hash 用以后续对比是否有脏数据
  Future<String> _computeFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 触发单条目标日记的强同步 (通常在 UI 执行 Save 操作后被调用)
  Future<void> syncJournal(DateTime date) async {
    final journalService = ref.read(journalFileServiceProvider.notifier);
    final dbService = ref.read(shadowIndexDatabaseProvider.notifier);

    final diary = await journalService.readJournal(date);
    if (diary == null) {
      // 如果文件不存在，可能是删除了
      return;
    }

    // 重新获取一下那个真实的文件句柄，由于写锁在这个上下文无法暴露，此处假设 readJournal 反推出其安全路径
    final mockHash = md5.convert(diary.content.codeUnits).toString();

    await dbService.upsertJournalIndex(
      id: diary.id,
      filePath: date.toIso8601String(),

      // ==========================================
      // 【疑问解答】：为什么这里是 ISO8601 而不是 UTF8？
      // ==========================================
      // 1. 概念层级不同：UTF8 是“序列化方案”（把字符变字节），而 ISO8601 是“内容格式”（一种标准时间字符串）。
      // 2. 数据库友好：SQLite 虽然不直接支持 DateTime 类型，但 ISO8601 字符串是文本可比、可排序的，
      //    方便我们执行 `ORDER BY createdAt` 这种 SQL 查询。
      // 3. 跨端一致性：ISO8601 是国际标准 (yyyy-MM-ddTHH:mm:ss)，无论在哪个时区解析都能保持一致。
      date: diary.date.toIso8601String(),
      createdAt: diary.createdAt.toIso8601String(),
      updatedAt: diary.updatedAt.toIso8601String(),

      contentHash: mockHash,
      weather: diary.weather,
      mood: diary.mood,
      location: diary.location,
      locationDetail: diary.locationDetail,
      isFavorite: diary.isFavorite,
      hasMedia: diary.mediaPaths.isNotEmpty,
      rawContent: diary.content,
      tags: diary.tags.join(','),
    );
  }

  /// 全量空间扫描
  ///
  /// 这是“影子索引”架构的兜底同步机制：
  /// 当用户更换设备拷入文件、或者数据库意外损坏时，
  /// 该方法会递归物理磁盘，将所有 Markdown 文件重新解析并强行对齐到 SQLite 中。
  Future<void> fullScanVault() async {
    final activeVault = await ref.read(vaultServiceProvider.future);
    if (activeVault == null) return;

    final journalsDir = Directory(p.join(activeVault.path, 'Journals'));
    if (!journalsDir.existsSync()) return;

    // 1. 获取所有待同步的物理文件列表
    // 匹配 yyyy-MM-dd.md 格式
    final dateFileRegex = RegExp(r'^(\d{4}-\d{2}-\d{2})\.md$');
    final List<File> targetFiles = [];

    await for (final entity in journalsDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        if (dateFileRegex.hasMatch(fileName)) {
          targetFiles.add(entity);
        }
      }
    }

    // 2. 串行（或分批）执行同步
    // 此处选择串行以保证 SQLite 写入时序的稳定性，且减少 IO 并发压力
    for (final file in targetFiles) {
      try {
        final fileName = p.basename(file.path);
        final dateStr = dateFileRegex.firstMatch(fileName)?.group(1);
        if (dateStr != null) {
          final date = DateTime.parse(dateStr);
          await syncJournal(date);
        }
      } catch (e) {
        // 单个文件同步失败不应阻断整个扫描流程
        continue;
      }
    }
  }
}
