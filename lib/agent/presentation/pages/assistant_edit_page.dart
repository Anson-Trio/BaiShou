/// 助手编辑页面（创建 / 编辑）
///
/// 独立页面，支持移动端和桌面端

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/models/ai_provider_model.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/agent/presentation/widgets/emoji_picker_dialog.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/core/services/api_config_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:baishou/core/widgets/app_toast.dart';

class AssistantEditPage extends ConsumerStatefulWidget {
  /// 传入 null 表示创建新助手，传入已有助手表示编辑
  final AgentAssistant? assistant;

  const AssistantEditPage({super.key, this.assistant});

  @override
  ConsumerState<AssistantEditPage> createState() => _AssistantEditPageState();
}

class _AssistantEditPageState extends ConsumerState<AssistantEditPage> {
  late TextEditingController _nameController;
  late TextEditingController _promptController;
  late TextEditingController _descriptionController;
  String _emoji = '⭐';
  double _contextWindow = -1; // -1 = 无限
  double _compressThreshold = 0; // 0 = 不触发
  double _truncateThreshold = 4000;
  bool _isDefault = false;
  String? _avatarPath;
  bool _avatarRemoved = false;
  bool _saving = false;
  bool _isLastAssistant = false;

  // 模型绑定
  String? _selectedProviderId;
  String? _selectedModelId;

  bool get _isEditing => widget.assistant != null;
  bool get _isUnlimitedContext => _contextWindow < 0;
  bool get _isCompressDisabled => _compressThreshold <= 0;

  @override
  void initState() {
    super.initState();
    final a = widget.assistant;
    _nameController = TextEditingController(text: a?.name ?? '');
    _promptController = TextEditingController(text: a?.systemPrompt ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _emoji = a?.emoji ?? '⭐';
    _contextWindow = (a?.contextWindow ?? -1).toDouble();
    _compressThreshold = (a?.compressTokenThreshold ?? 0).toDouble();
    _truncateThreshold = (a?.truncateTokenThreshold ?? 4000).toDouble();
    _isDefault = a?.isDefault ?? false;
    _avatarPath = a?.avatarPath;
    _selectedProviderId = a?.providerId;
    _selectedModelId = a?.modelId;
    _checkIfLastAssistant();
  }

  Future<void> _checkIfLastAssistant() async {
    final all = await ref.read(assistantRepositoryProvider).getAll();
    if (mounted) {
      setState(() => _isLastAssistant = all.length <= 1);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? t.agent.assistant.edit_title
            : t.agent.assistant.create_title),
        actions: [
          if (_isEditing && !_isLastAssistant)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
              tooltip: t.common.delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 头像（点击选 emoji） ──
                Center(
                  child: GestureDetector(
                    onTap: _pickEmoji,
                    onLongPress: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          backgroundImage: _getAvatarImage(),
                          child: _getAvatarImage() == null
                              ? Text(_emoji, style: const TextStyle(fontSize: 36))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primary,
                            child: Icon(Icons.emoji_emotions,
                                size: 16, color: colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '点击选 emoji · 长按选图片',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                if (_avatarPath != null && !_avatarRemoved)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _avatarRemoved = true;
                        _avatarPath = null;
                      }),
                      child: Text(t.agent.assistant.remove_avatar),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── 名称 ──
                Text(t.agent.assistant.name_label,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: t.agent.assistant.name_hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),

                const SizedBox(height: 16),

                // ── 简介 ──
                Text('简介', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: '简短描述助手的用途...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 24),

                // ── 提示词 ──
                Text(t.agent.assistant.prompt_label,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: t.agent.assistant.prompt_hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: theme.textTheme.bodySmall,
                ),

                const SizedBox(height: 24),

                // ── 模型绑定 ──
                _buildModelSection(theme, colorScheme),

                const SizedBox(height: 24),

                // ── 上下文轮数 ──
                _buildContextSection(theme, colorScheme),

                const SizedBox(height: 24),

                // ── 会话压缩设置 ──
                _buildCompressionSection(theme, colorScheme),

                const SizedBox(height: 16),

                // ── 设为默认 ──
                SwitchListTile(
                  title: Text(t.agent.assistant.set_default),
                  subtitle: Text(t.agent.assistant.set_default_desc),
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 32),

                // ── 保存按钮 ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.common.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 上下文轮数区域
  Widget _buildContextSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.agent.assistant.context_window_label,
                style: theme.textTheme.titleSmall),
            const Spacer(),
            // 无限按钮
            FilterChip(
              label: const Text('∞ 无限'),
              selected: _isUnlimitedContext,
              onSelected: (v) => setState(() {
                _contextWindow = v ? -1 : 20;
              }),
              visualDensity: VisualDensity.compact,
            ),
            if (!_isUnlimitedContext) ...[
              const SizedBox(width: 8),
              Text('${_contextWindow.round()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  )),
            ],
          ],
        ),
        if (!_isUnlimitedContext)
          Slider(
            value: _contextWindow,
            min: 2,
            max: 100,
            divisions: 49,
            label: '${_contextWindow.round()}',
            onChanged: (v) => setState(() => _contextWindow = v),
          ),
        Text(
          _isUnlimitedContext
              ? '将发送所有历史消息给模型'
              : t.agent.assistant.context_window_desc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 模型绑定区域
  Widget _buildModelSection(ThemeData theme, ColorScheme colorScheme) {
    final apiConfig = ref.read(apiConfigServiceProvider);
    final providers = apiConfig.getProviders().where((p) => p.isEnabled).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('绑定模型', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (_selectedProviderId != null)
              TextButton(
                onPressed: () => setState(() {
                  _selectedProviderId = null;
                  _selectedModelId = null;
                }),
                child: const Text('使用全局模型'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedProviderId == null)
          OutlinedButton.icon(
            onPressed: () => _showModelPicker(providers),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('选择模型（使用全局默认）'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          )
        else
          InkWell(
            onTap: () => _showModelPicker(providers),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined,
                      color: colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedProviderId ?? '',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            )),
                        Text(_selectedModelId ?? '',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colorScheme.outline),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          '绑定后，使用此助手的会话将始终使用指定模型',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 会话压缩设置区域
  Widget _buildCompressionSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('会话压缩', style: theme.textTheme.titleSmall),
            const Spacer(),
            FilterChip(
              label: Text(_isCompressDisabled ? '不压缩' : '已启用'),
              selected: !_isCompressDisabled,
              onSelected: (v) => setState(() {
                _compressThreshold = v ? 80000 : 0;
                if (!v) _truncateThreshold = 4000;
              }),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isCompressDisabled
              ? '对话不会自动压缩，所有消息将完整保留'
              : '对话 token 达到阈值时自动压缩旧消息',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        if (!_isCompressDisabled) ...[
          const SizedBox(height: 12),

          // 压缩阈值
          Row(
            children: [
              const Text('压缩触发'),
              const Spacer(),
              Text(_formatTokens(_compressThreshold.round()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  )),
            ],
          ),
          Slider(
            value: _compressThreshold,
            min: 10000,
            max: 300000,
            divisions: 29,
            label: _formatTokens(_compressThreshold.round()),
            onChanged: (v) => setState(() {
              _compressThreshold = v;
              if (_truncateThreshold > _compressThreshold * 0.8) {
                _truncateThreshold = (_compressThreshold * 0.5).roundToDouble();
              }
            }),
          ),

          // 截断阈值
          Row(
            children: [
              const Text('截断旧消息'),
              const Spacer(),
              Text(_formatTokens(_truncateThreshold.round()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  )),
            ],
          ),
          Slider(
            value: _truncateThreshold.clamp(1000, _compressThreshold * 0.8),
            min: 1000,
            max: _compressThreshold * 0.8,
            divisions: 29,
            label: _formatTokens(_truncateThreshold.round()),
            onChanged: (v) => setState(() => _truncateThreshold = v),
          ),
        ],
      ],
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 10000) {
      final w = (tokens / 10000).toStringAsFixed(tokens % 10000 == 0 ? 0 : 1);
      return '${w}w';
    }
    return '$tokens';
  }

  void _showModelPicker(List<AiProviderModel> providers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('选择模型',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: providers.length,
                    itemBuilder: (ctx, i) {
                      final provider = providers[i];
                      final modelList = provider.enabledModels.isNotEmpty
                          ? provider.enabledModels
                          : provider.models;

                      return ExpansionTile(
                        title: Text(provider.name),
                        children: modelList.map((modelId) {
                          final isSelected = _selectedProviderId == provider.id &&
                              _selectedModelId == modelId;
                          return ListTile(
                            title: Text(modelId),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedProviderId = provider.id;
                                _selectedModelId = modelId;
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPickerDialog(context);
    if (emoji != null && mounted) {
      setState(() {
        _emoji = emoji;
        _avatarPath = null;
        _avatarRemoved = true;
      });
    }
  }

  ImageProvider? _getAvatarImage() {
    if (_avatarRemoved) return null;
    if (_avatarPath != null) {
      final file = File(_avatarPath!);
      if (file.existsSync()) return FileImage(file);
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _avatarPath = result.files.single.path;
        _avatarRemoved = false;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.showError(context, t.agent.assistant.name_required);
      return;
    }

    setState(() => _saving = true);

    try {
      final service = ref.read(assistantServiceProvider);

      if (_isEditing) {
        await service.updateAssistant(
          id: widget.assistant!.id,
          name: name,
          emoji: _emoji,
          description: _descriptionController.text.trim(),
          systemPrompt: _promptController.text.trim(),
          avatarPath: _avatarPath != widget.assistant?.avatarPath
              ? _avatarPath
              : null,
          avatarRemoved: _avatarRemoved,
          contextWindow: _isUnlimitedContext ? -1 : _contextWindow.round(),
          isDefault: _isDefault,
          providerId: _selectedProviderId,
          modelId: _selectedModelId,
          clearModel: _selectedProviderId == null,
          compressTokenThreshold: _isCompressDisabled ? 0 : _compressThreshold.round(),
          truncateTokenThreshold: _isCompressDisabled ? 0 : _truncateThreshold.round(),
        );
      } else {
        await service.createAssistant(
          name: name,
          emoji: _emoji,
          description: _descriptionController.text.trim(),
          systemPrompt: _promptController.text.trim(),
          avatarPath: _avatarPath,
          contextWindow: _isUnlimitedContext ? -1 : _contextWindow.round(),
          isDefault: _isDefault,
          providerId: _selectedProviderId,
          modelId: _selectedModelId,
          compressTokenThreshold: _isCompressDisabled ? 0 : _compressThreshold.round(),
          truncateTokenThreshold: _isCompressDisabled ? 0 : _truncateThreshold.round(),
        );
      }

      // 刷新列表
      ref.invalidate(assistantListStreamProvider);
      ref.invalidate(assistantListProvider);
      ref.invalidate(defaultAssistantProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.agent.assistant.delete_confirm_title),
        content: Text(t.agent.assistant.delete_confirm_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final service = ref.read(assistantServiceProvider);
                await service.deleteAssistant(widget.assistant!.id);
                ref.invalidate(assistantListStreamProvider);
                ref.invalidate(assistantListProvider);
                ref.invalidate(defaultAssistantProvider);
                if (mounted) Navigator.of(context).pop(true);
              } catch (e) {
                if (mounted) {
                  AppToast.showError(context, '$e');
                }
              }
            },
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }
}
