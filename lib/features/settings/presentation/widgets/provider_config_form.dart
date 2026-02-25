import 'package:baishou/core/models/ai_provider_model.dart';
import 'package:flutter/material.dart';
import 'package:baishou/i18n/strings.g.dart';

/// 负责渲染 API 密钥与基础 URL 的配置表单
class ProviderConfigForm extends StatelessWidget {
  final AiProviderModel provider;
  final TextEditingController baseUrlController;
  final TextEditingController apiKeyController;
  final bool isObscure;
  final VoidCallback onObscureToggle;
  final bool isTesting;
  final VoidCallback onTestRequested;
  final VoidCallback onResetRequested;
  final GlobalKey<FormState> formKey;

  const ProviderConfigForm({
    super.key,
    required this.provider,
    required this.baseUrlController,
    required this.apiKeyController,
    required this.isObscure,
    required this.onObscureToggle,
    required this.isTesting,
    required this.onTestRequested,
    required this.onResetRequested,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.api_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.settings.api_config,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: onResetRequested,
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: Text(t.settings.reset_default),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: baseUrlController,
              decoration: InputDecoration(
                labelText: 'API Base URL',
                hintText: '',
                prefixIcon: const Icon(Icons.link_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return t.settings.error_base_url_required;
                }
                if (!Uri.parse(value).isAbsolute) {
                  return t.settings.error_invalid_url;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: apiKeyController,
              obscureText: isObscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    isObscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: onObscureToggle,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isTesting ? null : onTestRequested,
              icon: isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.wifi_rounded, size: 18),
              label: Text(
                isTesting
                    ? t.settings.testing_connection
                    : t.settings.test_connection,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
