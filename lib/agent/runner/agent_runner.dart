/// Agent 运行循环 — 核心引擎
/// 参考 opencode: packages/opencode/src/session/processor.ts

import 'dart:async';
import 'package:baishou/agent/clients/ai_client.dart';
import 'package:baishou/agent/models/chat_message.dart';
import 'package:baishou/agent/models/stream_event.dart';
import 'package:baishou/agent/tools/agent_tool.dart';

/// Agent 运行配置
class AgentConfig {
  final String modelId;
  final String systemPrompt;
  final int maxSteps;
  final double? temperature;

  const AgentConfig({
    required this.modelId,
    required this.systemPrompt,
    this.maxSteps = 10,
    this.temperature,
  });
}

/// Agent 运行产出的事件
sealed class AgentEvent {
  const AgentEvent();
}

class AgentTextDelta extends AgentEvent {
  final String text;
  const AgentTextDelta(this.text);
}

class AgentToolStart extends AgentEvent {
  final ToolCall toolCall;
  const AgentToolStart(this.toolCall);
}

class AgentToolComplete extends AgentEvent {
  final ToolCall toolCall;
  final ToolResult result;
  final int durationMs;
  const AgentToolComplete(this.toolCall, this.result, {this.durationMs = 0});
}

class AgentComplete extends AgentEvent {
  final String text;
  final List<ChatMessage> messages;
  final TokenUsage? usage;
  const AgentComplete(this.text, this.messages, {this.usage});
}

class AgentError extends AgentEvent {
  final Object error;
  const AgentError(this.error);
}

class AgentStepInfo extends AgentEvent {
  final int currentStep;
  final int maxSteps;
  const AgentStepInfo(this.currentStep, this.maxSteps);
}

/// Agent Runner — 核心引擎
class AgentRunner {
  final AiClient client;
  final ToolRegistry tools;
  final AgentConfig config;

  AgentRunner({
    required this.client,
    required this.tools,
    required this.config,
  });

  /// 运行 Agent Loop
  Stream<AgentEvent> run({
    required List<ChatMessage> messages,
    required ToolContext context,
    String? askId,
  }) async* {
    // messages 已由调用方包含完整上下文（含最新 userMessage）
    final messageHistory = List<ChatMessage>.from(messages);
    // 单独追踪本轮新增的消息（assistant/tool），用于返回给调用方持久化
    final newMessages = <ChatMessage>[];

    int step = 0;
    int totalInputTokens = 0;
    int totalOutputTokens = 0;
    int totalCachedTokens = 0;

    while (step < config.maxSteps) {
      step++;
      yield AgentStepInfo(step, config.maxSteps);

      final allMessages = [
        ChatMessage.system(config.systemPrompt),
        ...messageHistory,
      ];

      String textBuffer = '';
      final pendingToolCalls = <ToolCall>[];
      TokenUsage? stepUsage;

      await for (final event in client.chatStream(
        messages: allMessages,
        modelId: config.modelId,
        tools: tools.toDefinitions(),
        temperature: config.temperature,
      )) {
        switch (event) {
          case TextDelta(:final text):
            textBuffer += text;
            yield AgentTextDelta(text);

          case ToolCallComplete(:final toolCall):
            pendingToolCalls.add(toolCall);

          case StreamDone(:final usage):
            stepUsage = usage;

          case StreamError(:final error):
            yield AgentError(error);
            return;

          default:
            break;
        }
      }

      // 累加多步的 token 用量
      if (stepUsage != null) {
        final su = stepUsage;
        totalInputTokens += su.inputTokens;
        totalOutputTokens += su.outputTokens;
        if (su.cachedInputTokens != null) {
          totalCachedTokens += su.cachedInputTokens!;
        }
      }

      final assistantMsg = ChatMessage.assistant(
        content: textBuffer.isNotEmpty ? textBuffer : null,
        toolCalls: pendingToolCalls.isNotEmpty ? pendingToolCalls : null,
        askId: askId,
      );
      messageHistory.add(assistantMsg);
      newMessages.add(assistantMsg);

      if (pendingToolCalls.isEmpty) {
        yield AgentComplete(
          textBuffer,
          newMessages,
          usage: TokenUsage(
            inputTokens: totalInputTokens,
            outputTokens: totalOutputTokens,
            cachedInputTokens: totalCachedTokens > 0 ? totalCachedTokens : null,
          ),
        );
        return;
      }

      for (final call in pendingToolCalls) {
        yield AgentToolStart(call);

        final tool = tools.get(call.name);
        late final ToolResult result;
        final stopwatch = Stopwatch()..start();

        if (tool == null) {
          result = ToolResult.error(
            'Tool "${call.name}" does not exist or has been disabled by the user. '
            'Available tools: ${tools.ids.join(", ")}',
          );
        } else {
          try {
            result = await tool.execute(call.arguments, context);
          } catch (e) {
            result = ToolResult.error('Tool execution failed: $e');
          }
        }

        stopwatch.stop();
        yield AgentToolComplete(
          call,
          result,
          durationMs: stopwatch.elapsedMilliseconds,
        );

        final toolMsg = ChatMessage.tool(
          callId: call.id,
          content: result.output,
          toolName: call.name,
          askId: askId,
        );
        messageHistory.add(toolMsg);
        newMessages.add(toolMsg);
      }
    }

    yield AgentComplete(
      '达到最大执行步数限制 (${config.maxSteps})，已中止。',
      newMessages,
      usage: TokenUsage(
        inputTokens: totalInputTokens,
        outputTokens: totalOutputTokens,
        cachedInputTokens: totalCachedTokens > 0 ? totalCachedTokens : null,
      ),
    );
  }
}
