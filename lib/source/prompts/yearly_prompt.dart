import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/source/prompts/prompt_templates.dart';

String getYearlyPrompt(MissingSummary target, AppLocale locale) {
  return PromptTemplates.buildYearly(
    locale,
    year: target.startDate.year,
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
  );
}
