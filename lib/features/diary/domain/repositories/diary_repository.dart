import 'package:baishou/features/diary/domain/entities/diary.dart';

abstract class DiaryRepository {
  // 获取所有日记 (按日期倒序)
  Stream<List<Diary>> watchAllDiaries();

  // 获取单个日记 (用于编辑)
  Future<Diary?> getDiaryById(int id);

  // 保存日记 (新增或更新)
  // 如果 provided id, 则更新; 否则新增
  Future<void> saveDiary({
    int? id,
    required DateTime date,
    required String content,
    List<String> tags = const [],
  });

  // 删除日记
  Future<void> deleteDiary(int id);
  Future<List<Diary>> getDiariesByDateRange(DateTime start, DateTime end);
  
  /// Get all diaries (for analysis)
  Future<List<Diary>> getAllDiaries();
  
  /// Get diaries in range (alias for getDiariesByDateRange but maybe with different sorting if needed)
  Future<List<Diary>> getDiariesInRange(DateTime start, DateTime end);
}
