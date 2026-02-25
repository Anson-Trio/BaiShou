import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:baishou/i18n/strings.g.dart';

part 'raw_data_exporter.g.dart';

class RawDataExporter {
  final DiaryRepository _diaryRepository;

  RawDataExporter(this._diaryRepository);

  Future<String> exportRawData(DateTime start, DateTime end) async {
    final diaries = await _diaryRepository.getDiariesByDateRange(start, end);
    final buffer = StringBuffer();

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm');

    buffer.writeln(t.ai_prompt.raw_data_export_title);
    buffer.writeln(
      t.ai_prompt.export_range(
        start: dateFormat.format(start),
        end: dateFormat.format(end),
      ),
    );
    buffer.writeln(
      t.ai_prompt.total_diaries_count(count: diaries.length.toString()),
    );
    buffer.writeln();

    for (final diary in diaries) {
      final dateStr = dateFormat.format(diary.date);
      final weekDay = DateFormat(
        'EEEE',
        LocaleSettings.currentLocale.languageCode,
      ).format(diary.date);
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
