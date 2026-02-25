import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:baishou/core/clients/ai_client.dart';
import 'package:baishou/i18n/strings.g.dart';

class AnthropicClient implements AiClient {
  final AiProviderModel provider;

  AnthropicClient({required this.provider});

  String get _baseUrlStr {
    var url = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.anthropic.com/v1';
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': provider.apiKey,
    'anthropic-version': '2023-06-01',
  };

  @override
  Future<List<String>> fetchAvailableModels() async {
    final uri = Uri.parse('$_baseUrlStr/models');
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('data') && data['data'] is List) {
          final List<dynamic> modelsList = data['data'];
          final List<String> result = [];
          for (var model in modelsList) {
            if (model is Map && model.containsKey('id')) {
              result.add(model['id'].toString());
            }
          }
          return result;
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
    } catch (e) {
      throw Exception(t.ai.error_fetch_models(e: e.toString()));
    }
  }

  @override
  Future<String> generateContent({
    required String prompt,
    required String modelId,
  }) async {
    final uri = Uri.parse('$_baseUrlStr/messages');
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
              'max_tokens': 4096,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        if (data['content'] != null &&
            (data['content'] as List).isNotEmpty &&
            data['content'][0]['text'] != null) {
          return data['content'][0]['text'].toString().trim();
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
    await fetchAvailableModels();
  }
}
