import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:baishou/core/clients/ai_client.dart';
import 'package:baishou/i18n/strings.g.dart';

class GeminiClient implements AiClient {
  final AiProviderModel provider;

  GeminiClient({required this.provider});

  // 获取 baseUrl，支持 Gemini 特有的默认后缀 fallback
  String get _baseUrlStr {
    var url = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://generativelanguage.googleapis.com/v1beta';
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  // Gemini 特有的基于 Query 的鉴权基础请求头 (不带 Authorization)
  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  @override
  Future<List<String>> fetchAvailableModels() async {
    final List<String> result = [];
    String? pageToken;

    try {
      do {
        var urlStr = '$_baseUrlStr/models?key=${provider.apiKey}&pageSize=1000';
        if (pageToken != null && pageToken.isNotEmpty) {
          urlStr += '&pageToken=$pageToken';
        }
        final uri = Uri.parse(urlStr);

        final response = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data.containsKey('models') && data['models'] is List) {
            final List<dynamic> modelsList = data['models'];
            for (var model in modelsList) {
              if (model is Map && model.containsKey('name')) {
                // 剥离 "models/" 前缀
                result.add(
                  model['name'].toString().replaceFirst('models/', ''),
                );
              }
            }
            // nextPageToken 进行分页抓取
            pageToken = data['nextPageToken'] as String?;
          } else {
            throw Exception(
              t.ai.error_response_format(e: t.ai.error_no_model_list),
            );
          }
        } else {
          throw Exception(
            t.ai.error_api_request(statusCode: response.statusCode.toString()) +
                '\n${response.body}',
          );
        }
      } while (pageToken != null && pageToken.isNotEmpty);

      return result;
    } catch (e) {
      throw Exception(t.ai.error_fetch_models(e: e.toString()));
    }
  }

  @override
  Future<String> generateContent({
    required String prompt,
    required String modelId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrlStr/models/$modelId:generateContent?key=${provider.apiKey}',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                // Gemini 支持 tokens 更长
                'maxOutputTokens': 8192,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);

        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text']
              .toString()
              .trim();
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
    // 调用 fetch 可测试其是否能成功解析 models 且无鉴权异常
    await fetchAvailableModels();
  }
}
