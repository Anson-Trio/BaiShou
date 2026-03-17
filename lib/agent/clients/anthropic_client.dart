import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:baishou/agent/clients/base_ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/models/tool_definition.dart';
import 'package:baishou/i18n/strings.g.dart';

/// Anthropic Claude 专属 AI 客户端
class AnthropicClient extends BaseAiClient {
  AnthropicClient({required super.provider});

  @override
  String get baseUrl {
    var url = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.anthropic.com/v1';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  @override
  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'x-api-key': provider.apiKey,
        'anthropic-version': '2023-06-01',
      };

  // ─── 原有能力：总结生成 ────────────────────────────────────

  // ─── 嵌入能力（Anthropic 不支持）─────────────────────────

  @override
  Future<List<double>> generateEmbedding({
    required String input,
    required String modelId,
  }) async {
    throw UnsupportedError(
      'Anthropic does not provide an embedding API. '
      'Please configure an OpenAI-compatible or Gemini provider for embeddings.',
    );
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    final uri = Uri.parse('$baseUrl/models');
    try {
      final response = await http
          .get(uri, headers: headers)
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
          t.ai.error_api_request(
                  statusCode: response.statusCode.toString()) +
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
    final uri = Uri.parse('$baseUrl/messages');
    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'model': modelId,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
              'max_tokens': 4096,
            }),
          )
          .timeout(const Duration(seconds: 120));

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
          t.ai.error_api_request(
                  statusCode: response.statusCode.toString()) +
              '\n${response.body}',
        );
      }
    } catch (e) {
      throw Exception(t.ai.error_generate_interface(e: e.toString()));
    }
  }


  // ─── 新增能力：Agent 流式对话 + Tool Calling ─────────────────

  @override
  Stream<StreamEvent> chatStream({
    required List<ChatMessage> messages,
    required String modelId,
    List<ToolDefinition>? tools,
    double? temperature,
  }) async* {
    final uri = Uri.parse('$baseUrl/messages');

    final body = <String, dynamic>{
      'model': modelId,
      'messages': _messagesToAnthropic(messages),
      'max_tokens': 8192,
      'stream': true,
    };

    // Anthropic system prompt 在顶层而不是消息里
    final systemMsg = messages.where((m) => m.role == MessageRole.system);
    if (systemMsg.isNotEmpty) {
      body['system'] = systemMsg.first.content ?? '';
    }

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools
          .map((t) => {
                'name': t.name,
                'description': t.description,
                'input_schema': t.parameterSchema,
              })
          .toList();
    }
    if (temperature != null) {
      body['temperature'] = temperature;
    }

    final request = http.Request('POST', uri)
      ..headers.addAll({...headers, 'Accept': 'text/event-stream'})
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
        Exception('Anthropic API Error ${response.statusCode}: $errorBody'),
      );
      return;
    }

    // Anthropic SSE 事件解析
    String? currentToolId;
    String? currentToolName;
    final argumentsBuffer = StringBuffer();
    int inputTokens = 0;
    int outputTokens = 0;
    int? cacheReadTokens;

    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: '))
        .map((line) => line.substring(6).trim())
        .where((data) => data.isNotEmpty)
        .expand<StreamEvent>((data) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final type = json['type'] as String?;
        final events = <StreamEvent>[];

        switch (type) {
          case 'message_start':
            // Anthropic 在 message_start 中返回 input tokens
            final msg = json['message'] as Map<String, dynamic>?;
            final usage = msg?['usage'] as Map<String, dynamic>?;
            if (usage != null) {
              inputTokens = usage['input_tokens'] as int? ?? 0;
              cacheReadTokens = usage['cache_read_input_tokens'] as int?;
            }
            break;

          case 'content_block_start':
            final block = json['content_block'] as Map<String, dynamic>?;
            if (block != null && block['type'] == 'tool_use') {
              currentToolId = block['id'] as String;
              currentToolName = block['name'] as String;
              argumentsBuffer.clear();
              events.add(ToolCallStart(
                callId: currentToolId!,
                toolName: currentToolName!,
              ));
            }
            break;

          case 'content_block_delta':
            final delta = json['delta'] as Map<String, dynamic>?;
            if (delta != null) {
              if (delta['type'] == 'text_delta') {
                events.add(TextDelta(delta['text'] as String));
              } else if (delta['type'] == 'input_json_delta') {
                final partial = delta['partial_json'] as String? ?? '';
                argumentsBuffer.write(partial);
                events.add(ToolCallDelta(
                  callId: currentToolId ?? '',
                  argumentsDelta: partial,
                ));
              }
            }
            break;

          case 'content_block_stop':
            if (currentToolId != null && currentToolName != null) {
              Map<String, dynamic> args = {};
              try {
                args = jsonDecode(argumentsBuffer.toString())
                    as Map<String, dynamic>;
              } catch (_) {}
              events.add(ToolCallComplete(ToolCall(
                id: currentToolId!,
                name: currentToolName!,
                arguments: args,
              )));
              currentToolId = null;
              currentToolName = null;
              argumentsBuffer.clear();
            }
            break;

          case 'message_delta':
            // Anthropic 在 message_delta 中返回 output tokens
            final usage = json['usage'] as Map<String, dynamic>?;
            if (usage != null) {
              outputTokens = usage['output_tokens'] as int? ?? 0;
            }
            break;

          case 'message_stop':
            break;
        }

        return events;
      } catch (e, st) {
        return [StreamError(e, st)];
      }
    });

    yield StreamDone(
      usage: TokenUsage(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        cachedInputTokens: cacheReadTokens,
      ),
    );
  }

  /// 将 ChatMessage 列表转换为 Anthropic messages 格式
  List<Map<String, dynamic>> _messagesToAnthropic(List<ChatMessage> messages) {
    final result = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == MessageRole.system) continue; // system 单独处理

      switch (msg.role) {
        case MessageRole.user:
          result.add({'role': 'user', 'content': msg.content ?? ''});
          break;

        case MessageRole.assistant:
          final content = <Map<String, dynamic>>[];
          if (msg.content != null && msg.content!.isNotEmpty) {
            content.add({'type': 'text', 'text': msg.content!});
          }
          if (msg.toolCalls != null) {
            for (final tc in msg.toolCalls!) {
              content.add({
                'type': 'tool_use',
                'id': tc.id,
                'name': tc.name,
                'input': tc.arguments,
              });
            }
          }
          result
              .add({'role': 'assistant', 'content': content});
          break;

        case MessageRole.tool:
          result.add({
            'role': 'user',
            'content': [
              {
                'type': 'tool_result',
                'tool_use_id': msg.toolCallId ?? '',
                'content': msg.content ?? '',
              },
            ],
          });
          break;

        default:
          break;
      }
    }

    return result;
  }
}
