import 'dart:convert';
import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:http/http.dart' as http;

/// AI 客户端的抽象基类
///
/// 提取三个 Client 的公共模板代码：
/// - URL 规范化（trailing slash 处理）
/// - HTTP POST/GET 快捷方法（含超时、UTF-8 解码、JSON 解析）
/// - testConnection 默认实现
abstract class BaseAiClient implements AiClient {
  final AiProviderModel provider;

  BaseAiClient({required this.provider});

  /// 规范化后的 base URL（去掉尾部斜杠）
  String get baseUrl {
    var url = provider.baseUrl;
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  /// HTTP 请求头（子类可覆写以添加认证头）
  Map<String, String> get headers => {'Content-Type': 'application/json'};

  /// 发送 POST 请求并解析 JSON 响应
  ///
  /// 自动处理：超时、UTF-8 解码、状态码检查、JSON 解析
  Future<Map<String, dynamic>> postJson(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse(url);
    final response = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decodedBody = utf8.decode(response.bodyBytes);
      return jsonDecode(decodedBody) as Map<String, dynamic>;
    } else {
      throw Exception(
        'API Error ${response.statusCode}\n${response.body}',
      );
    }
  }

  /// 发送 GET 请求并解析 JSON 响应
  Future<Map<String, dynamic>> getJson(
    String url, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse(url);
    final response = await http
        .get(uri, headers: headers)
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decodedBody = utf8.decode(response.bodyBytes);
      return jsonDecode(decodedBody) as Map<String, dynamic>;
    } else {
      throw Exception(
        'API Error ${response.statusCode}\n${response.body}',
      );
    }
  }

  /// 发送 SSE 流式请求
  Future<http.StreamedResponse> postStream(
    String url,
    Map<String, dynamic> body,
  ) async {
    final request = http.Request('POST', Uri.parse(url))
      ..headers.addAll({...headers, 'Accept': 'text/event-stream'})
      ..body = jsonEncode(body);

    return http.Client().send(request);
  }

  @override
  Future<void> testConnection() async {
    await fetchAvailableModels();
  }
}
