import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/agent/prompts/prompt_templates.dart';

String getWeeklyPrompt(MissingSummary target, {String? customInstructions}) {
  return PromptTemplates.buildWeekly(
    year: target.startDate.year,
    month: target.startDate.month,
    week: target.weekNumber ?? 1,
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
    customInstructions: customInstructions,
  );
}
