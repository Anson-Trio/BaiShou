import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/agent/prompts/prompt_templates.dart';

String getMonthlyPrompt(MissingSummary target, {String? customTemplate}) {
  return PromptTemplates.buildMonthly(
    year: target.startDate.year,
    month: target.startDate.month,
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
    customTemplate: customTemplate,
  );
}
