import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/features/onboarding/data/providers/onboarding_provider.dart';
import 'package:baishou/features/onboarding/presentation/widgets/compression_chart.dart';
import 'package:baishou/i18n/strings.g.dart';
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
  static const int _numPages = 5;

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
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
            t.onboarding.welcome_title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t.onboarding.welcome_desc,
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            t.onboarding.philosophy_title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text(
            t.onboarding.philosophy_desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, height: 1.5),
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
          Text(
            t.onboarding.compression_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            t.onboarding.compression_desc,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_queue_outlined, size: 80, color: Colors.black),
          const SizedBox(height: 32),
          Text(
            t.onboarding.api_guide_title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              t.onboarding.api_guide_desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6),
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
          Text(
            t.onboarding.privacy_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Text(
            t.onboarding.privacy_desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, height: 1.5),
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
            children: List.generate(_numPages, (index) {
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
          Row(
            children: [
              if (_currentPage > 0)
                TextButton.icon(
                  onPressed: _previousPage,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(t.common.back),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _nextPage,
                child: Text(
                  _currentPage == _numPages - 1
                      ? t.onboarding.get_started
                      : t.common.next,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
