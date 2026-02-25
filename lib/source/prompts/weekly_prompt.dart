import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/source/prompts/prompt_templates.dart';

String getWeeklyPrompt(MissingSummary target, AppLocale locale) {
  return PromptTemplates.buildWeekly(
    locale,
    year: target.startDate.year,
    month: target.startDate.month,
    week: target.weekNumber ?? 1, // 假设 MissingSummary 有 weekNumber，如果没有则需要计算
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
  );
}
