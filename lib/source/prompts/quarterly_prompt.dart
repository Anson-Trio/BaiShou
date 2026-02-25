import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:baishou/source/prompts/prompt_templates.dart';

String getQuarterlyPrompt(MissingSummary target, AppLocale locale) {
  return PromptTemplates.buildQuarterly(
    locale,
    year: target.startDate.year,
    quarter: (target.startDate.month / 3).ceil(),
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
  );
}
