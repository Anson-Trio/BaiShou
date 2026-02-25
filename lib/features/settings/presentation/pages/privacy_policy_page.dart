import 'package:flutter/material.dart';
import 'package:baishou/i18n/strings.g.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.privacy.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              title: t.privacy.data_ownership,
              content: t.privacy.data_ownership_desc,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: t.privacy.transparency,
              content: t.privacy.transparency_desc,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: t.privacy.local_first,
              content: t.privacy.local_first_desc,
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
