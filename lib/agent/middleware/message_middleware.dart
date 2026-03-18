/// 消息中间件抽象接口
///
/// 中间件作用在 [消息列表 → API 请求体] 的转换阶段，
/// 对已构建好的 provider-specific contents 列表做后处理。
abstract class MessageMiddleware {
  /// 中间件名称（用于调试日志）
  String get name;

  /// 处理已构建好的请求体 contents 列表
  ///
  /// [contents] 是各 Client 的 `_messagesToXxx()` 输出（provider 特定格式）
  /// 返回处理后的 contents
  List<Map<String, dynamic>> process(List<Map<String, dynamic>> contents);
}

/// 中间件链 — 按顺序执行多个中间件
class MiddlewareChain {
  final List<MessageMiddleware> _middlewares;

  const MiddlewareChain(this._middlewares);

  /// 依次执行所有中间件
  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> contents) {
    var result = contents;
    for (final mw in _middlewares) {
      result = mw.process(result);
    }
    return result;
  }

  bool get isEmpty => _middlewares.isEmpty;
}
