import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:baishou/agent/clients/base_ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/models/tool_definition.dart';
import 'package:baishou/i18n/strings.g.dart';

/// Gemini 专属 AI 客户端
class GeminiClient extends BaseAiClient {
  GeminiClient({required super.provider});

  @override
  String get baseUrl {
    var url = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://generativelanguage.googleapis.com/v1beta';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  // ─── 原有能力：总结生成 ────────────────────────────────────

  // ─── 嵌入能力 ────────────────────────────────────────────

  @override
  Future<List<double>> generateEmbedding({
    required String input,
    required String modelId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/models/$modelId:embedContent?key=${provider.apiKey}',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'content': {
                'parts': [
                  {'text': input},
                ],
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody) as Map<String, dynamic>;
        final embedding = data['embedding'] as Map<String, dynamic>?;
        if (embedding != null) {
          final values = embedding['values'] as List;
          return values.cast<num>().map((e) => e.toDouble()).toList();
        }
        throw Exception('Gemini embedding response missing values');
      } else {
        throw Exception(
          'Gemini Embedding API Error ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to generate embedding: $e');
    }
  }

  @override
  Future<List<String>> fetchAvailableModels() async {
    final List<String> result = [];
    String? pageToken;

    try {
      do {
        var urlStr = '$baseUrl/models?key=${provider.apiKey}&pageSize=1000';
        if (pageToken != null && pageToken.isNotEmpty) {
          urlStr += '&pageToken=$pageToken';
        }
        final uri = Uri.parse(urlStr);

        final response = await http
            .get(uri, headers: headers)
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
      '$baseUrl/models/$modelId:generateContent?key=${provider.apiKey}',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {'maxOutputTokens': 8192},
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
          t.ai.error_api_request(statusCode: response.statusCode.toString()) +
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
    final uri = Uri.parse(
      '$baseUrl/models/$modelId:streamGenerateContent?alt=sse&key=${provider.apiKey}',
    );

    // 构建 Gemini contents 并应用中间件链（如 thought_signature 跳过）
    final contents = middlewareChain.apply(_messagesToGemini(messages));
    final body = <String, dynamic>{'contents': contents};

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
      body['tools'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'functionDeclarations': tools
              .map(
                (t) => <String, dynamic>{
                  'name': t.name,
                  'description': t.description,
                  'parameters': t.parameterSchema,
                },
              )
              .toList(),
        },
      ];
    }


    final config = <String, dynamic>{'maxOutputTokens': 8192};
    if (temperature != null) config['temperature'] = temperature;
    body['generationConfig'] = config;

    final request = http.Request('POST', uri)
      ..headers.addAll({...headers, 'Accept': 'text/event-stream'})
      ..body = jsonEncode(body);

    http.StreamedResponse response;
    try {
      final client = http.Client();
      response = await client.send(request).timeout(const Duration(seconds: 45));
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
        final callId =
            'gemini_${name}_${DateTime.now().millisecondsSinceEpoch}';

        events.add(ToolCallStart(callId: callId, toolName: name));
        events.add(
          ToolCallComplete(ToolCall(id: callId, name: name, arguments: args)),
        );
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
      String role = '';

      switch (msg.role) {
        case MessageRole.user:
          role = 'user';
          parts.add({'text': msg.content ?? ''});
          // 处理附件：图片 → inline_data，PDF → 提取文本
          if (msg.attachments != null) {
            for (final att in msg.attachments!) {
              if (att.isImage) {
                try {
                  final file = File(att.filePath);
                  if (file.existsSync()) {
                    final bytes = file.readAsBytesSync();
                    parts.add({
                      'inline_data': {
                        'mime_type': att.mimeType,
                        'data': base64Encode(bytes),
                      },
                    });
                  }
                } catch (_) {
                  parts.add({'text': '[附件: ${att.fileName} 读取失败]'});
                }
              } else if (att.isPdf) {
                // PDF: 提取文本内容拼接进消息
                try {
                  final file = File(att.filePath);
                  if (file.existsSync()) {
                    final bytes = file.readAsBytesSync();
                    parts.add({
                      'inline_data': {
                        'mime_type': 'application/pdf',
                        'data': base64Encode(bytes),
                      },
                    });
                  }
                } catch (_) {
                  parts.add({'text': '[PDF: ${att.fileName} 读取失败]'});
                }
              }
            }
          }
          break;

        case MessageRole.assistant:
          role = 'model';
          // 关键修复：Gemini 2.5 Pro 要求包含 functionCall 的 model turn
          // 不能混入 text part，否则后续的 functionResponse 会触发 400 错误。
          // 当同时存在 text 和 functionCall 时，先将 text 作为独立的 model turn 输出，
          // 然后再开启新的 model turn 放 functionCall。
          final hasText = msg.content != null && msg.content!.isNotEmpty;
          final hasFunctionCalls = msg.toolCalls != null && msg.toolCalls!.isNotEmpty;

          if (hasText && hasFunctionCalls) {
            // 关键拆分：Gemini 2.5 Pro 不允许同一个 model turn 中混合 text 和 functionCall。
            // 策略：先输出纯 text 的 model turn，再输出纯 functionCall 的 model turn。
            // 两个 turn 都直接写入 contents，parts 留空让后续合并逻辑跳过当前消息。

            // Step 1: text → 独立 model turn（可与前面的 model turn 合并）
            final textParts = <Map<String, dynamic>>[{'text': msg.content!}];
            if (contents.isNotEmpty && contents.last['role'] == 'model') {
              (contents.last['parts'] as List).addAll(textParts);
            } else {
              contents.add({'role': 'model', 'parts': textParts});
            }

            // Step 2: functionCall → 强制新建独立 model turn（绝对不与 text turn 合并）
            final fcParts = <Map<String, dynamic>>[];
            for (final tc in msg.toolCalls!) {
              fcParts.add({
                'functionCall': {
                  'name': tc.name,
                  'args': tc.arguments.isNotEmpty
                      ? tc.arguments
                      : <String, dynamic>{},
                },
              });
            }
            contents.add({'role': 'model', 'parts': fcParts});

            // parts 保持为空 + 跳过后续合并逻辑（直接 continue）
            continue;
          } else {
            if (hasText) {
              parts.add({'text': msg.content!});
            }
            if (hasFunctionCalls) {
              for (final tc in msg.toolCalls!) {
                parts.add({
                  'functionCall': {
                    'name': tc.name,
                    'args': tc.arguments.isNotEmpty
                        ? tc.arguments
                        : <String, dynamic>{},
                  },
                });
              }
            }
          }
          break;

        case MessageRole.tool:
          role = 'user';
          // 优先使用 toolName 属性，降级正则解析 callId
          final toolName = msg.toolName ?? _extractToolName(msg.toolCallId);
          // 尝试解析为 JSON，如果成功且是 Map 则直接作为 response，否则包裹一层对象
          dynamic responseObj;
          final contentStr = msg.content ?? '';
          if (contentStr.isNotEmpty) {
            try {
              responseObj = jsonDecode(contentStr);
              if (responseObj is! Map) {
                // 如果解析出来是 List 或者基本类型，也要包裹一层，因为 Gemini要求的是 Object(Struct)
                responseObj = {'result': responseObj};
              }
            } catch (_) {
              // 不是 JSON，用 text fallback 包裹
              responseObj = {'result': contentStr};
            }
          } else {
            responseObj = {'result': ''};
          }

          parts.add({
            'functionResponse': {
              'name': toolName,
              'response': responseObj,
            },
          });
          break;

        default:
          continue;
      }

      // 忽略因全是 null 导致提取出空的 model Turn
      if (parts.isEmpty && role == 'model') {
        continue;
      }

      // 合并相邻且相同 Role 的对话块 (Gemini 强制要求交替 User/Model)
      if (contents.isNotEmpty && contents.last['role'] == role) {
        (contents.last['parts'] as List).addAll(parts);
      } else {
        contents.add({'role': role, 'parts': parts});
      }
    }

    if (contents.isEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'Hello'},
        ],
      });
    }

    // --- 强制约束 Gemini 严格的上下文协议 ---
    // 1. 清洗残缺的 functionCall / functionResponse 对偶
    for (int i = 0; i < contents.length; i++) {
      final turn = contents[i];
      final parts = turn['parts'] as List; // List<dynamic>

      if (turn['role'] == 'model') {
        bool hasFc = parts.any((p) => p is Map && p.containsKey('functionCall'));
        if (hasFc) {
          bool nextHasFr = false;
          if (i + 1 < contents.length) {
            final nextTurn = contents[i + 1];
            nextHasFr = (nextTurn['parts'] as List)
                .any((p) => p is Map && p.containsKey('functionResponse'));
          }
          if (!nextHasFr) {
            for (int j = 0; j < parts.length; j++) {
              if (parts[j] is Map && (parts[j] as Map).containsKey('functionCall')) {
                final fc = parts[j]['functionCall'];
                parts[j] = {'text': '[工具调用 (${fc['name']}) 被跳过或截断]'};
              }
            }
          }
        }
      } else if (turn['role'] == 'user') {
        bool hasFr = parts.any((p) => p is Map && p.containsKey('functionResponse'));
        if (hasFr) {
          bool prevHasFc = false;
          if (i > 0) {
            final prevTurn = contents[i - 1];
            prevHasFc = (prevTurn['parts'] as List)
                .any((p) => p is Map && p.containsKey('functionCall'));
          }
          if (!prevHasFc) {
            for (int j = 0; j < parts.length; j++) {
              if (parts[j] is Map && (parts[j] as Map).containsKey('functionResponse')) {
                final fr = parts[j]['functionResponse'];
                parts[j] = {
                  'text': '[工具返回 (${fr['name']}): ${fr['response']}]'
                };
              }
            }
          }
        }
      }
    }

    // 2. 首个回合必须是 user
    if (contents.isNotEmpty && contents.first['role'] == 'model') {
      contents.insert(0, {
        'role': 'user',
        'parts': [
          {'text': '[历史对话已被截断...]'}
        ]
      });
    }

    return contents;
  }

  /// 从 callId 中提取工具名
  /// callId 格式: gemini_{toolName}_{timestamp}
  String _extractToolName(String? callId) {
    if (callId == null) return 'tool_result';
    final parts = callId.split('_');
    // gemini_{name}_{timestamp} → 取中间部分
    if (parts.length >= 3 && parts.first == 'gemini') {
      // 工具名可能包含下划线，去掉首尾（gemini 和 timestamp）
      return parts.sublist(1, parts.length - 1).join('_');
    }
    return 'tool_result';
  }
}
