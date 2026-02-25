import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:baishou/core/clients/ai_client.dart';
import 'package:baishou/i18n/strings.g.dart';

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
      throw Exception(t.ai.error_openai_base_url);
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
          throw Exception(
            t.ai.error_response_format(e: t.ai.error_no_model_list),
          );
        }

        final List<String> result = [];
        for (var model in modelsList) {
          if (model is Map && model.containsKey('id')) {
            result.add(model['id'].toString());
          }
        }
        return result;
      } else {
        throw Exception(
          t.ai.error_api_request(statusCode: response.statusCode.toString()) +
              '\n${response.body}',
        );
      }
    } catch (e) {
      throw Exception(t.ai.error_fetch_models(e: e.toString()));
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
          throw Exception(t.ai.error_no_text);
        }
      } else {
        throw Exception(
          t.ai.error_api_request(statusCode: response.statusCode.toString()) +
              '\n${response.body}',
        );
      }
    } catch (e) {
      throw Exception(t.ai.error_generate_interface(e: e.toString()));
    }
  }

  @override
  Future<void> testConnection() async {
    // OpenAI 的连接测试，只需要确认能拉取到模型列表即可
    await fetchAvailableModels();
  }
}
