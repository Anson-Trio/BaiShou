import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/core/theme/app_theme.dart';
import 'package:baishou/features/summary/domain/services/summary_generator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiConfigPage extends ConsumerStatefulWidget {
  const AiConfigPage({super.key});

  @override
  ConsumerState<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends ConsumerState<AiConfigPage> {
  final _formKey = GlobalKey<FormState>();
  late AiProvider _provider;
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _isObscure = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(apiConfigServiceProvider);
    _provider = config.provider;
    _modelController.text = config.model;

    _updateConfigFields(); // Load correct key and base URL

    // Set default model if empty and using Gemini
    if (_provider == AiProvider.gemini && _modelController.text.isEmpty) {
      _modelController.text = 'gemini-3-flash-preview';
    }
  }

  void _updateConfigFields() {
    final config = ref.read(apiConfigServiceProvider);
    if (_provider == AiProvider.gemini) {
      _apiKeyController.text = config.geminiApiKey;
      _baseUrlController.text = config.geminiBaseUrl;
    } else {
      _apiKeyController.text = config.openAiApiKey;
      _baseUrlController.text = config.openAiBaseUrl;
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      final config = ref.read(apiConfigServiceProvider);
      await config.setProvider(_provider);
      await config.setModel(_modelController.text.trim());

      // Save Key and Base URL to specific slot based on current provider
      if (_provider == AiProvider.gemini) {
        await config.setGeminiApiKey(_apiKeyController.text.trim());
        await config.setGeminiBaseUrl(_baseUrlController.text.trim());
      } else {
        await config.setOpenAiApiKey(_apiKeyController.text.trim());
        await config.setOpenAiBaseUrl(_baseUrlController.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存')));
        Navigator.pop(context); // Optional: go back after save
      }
    }
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写 API Key')));
      return;
    }

    setState(() {
      _isTesting = true;
    });

    try {
      // 临时保存配置用于测试连接
      // 注意：这里必须先保存，因为 SummaryGeneratorService 读取的是持久化的配置
      // 如果不保存直接测试，SummaryGeneratorService 读到的还是旧的配置
      // _saveConfig 已经包含了 Navigator.pop，这里逻辑有点冲突
      // 如果是为了测试连接，不应该直接退出页面。
      // 所以我们需要把_saveConfig里的pop逻辑改一下，或者单独写保存逻辑。
      // 让我们重构一下，不要在 _testConnection 里调用 _saveConfig 的 pop 版本。

      // 手动保存但不退出
      final config = ref.read(apiConfigServiceProvider);
      await config.setProvider(_provider);
      await config.setModel(_modelController.text.trim());
      if (_provider == AiProvider.gemini) {
        await config.setGeminiApiKey(_apiKeyController.text.trim());
        await config.setGeminiBaseUrl(_baseUrlController.text.trim());
      } else {
        await config.setOpenAiApiKey(_apiKeyController.text.trim());
        await config.setOpenAiBaseUrl(_baseUrlController.text.trim());
      }

      await ref.read(summaryGeneratorServiceProvider).testConnection(config);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接测试成功！🎉')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 配置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConfigCard(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: const Text('测试连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isTesting ? null : _saveConfig,
                      icon: const Icon(Icons.save),
                      label: const Text('保存配置'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: AppTheme.primary),
                const SizedBox(width: 12),
                Text(
                  'AI 参数设置',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Provider Selection
            DropdownButtonFormField<AiProvider>(
              value: _provider,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'AI 提供商',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: AiProvider.gemini,
                  child: Text('Google Gemini', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: AiProvider.openai,
                  child: Text(
                    'OpenAI 兼容 (DeepSeek/ChatGPT)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _provider = value;
                    _updateConfigFields(); // Switch key and base url text

                    // Switch Model Text
                    if (_provider == AiProvider.gemini) {
                      if (_modelController.text.isEmpty) {
                        _modelController.text = 'gemini-3-flash-preview';
                      }
                    } else {
                      // OpenAI: clear if it was default Gemini
                      if (_modelController.text == 'gemini-3-flash-preview') {
                        _modelController.text = '';
                      }
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Base URL
            TextFormField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: 'API Base URL',
                hintText: _provider == AiProvider.gemini
                    ? '默认为空 (使用官方地址)'
                    : 'https://api.openai.com/v1',
                border: const OutlineInputBorder(),
                helperText: _provider == AiProvider.gemini
                    ? '通常不需要填写，除非使用代理'
                    : 'OpenAI 兼容模式必填',
                helperMaxLines: 2,
              ),
              validator: (value) {
                if (_provider == AiProvider.openai &&
                    (value == null || value.isEmpty)) {
                  return 'OpenAI 模式下 Base URL 不能为空';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // API Key
            TextFormField(
              controller: _apiKeyController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscure = !_isObscure;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'API Key 不能为空';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Model Name
            TextFormField(
              controller: _modelController,
              decoration: InputDecoration(
                labelText: '模型名称',
                hintText: _provider == AiProvider.gemini
                    ? '例如: gemini-3-flash-preview'
                    : '例如: deepseek-chat',
                border: const OutlineInputBorder(),
                helperText: _provider == AiProvider.gemini
                    ? '必填项 (推荐 gemini-3-flash-preview)'
                    : '必填项 (如 deepseek-chat)',
                helperMaxLines: 2,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '模型名称不能为空';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
