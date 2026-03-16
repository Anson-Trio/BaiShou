import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/models/tool_definition.dart';
import 'package:baishou/i18n/strings.g.dart';

/// Gemini 专属 AI 客户端
class GeminiClient implements AiClient {
  final AiProviderModel provider;

  GeminiClient({required this.provider});

  String get _baseUrl {
    var url = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://generativelanguage.googleapis.com/v1beta';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // ─── 原有能力：总结生成 ────────────────────────────────────

  @override
  Future<List<String>> fetchAvailableModels() async {
    final List<String> result = [];
    String? pageToken;

    try {
      do {
        var urlStr = '$_baseUrl/models?key=${provider.apiKey}&pageSize=1000';
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
                result.add(
                  model['name'].toString().replaceFirst('models/', ''),
                );
              }
            }
            pageToken = data['nextPageToken'] as String?;
          } else {
            throw Exception(
              t.ai.error_response_format(e: t.ai.error_no_model_list),
            );
          }
        } else {
          throw Exception(
            t.ai.error_api_request(
                    statusCode: response.statusCode.toString()) +
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
      '$_baseUrl/models/$modelId:generateContent?key=${provider.apiKey}',
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
                'maxOutputTokens': 8192,
              },
            }),
          )
          .timeout(const Duration(seconds: 120));

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
          t.ai.error_api_request(
                  statusCode: response.statusCode.toString()) +
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

  // ─── 新增能力：Agent 流式对话 + Tool Calling ─────────────────

  @override
  Stream<StreamEvent> chatStream({
    required List<ChatMessage> messages,
    required String modelId,
    List<ToolDefinition>? tools,
    double? temperature,
  }) async* {
    final uri = Uri.parse(
      '$_baseUrl/models/$modelId:streamGenerateContent?alt=sse&key=${provider.apiKey}',
    );

    final body = <String, dynamic>{
      'contents': _messagesToGemini(messages),
    };

    // System Prompt 单独提取
    final systemMsg = messages.where((m) => m.role == MessageRole.system);
    if (systemMsg.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemMsg.first.content ?? ''},
        ],
      };
    }

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = [
        {
          'functionDeclarations': tools
              .map((t) => {
                    'name': t.name,
                    'description': t.description,
                    'parameters': t.parameterSchema,
                  })
              .toList(),
        },
      ];
    }

    final config = <String, dynamic>{'maxOutputTokens': 8192};
    if (temperature != null) config['temperature'] = temperature;
    body['generationConfig'] = config;

    final request = http.Request('POST', uri)
      ..headers.addAll({..._headers, 'Accept': 'text/event-stream'})
      ..body = jsonEncode(body);

    http.StreamedResponse response;
    try {
      final client = http.Client();
      response = await client.send(request);
    } catch (e, st) {
      yield StreamError(e, st);
      return;
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      yield StreamError(
        Exception('Gemini API Error ${response.statusCode}: $errorBody'),
      );
      return;
    }

    TokenUsage? lastUsage;

    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: '))
        .map((line) => line.substring(6).trim())
        .where((data) => data.isNotEmpty)
        .expand<StreamEvent>((data) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;

        // 解析 usageMetadata（Gemini 在每个 chunk 都可能返回）
        final usage = json['usageMetadata'] as Map<String, dynamic>?;
        if (usage != null) {
          lastUsage = TokenUsage(
            inputTokens: usage['promptTokenCount'] as int? ?? 0,
            outputTokens: usage['candidatesTokenCount'] as int? ?? 0,
            cachedInputTokens: usage['cachedContentTokenCount'] as int?,
          );
        }

        return _parseGeminiChunk(json);
      } catch (e, st) {
        return [StreamError(e, st)];
      }
    });

    yield StreamDone(usage: lastUsage);
  }

  /// 解析 Gemini SSE chunk
  List<StreamEvent> _parseGeminiChunk(Map<String, dynamic> json) {
    final events = <StreamEvent>[];
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return events;

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    if (content == null) return events;

    final parts = content['parts'] as List?;
    if (parts == null) return events;

    for (final part in parts) {
      final partMap = part as Map<String, dynamic>;

      // 文本部分
      if (partMap.containsKey('text')) {
        events.add(TextDelta(partMap['text'] as String));
      }

      // 函数调用部分
      if (partMap.containsKey('functionCall')) {
        final fc = partMap['functionCall'] as Map<String, dynamic>;
        final name = fc['name'] as String;
        final args = fc['args'] as Map<String, dynamic>? ?? {};
        final callId = 'gemini_${name}_${DateTime.now().millisecondsSinceEpoch}';

        events.add(ToolCallStart(callId: callId, toolName: name));
        events.add(ToolCallComplete(ToolCall(
          id: callId,
          name: name,
          arguments: args,
        )));
      }
    }

    return events;
  }

  /// 将 ChatMessage 列表转换为 Gemini contents 格式
  List<Map<String, dynamic>> _messagesToGemini(List<ChatMessage> messages) {
    final contents = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == MessageRole.system) continue; // system 单独处理

      final parts = <Map<String, dynamic>>[];

      switch (msg.role) {
        case MessageRole.user:
          parts.add({'text': msg.content ?? ''});
          contents.add({'role': 'user', 'parts': parts});
          break;

        case MessageRole.assistant:
          if (msg.content != null) {
            parts.add({'text': msg.content!});
          }
          if (msg.toolCalls != null) {
            for (final tc in msg.toolCalls!) {
              parts.add({
                'functionCall': {
                  'name': tc.name,
                  'args': tc.arguments,
                },
              });
            }
          }
          contents.add({'role': 'model', 'parts': parts});
          break;

        case MessageRole.tool:
          contents.add({
            'role': 'user',
            'parts': [
              {
                'functionResponse': {
                  'name': 'tool_result',
                  'response': {'result': msg.content ?? ''},
                },
              },
            ],
          });
          break;

        default:
          break;
      }
    }

    return contents;
  }
}
