import 'package:baishou/agent/middleware/message_middleware.dart';

/// Gemini Thought Signature 跳过中间件
///
/// Gemini 2.5/3 模型的 functionCall 响应包含 thoughtSignature 字段，
/// 回传历史时必须原样携带，否则返回 400 错误。
///
/// 本中间件使用 magic string 'skip_thought_signature_validator' 跳过验证，
/// 详见: https://ai.google.dev/gemini-api/docs/thought-signatures
class GeminiThoughtSignatureMiddleware implements MessageMiddleware {
  static const _skipValidator = 'skip_thought_signature_validator';

  @override
  String get name => 'gemini-thought-signature-skip';

  @override
  List<Map<String, dynamic>> process(List<Map<String, dynamic>> contents) {
    for (final content in contents) {
      final role = content['role'] as String?;
      if (role != 'model') continue;

      final parts = content['parts'] as List?;
      if (parts == null) continue;

      var isFirstFunctionCall = true;
      for (final part in parts) {
        if (part is Map<String, dynamic> && part.containsKey('functionCall')) {
          // 仅第一个 functionCall 需要 thoughtSignature（并行调用时）
          if (isFirstFunctionCall) {
            part['thoughtSignature'] = _skipValidator;
            isFirstFunctionCall = false;
          }
        }
      }
    }
    return contents;
  }
}
