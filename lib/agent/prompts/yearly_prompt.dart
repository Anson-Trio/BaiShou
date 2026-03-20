import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/agent/prompts/prompt_templates.dart';

String getYearlyPrompt(MissingSummary target, {String? customInstructions}) {
  return PromptTemplates.buildYearly(
    year: target.startDate.year,
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
    customInstructions: customInstructions,
  );
}
