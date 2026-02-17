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

  /// 创建副本并允许修改部分字段
  Summary copyWith({
    int? id,
    SummaryType? type,
    DateTime? startDate,
    DateTime? endDate,
    String? content,
    DateTime? generatedAt,
    List<String>? sourceIds,
  }) {
    return Summary(
      id: id ?? this.id,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      content: content ?? this.content,
      generatedAt: generatedAt ?? this.generatedAt,
      sourceIds: sourceIds ?? this.sourceIds,
    );
  }
}
