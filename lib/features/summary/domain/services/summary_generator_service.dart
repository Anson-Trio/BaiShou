import 'dart:convert';
import 'package:baishou/core/database/tables/summaries.dart';
import 'package:baishou/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:baishou/features/diary/domain/repositories/diary_repository.dart';
import 'package:baishou/features/summary/data/repositories/summary_repository_impl.dart';
import 'package:baishou/features/summary/domain/entities/summary.dart';
import 'package:baishou/features/summary/domain/repositories/summary_repository.dart';
import 'package:baishou/features/summary/domain/services/missing_summary_detector.dart'; // 用于 MissingSummary
import 'package:baishou/source/prompts/monthly_prompt.dart';
import 'package:baishou/source/prompts/quarterly_prompt.dart';
import 'package:baishou/source/prompts/weekly_prompt.dart';
import 'package:baishou/source/prompts/yearly_prompt.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:baishou/core/services/api_config_service.dart';

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

      yield 'STATUS:正在思考 (${dotenv.env['GEMINI_MODEL'] ?? 'AI'})...';

      final generatedContent = await _callApi(promptTemplate, contextData);

      yield generatedContent;
    } catch (e) {
      yield 'STATUS:生成失败: $e';
      rethrow;
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
    // 获取此范围内的周记总结
    final summaries = await _summaryRepo.getSummaries(start: start, end: end);
    final weeklies = summaries
        .where((s) => s.type == SummaryType.weekly)
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
    final summaries = await _summaryRepo.getSummaries(start: start, end: end);
    final monthlies = summaries
        .where((s) => s.type == SummaryType.monthly)
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
    final summaries = await _summaryRepo.getSummaries(start: start, end: end);
    // 优先使用季报，回退到月报？
    // 让我们使用季报
    final quarterlies = summaries
        .where((s) => s.type == SummaryType.quarterly)
        .toList();

    // 如果没有季报则回退？
    // 如果季报为空，或许可以使用月报？
    // 目前，让我们坚持层级结构：检查季报。

    if (quarterlies.isEmpty) {
      // 如果没有找到季报，则回退到月报
      final monthlies = summaries
          .where((s) => s.type == SummaryType.monthly)
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
      // 估算季度
      final q = (s.startDate.month / 3).ceil();
      buffer.writeln('\n#### ${s.startDate.year} Q$q 总结');
      buffer.writeln(s.content);
    }
    return buffer.toString();
  }

  // _getWeeklyPrompt 已移除，改为从 lib/source/prompts/weekly_prompt.dart 导入

  Future<String> _callApi(String prompt, String data) async {
    final apiConfig = _ref.read(apiConfigServiceProvider);
    final provider = apiConfig.provider;
    final apiKey = apiConfig.apiKey;

    // 如果未配置 Key，抛出异常
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception('请先在"设置"中配置 API Key (Settings -> AI Config)');
    }

    if (provider == AiProvider.gemini) {
      return _callGemini(prompt, data, apiConfig);
    } else {
      return _callOpenAi(prompt, data, apiConfig);
    }
  }

  Future<String> _callGemini(
    String prompt,
    String data,
    ApiConfigService config,
  ) async {
    final model = config.model;
    if (model.isEmpty) {
      throw Exception(
        '未配置模型名称。请在"设置"中配置模型名称 (Settings -> AI Config -> Model Name)',
      );
    }

    // Gemini 允许 Base URL 为空，默认为官方 v1beta
    // 如果用户填了 Base URL（例如代理），则使用用户填的
    final baseUrl = config.baseUrl.isNotEmpty
        ? config.baseUrl
        : 'https://generativelanguage.googleapis.com/v1beta';

    final uri = Uri.parse(
      '$baseUrl/models/$model:generateContent?key=${config.apiKey}',
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
                  {'text': data},
                ],
              },
            ],
            'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 36000},
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('请求超时，请检查网络'),
        );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception(
        'Gemini API 错误: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<String> _callOpenAi(
    String prompt,
    String data,
    ApiConfigService config,
  ) async {
    final model = config.model;
    if (model.isEmpty) {
      throw Exception(
        '未配置模型名称。请在"设置"中配置模型名称 (Settings -> AI Config -> Model Name)',
      );
    }

    var baseUrl = config.baseUrl;
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
            'Authorization': 'Bearer ${config.apiKey}',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': '$prompt\n\n$data', // 将 prompt 和 data 拼接
              },
            ],
            'temperature': 0.7,
            'max_tokens': 36000,
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('请求超时，请检查网络'),
        );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes)); // 确保 UTF8 解码
      return json['choices'][0]['message']['content'];
    } else {
      throw Exception(
        'OpenAI API 错误: ${response.statusCode} - ${response.body}',
      );
    }
  }
}

@Riverpod(keepAlive: true)
SummaryGeneratorService summaryGeneratorService(Ref ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final summaryRepo = ref.watch(summaryRepositoryProvider);
  return SummaryGeneratorService(diaryRepo, summaryRepo, ref);
}
