import 'dart:io';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';

part 'file_sync_service.g.dart';

@riverpod
class FileSyncService extends _$FileSyncService {
  @override
  void build() {
    // 可以在这里初始化监听
  }

  /// 获取存储日记的根目录
  Future<Directory> _getDiariesRoot() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final diariesDir = Directory(p.join(docsDir.path, 'BaiShou', 'Diaries'));
    if (!diariesDir.existsSync()) {
      diariesDir.createSync(recursive: true);
    }
    return diariesDir;
  }

  /// 同步单条日记到文件系统
  Future<void> syncDiaryToFile(Diary diary) async {
    try {
      final root = await _getDiariesRoot();
      final yearDir = Directory(p.join(root.path, diary.date.year.toString()));
      if (!yearDir.existsSync()) yearDir.createSync();

      final monthDir = Directory(
        p.join(yearDir.path, diary.date.month.toString().padLeft(2, '0')),
      );
      if (!monthDir.existsSync()) monthDir.createSync();

      final fileName = '${DateFormat('yyyy-MM-dd').format(diary.date)}.md';
      final file = File(p.join(monthDir.path, fileName));

      final content = _formatToMarkdown(diary);
      await file.writeAsString(content);
      debugPrint('FileSyncService: Synced diary to ${file.path}');
    } catch (e) {
      debugPrint('FileSyncService: Failed to sync diary. Error: $e');
    }
  }

  /// 全量导出所有日记到文件系统
  Future<void> syncAllDiaries() async {
    final repository = ref.read(diaryRepositoryProvider);
    final diaries = await repository.getAllDiaries();
    for (final diary in diaries) {
      await syncDiaryToFile(diary);
    }
  }

  String _formatToMarkdown(Diary diary) {
    final sb = StringBuffer();
    sb.writeln('---');
    sb.writeln('id: ${diary.id}');
    sb.writeln('date: ${DateFormat('yyyy-MM-dd').format(diary.date)}');
    sb.writeln('tags: [${diary.tags.join(', ')}]');
    sb.writeln('updated_at: ${diary.updatedAt?.toIso8601String()}');
    sb.writeln('---');
    sb.writeln('\n${diary.content}');
    return sb.toString();
  }
}
