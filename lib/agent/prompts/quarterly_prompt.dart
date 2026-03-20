import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart';
import 'package:baishou/agent/prompts/prompt_templates.dart';

String getQuarterlyPrompt(MissingSummary target, {String? customInstructions}) {
  return PromptTemplates.buildQuarterly(
    year: target.startDate.year,
    quarter: (target.startDate.month / 3).ceil(),
    startStr: target.startDate.toString().split(' ')[0],
    endStr: target.endDate.toString().split(' ')[0],
    customInstructions: customInstructions,
  );
}
