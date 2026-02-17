import 'package:baishou/core/database/tables/summaries.dart';

class Summary {
  final int id;
  final SummaryType type;
  final DateTime startDate;
  final DateTime endDate;
  final String content;
  final DateTime generatedAt;
  final List<String> sourceIds;

  const Summary({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.content,
    required this.generatedAt,
    this.sourceIds = const [],
  });
}
