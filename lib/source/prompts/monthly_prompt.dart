import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/source/prompts/prompt_templates.dart';

String getMonthlyPrompt(MissingSummary target, AppLocale locale) {
  return PromptTemplates.buildMonthly(
    locale,
    year: target.startDate.year,
    month: target.startDate.month,
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
  );
}
