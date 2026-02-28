import 'package:freezed_annotation/freezed_annotation.dart';

part 'diary.freezed.dart';
part 'diary.g.dart';

@freezed
sealed class Diary with _$Diary {
  const factory Diary({
    required int id,
    required DateTime date,
    required String content,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    required DateTime updatedAt,
    // [NEW] 扩展元数据字段以支持 YAML
    String? weather,
    String? mood,
    String? location,
    String? locationDetail,
    @Default(false) bool isFavorite,
    @Default([]) List<String> mediaPaths,
  }) = _Diary;

  factory Diary.fromJson(Map<String, dynamic> json) => _$DiaryFromJson(json);
}
