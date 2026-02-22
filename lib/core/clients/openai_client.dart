import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:baishou/core/clients/ai_client.dart';

class OpenAiClient implements AiClient {
  final AiProviderModel provider;

  OpenAiClient({required this.provider});

  // 获取处理过尾部斜杠的 baseUrl
  String get _baseUrlStr {
    var url = provider.baseUrl;
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  // 通用的鉴权 Header，OpenAI 格式强制要求 Bearer Token
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${provider.apiKey}',
  };

  @override
  Future<List<String>> fetchAvailableModels() async {
    if (provider.baseUrl.isEmpty) {
      throw Exception('OpenAI 标准协议必须填写 API 基础地址。');
    }

    final uri = Uri.parse('$_baseUrlStr/models');

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(decodedBody);

        List<dynamic> modelsList = [];
        if (data is List) {
          modelsList = data;
        } else if (data is Map &&
            data.containsKey('data') &&
            data['data'] is List) {
          modelsList = data['data'];
        } else {
          throw Exception('OpenAI 标准协议响应数据格式错误：未找到模型列表字段。');
        }

        final List<String> result = [];
        for (var model in modelsList) {
          if (model is Map && model.containsKey('id')) {
            result.add(model['id'].toString());
          }
        }
        return result;
      } else {
        throw Exception('HTTP 错误 ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('(${provider.name}) 获取模型列表失败: $e');
    }
  }

  @override
  Future<String> generateContent({
    required String prompt,
    required String modelId,
  }) async {
    final uri = Uri.parse('$_baseUrlStr/chat/completions');

    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'model': modelId,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        // UTF8 解码解决中文乱码问题
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        if (data['choices'] != null &&
            data['choices'].isNotEmpty &&
            data['choices'][0]['message'] != null) {
          return data['choices'][0]['message']['content'].toString().trim();
        } else {
          throw Exception('OpenAI 标准协议格式异常：未找到生成的文本');
        }
      } else {
        throw Exception(
          'API请求失败 (状态码: ${response.statusCode})\n${response.body}',
        );
      }
    } catch (e) {
      throw Exception('调用生成接口失败: $e');
    }
  }

  @override
  Future<void> testConnection() async {
    // OpenAI 的连接测试，只需要确认能拉取到模型列表即可
    await fetchAvailableModels();
  }
}
