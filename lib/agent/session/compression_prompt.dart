/// 会话压缩 Prompt 模板
class CompressionPrompt {
  /// 构建压缩 prompt
  /// [previousSummary] 旧摘要文本（首次压缩时为 null）
  /// [messagesToCompress] 需要压缩的消息文本（已格式化）
  static String build({
    String? previousSummary,
    required String messagesToCompress,
  }) {
    return '''你是一个对话摘要引擎。你的任务是将对话历史压缩为一份结构化摘要，供后续对话使用。

## 规则
1. 保留所有关键事实、决策、结论、用户偏好
2. 保留所有重要的情感表达、关系动态、共同回忆
3. 丢弃寒暄、重复、过渡性语句
4. 如果提供了旧摘要，将旧摘要的内容与新消息合并，生成一份完整的更新版摘要
5. 输出格式使用 Markdown，按主题分段
6. 用第三人称描述（"用户说..."、"伙伴回复..."）

## 旧摘要
${previousSummary ?? "无，这是首次压缩"}

## 需要压缩的新消息
$messagesToCompress

## 请输出更新后的完整摘要：''';
  }

  /// 将 ChatMessage 列表格式化为压缩输入文本
  static String formatMessages(List<dynamic> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final role = msg.role.toString().split('.').last;
      final content = msg.content ?? '';
      if (content.isNotEmpty) {
        buffer.writeln('[$role]: $content');
        buffer.writeln();
      }
    }
    return buffer.toString();
  }
}
