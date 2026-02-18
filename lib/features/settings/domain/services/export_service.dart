import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:baishou/features/diary/domain/entities/diary.dart';

import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  final DiaryRepository _diaryRepository;

  ExportService(this._diaryRepository);

  // 导出为 ZIP 压缩包 (按日期分类 Markdown)
  // share: 是否调用系统分享 (默认 true，局域网传输时应设为 false)
  Future<File?> exportToZip({bool share = true}) async {
    final diaries = await _diaryRepository.getAllDiaries();
    // Sort by date descending
    final archive = Archive();

    // 按日期分组日记
    final Map<String, List<Diary>> grouped = {};
    for (final diary in diaries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(diary.date);
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(diary);
    }

    // 为每一天生成 Markdown 内容
    for (final entry in grouped.entries) {
      final dateStr = entry.key;
      final dailyDiaries = entry.value;

      final sb = StringBuffer();
      sb.writeln('# $dateStr');
      sb.writeln();

      for (final diary in dailyDiaries) {
        sb.writeln('## ${DateFormat('HH:mm').format(diary.date)}');
        if (diary.tags.isNotEmpty) {
          sb.writeln('标签: ${diary.tags.join(', ')}');
        }
        sb.writeln();
        sb.writeln(diary.content);
        sb.writeln();
        sb.writeln('---');
        sb.writeln();
      }

      final bytes = utf8.encode(sb.toString());
      archive.addFile(ArchiveFile('$dateStr.md', bytes.length, bytes));
    }

    // 编码为 ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    final fileName =
        'BaiShou_Backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip';

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(zipData);

      if (share) {
        await Share.shareXFiles([XFile(file.path)], text: '白守数据备份');
      }
      return file;
    } else {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: fileName,
        allowedExtensions: ['zip'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(zipData);
        return file;
      } else {
        return null; // User cancelled
      }
    }
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  final diaryRepository = ref.watch(diaryRepositoryProvider);
  return ExportService(diaryRepository);
});
