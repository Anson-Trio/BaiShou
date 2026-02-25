import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'export_service.g.dart';

@riverpod
class ExportService extends _$ExportService {
  @override
  void build() {}

  /// 将过去 [months] 个月的日记导出为 Markdown
  Future<String> formatPastMonthsToMarkdown(
    int months, {
    String? prefix,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months, now.day);
    return formatDiariesToMarkdown(start: start, end: now, prefix: prefix);
  }

  /// 将指定范围内的日记导出为 Markdown 字符串
  /// [prefix] 为用户自定义的开头寄语
  Future<String> formatDiariesToMarkdown({
    required DateTime start,
    required DateTime end,
    String? prefix,
  }) async {
    final repository = ref.read(diaryRepositoryProvider);
    final diaries = await repository.getDiariesByDateRange(start, end);

    final sb = StringBuffer();

    if (prefix != null && prefix.isNotEmpty) {
      sb.writeln(prefix);
      sb.writeln('\n---\n');
    }

    if (diaries.isEmpty) {
      sb.writeln('> ${t.diary.no_memories_range}');
      return sb.toString();
    }

    final monthFormat = DateFormat(t.diary.export_month_format);
    final dateFormat = DateFormat(t.diary.export_date_format);

    String? currentMonth;

    for (final diary in diaries) {
      final month = monthFormat.format(diary.date);
      if (month != currentMonth) {
        currentMonth = month;
        sb.writeln('# $month\n');
      }

      sb.writeln('## ${dateFormat.format(diary.date)}');
      if (diary.tags.isNotEmpty) {
        sb.writeln(
          '${t.diary.export_label_tags}: ${diary.tags.map((t) => '#$t').join(' ')}',
        );
      }
      sb.writeln('\n${diary.content}\n');
      sb.writeln('---');
    }

    return sb.toString();
  }
}
