import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/models/tool_definition.dart';
import 'package:baishou/i18n/strings.g.dart';

/// OpenAI 兼容协议的 AI 客户端
/// 覆盖 OpenAI / DeepSeek / Kimi / GLM / Ollama 等所有兼容供应商
class OpenAiClient implements AiClient {
  final AiProviderModel provider;

  OpenAiClient({required this.provider});

  String get _baseUrl {
    var url = provider.baseUrl;
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${provider.apiKey}',
      };

  // ─── 原有能力：总结生成 ────────────────────────────────────

  // ─── 嵌入能力 ────────────────────────────────────────────

  @override
  Future<List<double>> generateEmbedding({
    required String input,
    required String modelId,
  }) async {
    final uri = Uri.parse('$_baseUrl/embeddings');

    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'model': modelId,
              'input': input,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody) as Map<String, dynamic>;
        final dataList = data['data'] as List?;
        if (dataList != null && dataList.isNotEmpty) {
          final embedding = dataList[0]['embedding'] as List;
          return embedding.cast<num>().map((e) => e.toDouble()).toList();
        }
        throw Exception('Embedding response missing data field');
      } else {
        throw Exception(
          'Embedding API Error ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to generate embedding: $e');
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    if (provider.baseUrl.isEmpty) {
      throw Exception(t.ai.error_openai_base_url);
    }

    final uri = Uri.parse('$_baseUrl/models');

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
    final uri = Uri.parse('$_baseUrl/chat/completions');

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
    final uri = Uri.parse('$_baseUrl/chat/completions');

    final body = <String, dynamic>{
      'model': modelId,
      'messages': messages.map(_messageToOpenAi).toList(),
      'stream': true,
      'stream_options': {'include_usage': true},
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools
          .map((t) => {
                'type': 'function',
                'function': {
                  'name': t.name,
                  'description': t.description,
                  'parameters': t.parameterSchema,
                },
              })
          .toList();
    }
    if (temperature != null) {
      body['temperature'] = temperature;
    }

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
        Exception('API Error ${response.statusCode}: $errorBody'),
      );
      return;
    }

    // SSE 流解析
    final toolCallBuffers = <int, _ToolCallBuffer>{};
    TokenUsage? lastUsage;

    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: '))
        .map((line) => line.substring(6).trim())
        .where((data) => data.isNotEmpty && data != '[DONE]')
        .expand<StreamEvent>((data) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;

        // 解析 usage（OpenAI 在最后一个 chunk 中返回）
        final usage = json['usage'] as Map<String, dynamic>?;
        if (usage != null) {
          lastUsage = TokenUsage(
            inputTokens: usage['prompt_tokens'] as int? ?? 0,
            outputTokens: usage['completion_tokens'] as int? ?? 0,
            cachedInputTokens: usage['prompt_tokens_details']?['cached_tokens'] as int?,
            reasoningTokens: usage['completion_tokens_details']?['reasoning_tokens'] as int?,
          );
        }

        return _parseChunk(json, toolCallBuffers);
      } catch (e, st) {
        return [StreamError(e, st)];
      }
    });

    yield StreamDone(usage: lastUsage);
  }

  /// 解析单个 SSE chunk
  List<StreamEvent> _parseChunk(
    Map<String, dynamic> json,
    Map<int, _ToolCallBuffer> toolCallBuffers,
  ) {
    final events = <StreamEvent>[];
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) return events;

    final choice = choices[0] as Map<String, dynamic>;
    final delta = choice['delta'] as Map<String, dynamic>?;
    final finishReason = choice['finish_reason'] as String?;

    if (delta != null) {
      final content = delta['content'] as String?;
      if (content != null && content.isNotEmpty) {
        events.add(TextDelta(content));
      }

      final toolCalls = delta['tool_calls'] as List?;
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          final tcMap = tc as Map<String, dynamic>;
          final index = tcMap['index'] as int? ?? 0;
          final fn = tcMap['function'] as Map<String, dynamic>?;

          if (!toolCallBuffers.containsKey(index)) {
            toolCallBuffers[index] = _ToolCallBuffer(
              id: tcMap['id'] as String? ?? 'call_$index',
            );
          }
          final buffer = toolCallBuffers[index]!;

          if (fn != null) {
            if (fn['name'] != null) {
              buffer.name = fn['name'] as String;
              events.add(ToolCallStart(
                callId: buffer.id,
                toolName: buffer.name!,
              ));
            }
            if (fn['arguments'] != null) {
              final argsDelta = fn['arguments'] as String;
              buffer.argumentsBuffer.write(argsDelta);
              events.add(ToolCallDelta(
                callId: buffer.id,
                argumentsDelta: argsDelta,
              ));
            }
          }
        }
      }
    }

    if (finishReason == 'tool_calls' || finishReason == 'stop') {
      for (final buffer in toolCallBuffers.values) {
        if (buffer.name != null) {
          Map<String, dynamic> args = {};
          try {
            args = jsonDecode(buffer.argumentsBuffer.toString())
                as Map<String, dynamic>;
          } catch (_) {}
          events.add(ToolCallComplete(ToolCall(
            id: buffer.id,
            name: buffer.name!,
            arguments: args,
          )));
        }
      }
      toolCallBuffers.clear();
    }

    return events;
  }

  /// 将 ChatMessage 转换为 OpenAI API 格式
  Map<String, dynamic> _messageToOpenAi(ChatMessage msg) {
    final map = <String, dynamic>{'role': msg.role.name};

    switch (msg.role) {
      case MessageRole.system:
      case MessageRole.user:
        map['content'] = msg.content ?? '';
        break;

      case MessageRole.assistant:
        if (msg.content != null) map['content'] = msg.content;
        if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty) {
          map['tool_calls'] = msg.toolCalls!
              .map((tc) => {
                    'id': tc.id,
                    'type': 'function',
                    'function': {
                      'name': tc.name,
                      'arguments': jsonEncode(tc.arguments),
                    },
                  })
              .toList();
        }
        break;

      case MessageRole.tool:
        map['role'] = 'tool';
        map['content'] = msg.content ?? '';
        map['tool_call_id'] = msg.toolCallId ?? '';
        break;
    }

    return map;
  }
}

/// 工具调用参数缓冲区
class _ToolCallBuffer {
  final String id;
  String? name;
  final StringBuffer argumentsBuffer = StringBuffer();
  _ToolCallBuffer({required this.id});
}
