import 'package:baishou/features/diary/domain/entities/diary.dart';

abstract class DiaryRepository {
  // 获取所有日记 (按日期倒序)
  Stream<List<Diary>> watchAllDiaries();

  // 获取单个日记 (用于编辑)
  Future<Diary?> getDiaryById(int id);

  // 保存日记 (新增或更新)
  // 如果提供了 id，则更新；否则新增
  Future<void> saveDiary({
    int? id,
    required DateTime date,
    required String content,
    List<String> tags = const [],
  });

  /// 批量保存日记
  Future<void> batchSaveDiaries(List<Diary> diaries);

  /// 清空所有日记
  Future<void> deleteAllDiaries();

  // 删除日记
  Future<void> deleteDiary(int id);
  Future<List<Diary>> getDiariesByDateRange(DateTime start, DateTime end);

  /// 获取所有日记（用于分析）
  Future<List<Diary>> getAllDiaries();

  /// 获取指定日期范围内的日记
  Future<List<Diary>> getDiariesInRange(DateTime start, DateTime end);
}
