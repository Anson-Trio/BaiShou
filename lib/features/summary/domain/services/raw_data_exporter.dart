import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'raw_data_exporter.g.dart';

class RawDataExporter {
  final DiaryRepository _diaryRepository;

  RawDataExporter(this._diaryRepository);

  Future<String> exportRawData(DateTime start, DateTime end) async {
    final diaries = await _diaryRepository.getDiariesByDateRange(start, end);
    final buffer = StringBuffer();

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    buffer.writeln('# 原始数据导出');
    buffer.writeln(
      '范围: ${dateFormat.format(start)} ~ ${dateFormat.format(end)}',
    );
    buffer.writeln('总计: ${diaries.length} 篇日记');
    buffer.writeln();

    for (final diary in diaries) {
      final dateStr = dateFormat.format(diary.date);
      final weekDay = DateFormat('EEEE', 'zh_CN').format(diary.date);
      final timeStr = timeFormat.format(diary.date);

      buffer.writeln('## $dateStr ($weekDay) $timeStr');
      if (diary.tags.isNotEmpty) {
        buffer.writeln('Tags: ${diary.tags.map((e) => '#$e').join(' ')}');
      }
      buffer.writeln();
      buffer.writeln(diary.content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }
}

@Riverpod(keepAlive: true)
RawDataExporter rawDataExporter(Ref ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  return RawDataExporter(diaryRepo);
}
