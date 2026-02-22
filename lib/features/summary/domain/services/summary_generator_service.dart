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
import 'package:baishou/core/clients/ai_client.dart';

part 'summary_generator_service.g.dart';

/// 总结生成服务
/// 负责协调日记/总结仓库数据，并根据选定的 AI 供应商生成多维度的总结。
class SummaryGeneratorService {
  final DiaryRepository _diaryRepo;
  final SummaryRepository _summaryRepo;
  final Ref _ref;

  SummaryGeneratorService(this._diaryRepo, this._summaryRepo, this._ref);

  /// 为特定的总结目标生成内容。
  /// [target] 描述了要生成的总结类型和时间范围。
  /// 返回一个字符串流，包含状态更新（以 "STATUS:" 开头）或最终生成的 Markdown。
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

  /// 构建周记所需的上下文数据（日记列表）
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

  /// 构建月报所需的上下文数据（周记列表）
  Future<String> _buildMonthlyContext(DateTime start, DateTime end) async {
    // 获取从指定开始日期之后的所有总结
    // 获取所有 startDate 在该月份内的周记。
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

  /// 构建季报所需的上下文数据（月报列表）
  Future<String> _buildQuarterlyContext(DateTime start, DateTime end) async {
    // 获取 startDate 在该季度内的所有月报
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

  /// 构建年鉴所需的上下文数据（优先使用季报，回退至月报）
  Future<String> _buildYearlyContext(DateTime start, DateTime end) async {
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

  /// 统一的 API 调用入口
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

    if (modelId.isEmpty) {
      throw Exception('未配置模型。请在"设置"中配置对话模型 (Settings -> AI Config -> 默认模型)');
    }

    // 通过 Factory 实例化特定 Client 并发起请求
    try {
      final client = AiClientFactory.createClient(provider);
      // 这里的 Prompt 由业务侧拼接好传给 Client，因为部分底层 API (如 Gemini Native) 不支持单独传 system role
      final combinedPrompt = '$prompt\n\n$data';
      return await client.generateContent(
        prompt: combinedPrompt,
        modelId: modelId,
      );
    } catch (e) {
      throw Exception(_sanitizeError(e));
    }
  }

  /// 测试供应商连接
  Future<void> testConnection(AiProviderModel provider) async {
    try {
      final client = AiClientFactory.createClient(provider);
      await client.testConnection();
    } catch (e) {
      throw Exception(_sanitizeError(e));
    }
  }

  /// 错误脱敏与汉化
  /// 隐藏 API Key 并将常见的网络错误转换为用户友好的中文提示。
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
        errorMsg.contains('连接超时')) {
      errorMsg = '网络连接失败。请检查网络设置或配置国内可用的 API Base URL (反向代理)。\n原始错误: $errorMsg';
    } else if (errorMsg.contains('HandshakeException')) {
      errorMsg = 'SSL 握手失败。请检查网络或代理设置。\n原始错误: $errorMsg';
    }

    return errorMsg;
  }
}

@Riverpod(keepAlive: true)
SummaryGeneratorService summaryGeneratorService(Ref ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final summaryRepo = ref.watch(summaryRepositoryProvider);
  return SummaryGeneratorService(diaryRepo, summaryRepo, ref);
}
