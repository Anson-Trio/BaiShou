import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发理念')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              title: '数据自主权',
              content:
                  '我们不会对用户的数据做任何防止导出的措施，我们相信，数据是用户最宝贵的财产，并且为用户提供了多种数据导出和同步的方式。',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: '隐私与安全',
              content: '我们不会审查用户的日记。当云同步功能上线后，用户同步到云的数据会是加密的，确保您的隐私得到最大程度的保护。',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: '本地优先',
              content:
                  '目前版本（MVP）的所有数据均存储在您的本地设备上。除非您主动分享或导出，否则这些数据不会通过网络传输到任何第三方服务器。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
