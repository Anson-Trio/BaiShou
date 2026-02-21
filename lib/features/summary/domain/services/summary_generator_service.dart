import 'dart:convert';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart'; // 用于 MissingSummary
import 'package:baishou/source/prompts/monthly_prompt.dart';
import 'package:baishou/source/prompts/quarterly_prompt.dart';
import 'package:baishou/source/prompts/weekly_prompt.dart';
import 'package:baishou/source/prompts/yearly_prompt.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/models/ai_provider_model.dart';

part 'summary_generator_service.g.dart';

class SummaryGeneratorService {
  final DiaryRepository _diaryRepo;
  final SummaryRepository _summaryRepo;
  final Ref _ref;

  SummaryGeneratorService(this._diaryRepo, this._summaryRepo, this._ref);

  /// 为给定的缺失项生成总结。
  /// 返回状态消息/块的流，最后以最终的 Markdown 内容结束。
  ///
  /// 流程：
  /// 1. 获取原始数据（周记用日记；月报/季报用总结）。
  /// 2. 基于模板构建 Prompt。
  /// 3. 调用 Gemini API。
  /// 4. 返回结果。
  Stream<String> generate(MissingSummary target) async* {
    yield 'STATUS:正在读取数据...';

    // 获取当前配置的模型名称
    final apiConfig = _ref.read(apiConfigServiceProvider);
    final providerId = apiConfig.globalSummaryProviderId;
    final modelName = apiConfig.globalSummaryModelId;

    String contextData = '';
    String promptTemplate = '';

    try {
      switch (target.type) {
        case SummaryType.weekly:
          contextData = await _buildWeeklyContext(
            target.startDate,
            target.endDate,
          );
          promptTemplate = getWeeklyPrompt(target);
          break;
        case SummaryType.monthly:
          contextData = await _buildMonthlyContext(
            target.startDate,
            target.endDate,
          );
          promptTemplate = getMonthlyPrompt(target);
          break;
        case SummaryType.quarterly:
          contextData = await _buildQuarterlyContext(
            target.startDate,
            target.endDate,
          );
          promptTemplate = getQuarterlyPrompt(target);
          break;
        case SummaryType.yearly:
          contextData = await _buildYearlyContext(
            target.startDate,
            target.endDate,
          );
          promptTemplate = getYearlyPrompt(target);
          break;
      }

      if (contextData.isEmpty) {
        yield 'STATUS:没有足够的数据来生成总结。';
        return;
      }

      yield 'STATUS:正在思考 ($modelName)...';

      final generatedContent = await _callApi(
        providerId,
        modelName,
        promptTemplate,
        contextData,
      );

      yield generatedContent;
    } catch (e) {
      final msg = _sanitizeError(e);
      yield 'STATUS:生成失败: $msg';
      // 重新抛出脱敏后的异常，以便上层逻辑（如UI）能显示处理后的信息
      throw Exception(msg);
    }
  }

  Future<String> _buildWeeklyContext(DateTime start, DateTime end) async {
    final diaries = await _diaryRepo.getDiariesInRange(start, end);
    if (diaries.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln(
      '### 原始日记数据 (${start.year}-${start.month}-${start.day} ~ ${end.month}-${end.day})',
    );
    for (final d in diaries) {
      buffer.writeln('\n#### ${d.date.year}-${d.date.month}-${d.date.day}');
      buffer.writeln(d.content);
      buffer.writeln('Tags: ${d.tags.join(", ")}');
    }
    return buffer.toString();
  }

  Future<String> _buildMonthlyContext(DateTime start, DateTime end) async {
    // 获取从指定开始日期之后的所有总结
    // 注意：Repository 的 getSummaries(start, end) 是严格包含 (startDate >= start AND endDate <= end)
    // 但周记可能跨月（例如1月30日-2月5日），根据 MissingSummaryDetector 的逻辑，它被分配给开始日期所在的月份。
    // 因此，我们需要获取所有 startDate 在该月份内的周记。
    final summaries = await _summaryRepo.getSummaries(start: start);

    final weeklies = summaries
        .where((s) => s.type == SummaryType.weekly)
        // 内存过滤：只保留开始日期在范围内的周记
        .where((s) => s.startDate.isBefore(end.add(const Duration(seconds: 1))))
        .toList();

    if (weeklies.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('### 原始周记数据 (${start.year}-${start.month})');
    for (final s in weeklies) {
      buffer.writeln(
        '\n#### ${s.startDate.toString().split(' ')[0]} ~ ${s.endDate.toString().split(' ')[0]} 周记',
      );
      buffer.writeln(s.content);
    }
    return buffer.toString();
  }

  Future<String> _buildQuarterlyContext(DateTime start, DateTime end) async {
    // 同上，放宽结束日期限制
    final summaries = await _summaryRepo.getSummaries(start: start);
    final monthlies = summaries
        .where((s) => s.type == SummaryType.monthly)
        .where((s) => s.startDate.isBefore(end.add(const Duration(seconds: 1))))
        .toList();

    if (monthlies.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('### 原始月报数据 (${start.year} Q${(start.month / 3).ceil()})');
    for (final s in monthlies) {
      buffer.writeln('\n#### ${s.startDate.year}-${s.startDate.month} 月报');
      buffer.writeln(s.content);
    }
    return buffer.toString();
  }

  Future<String> _buildYearlyContext(DateTime start, DateTime end) async {
    // 同上
    final summaries = await _summaryRepo.getSummaries(start: start);
    // 优先使用季报
    final quarterlies = summaries
        .where((s) => s.type == SummaryType.quarterly)
        .where((s) => s.startDate.isBefore(end.add(const Duration(seconds: 1))))
        .toList();

    if (quarterlies.isEmpty) {
      // 如果没有找到季报，则回退到月报
      final monthlies = summaries
          .where((s) => s.type == SummaryType.monthly)
          .where(
            (s) => s.startDate.isBefore(end.add(const Duration(seconds: 1))),
          )
          .toList();
      if (monthlies.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('### 原始月报数据 (${start.year}年 - 季度缺失，使用月报补全)');
        for (final s in monthlies) {
          buffer.writeln('\n#### ${s.startDate.year}-${s.startDate.month} 月报');
          buffer.writeln(s.content);
        }
        return buffer.toString();
      }
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('### 原始季度总结数据 (${start.year}年)');
    for (final s in quarterlies) {
      final q = (s.startDate.month / 3).ceil();
      buffer.writeln('\n#### ${s.startDate.year} Q$q 总结');
      buffer.writeln(s.content);
    }
    return buffer.toString();
  }

  // _getWeeklyPrompt 已移除，改为从 lib/source/prompts/weekly_prompt.dart 导入

  Future<String> _callApi(
    String providerId,
    String modelId,
    String prompt,
    String data,
  ) async {
    final apiConfig = _ref.read(apiConfigServiceProvider);
    final provider = apiConfig.getProvider(providerId);

    if (provider == null) {
      throw Exception('未找到对应的 AI 配置 ($providerId)。请在设置中重新选择全局模型。');
    }

    final apiKey = provider.apiKey;

    // 如果未配置 Key，抛出异常
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception('请先在"设置"中配置 API Key (Settings -> AI Config)');
    }

    if (provider.type == ProviderType.gemini) {
      return _callGemini(prompt, data, provider, modelId);
    } else {
      return _callOpenAi(prompt, data, provider, modelId);
    }
  }

  Future<void> testConnection(AiProviderModel provider) async {
    const testPrompt = '你好！';
    const testData = '';
    final testModel = provider.models.isNotEmpty
        ? provider.models.first
        : 'test-model';

    try {
      if (provider.type == ProviderType.gemini) {
        await _callGemini(testPrompt, testData, provider, testModel);
      } else {
        await _callOpenAi(testPrompt, testData, provider, testModel);
      }
    } catch (e) {
      throw Exception(_sanitizeError(e));
    }
  }

  String _sanitizeError(Object e) {
    var errorMsg = e.toString();

    // 1. 脱敏 API Key
    // 匹配 key=AIzaSy... 这种格式，不管是 query param 还是 json body
    errorMsg = errorMsg.replaceAllMapped(
      RegExp(r'(key|api_key|Authorization)=([A-Za-z0-9\-_]+)'),
      (match) => '${match.group(1)}=******',
    );

    // 2. 常见网络错误汉化
    if (errorMsg.contains('SocketException') ||
        errorMsg.contains('Connection refused') ||
        errorMsg.contains('Connection timed out') ||
        errorMsg.contains('信号灯超时')) {
      errorMsg = '网络连接失败。请检查网络设置或配置国内可用的 API Base URL (反向代理)。\n原始错误: $errorMsg';
    } else if (errorMsg.contains('HandshakeException')) {
      errorMsg = 'SSL 握手失败。请检查网络或代理设置。\n原始错误: $errorMsg';
    }

    return errorMsg;
  }

  Future<String> _callGemini(
    String prompt,
    String data,
    AiProviderModel provider,
    String model,
  ) async {
    if (model.isEmpty) {
      throw Exception('未配置模型。请在"设置"中配置全局对话模型 (Settings -> AI Config -> 默认模型)');
    }

    // Gemini 允许 Base URL 为空，默认为官方 v1beta
    // 如果用户填了 Base URL（例如代理），则使用用户填的
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://generativelanguage.googleapis.com/v1beta';

    final uri = Uri.parse(
      '$baseUrl/models/$model:generateContent?key=${provider.apiKey}',
    );

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
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
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('请求超时，请检查网络'),
        );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      if (json['candidates'] == null || (json['candidates'] as List).isEmpty) {
        // Check for promptFeedback if available
        final feedback = json['promptFeedback'];
        throw Exception(
          'Gemini 返回无法生成内容 (Candidates Empty). Feedback: $feedback',
        );
      }

      final candidate = json['candidates'][0];
      final finishReason = candidate['finishReason'];

      if (candidate['content'] == null) {
        throw Exception('Gemini 生成内容为空. FinishReason: $finishReason');
      }

      final parts = candidate['content']['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Gemini 生成内容部分为空. FinishReason: $finishReason');
      }

      final text = parts[0]['text'] as String?;
      if (text == null || text.isEmpty) {
        throw Exception('Gemini 生成文本为空字符串. FinishReason: $finishReason');
      }

      return text;
    } else {
      throw Exception(
        'Gemini API 错误: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<String> _callOpenAi(
    String prompt,
    String data,
    AiProviderModel provider,
    String model,
  ) async {
    if (model.isEmpty) {
      throw Exception(
        '未配置模型。请在"设置"中配置全局对话模型 (Settings -> AI Config -> 默认对话模型)',
      );
    }

    var baseUrl = provider.baseUrl;
    if (baseUrl.isEmpty) {
      throw Exception(
        '使用 OpenAI 兼容模式时，必须配置 Base URL (如 https://api.openai.com/v1)',
      );
    }
    // 移除末尾斜杠
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    // 自动补全 /chat/completions 如果没填
    if (!baseUrl.endsWith('/chat/completions')) {
      baseUrl = '$baseUrl/chat/completions';
    }

    final uri = Uri.parse(baseUrl);

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${provider.apiKey}',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': '$prompt\n\n$data', // 将 prompt 和 data 拼接
              },
            ],
            'max_tokens': 8192,
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('请求超时，请检查网络'),
        );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));

      if (json['choices'] == null || (json['choices'] as List).isEmpty) {
        throw Exception('AI返回无法生成内容 (Choices Empty)');
      }

      final choice = json['choices'][0];
      final finishReason = choice['finish_reason'];

      if (choice['message'] == null) {
        throw Exception('AI生成消息为空. FinishReason: $finishReason');
      }

      final content = choice['message']['content'] as String?;
      if (content == null || content.isEmpty) {
        throw Exception('AI生成内容为空字符串. FinishReason: $finishReason');
      }

      return content;
    } else {
      throw Exception('AI API 错误: ${response.statusCode} - ${response.body}');
    }
  }
}

@Riverpod(keepAlive: true)
SummaryGeneratorService summaryGeneratorService(Ref ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final summaryRepo = ref.watch(summaryRepositoryProvider);
  return SummaryGeneratorService(diaryRepo, summaryRepo, ref);
}
