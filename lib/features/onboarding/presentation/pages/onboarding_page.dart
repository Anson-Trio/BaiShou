import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/onboarding/data/providers/onboarding_provider.dart';
import 'package:baishou/features/onboarding/presentation/widgets/compression_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 新手引导页面
/// 向用户介绍应用核心理念（灵魂备份、记忆压缩）并引导其完成基础配置（如 API Key）。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final geminiProvider = ref
        .read(apiConfigServiceProvider)
        .getProvider('gemini');
    _apiKeyController.text = geminiProvider?.apiKey ?? '';
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    // Save API Key if entered
    if (_apiKeyController.text.isNotEmpty) {
      final configService = ref.read(apiConfigServiceProvider);
      final geminiProvider = configService.getProvider('gemini');
      if (geminiProvider != null) {
        await configService.updateProvider(
          geminiProvider.copyWith(apiKey: _apiKeyController.text),
        );
      }
    }

    // Mark onboarding as complete
    await ref.read(onboardingCompletedProvider.notifier).complete();

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomeSlide(),
                  _buildPhilosophySlide(),
                  _buildCompressionSlide(),
                  _buildApiConfigSlide(),
                  _buildPrivacySlide(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/icon/icon.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.pets, size: 80, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '你好，我是白守狐',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text('你可以叫我小白', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildPhilosophySlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_stories, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 32),
          Text(
            '你的灵魂备份',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            '白守会全力为你守护重要的回忆。\n在这里，我们对抗遗忘。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressionSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('记忆压缩算法', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '年度不覆盖其他，层层递进',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Expanded(child: CompressionChart()),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildApiConfigSlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology, size: 80, color: Colors.purple),
          const SizedBox(height: 32),
          Text('AI 助手配置', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text(
            '配置 Gemini API 后，可以直接调用 AI 模型来生成日记的总结。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              border: OutlineInputBorder(),
              hintText: '可选，稍后在设置中配置',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySlide() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.green),
          const SizedBox(height: 32),
          Text('数据完全掌控', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          const Text(
            '所有的数据都是可以随意导出。\n并且提供局域网传输。\n让你能守护自己和爱人的回忆。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Indicators
          Row(
            children: List.generate(5, (index) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                ),
              );
            }),
          ),
          // Button
          FilledButton(
            onPressed: _nextPage,
            child: Text(_currentPage == 4 ? '开始旅程' : '下一步'),
          ),
        ],
      ),
    );
  }
}
