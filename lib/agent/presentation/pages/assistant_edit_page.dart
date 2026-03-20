/// 助手编辑页面（创建 / 编辑）
///
/// 独立页面，支持移动端和桌面端

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/presentation/notifiers/assistant_notifier.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  double _contextWindow = 20;
  bool _isDefault = false;
  String? _avatarPath;
  bool _avatarRemoved = false;
  bool _saving = false;

  bool get _isEditing => widget.assistant != null;

  @override
  void initState() {
    super.initState();
    final a = widget.assistant;
    _nameController = TextEditingController(text: a?.name ?? '');
    _promptController = TextEditingController(text: a?.systemPrompt ?? '');
    _contextWindow = (a?.contextWindow ?? 20).toDouble();
    _isDefault = a?.isDefault ?? false;
    _avatarPath = a?.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
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
          if (_isEditing)
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
                // ── 头像 ──
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          backgroundImage: _getAvatarImage(),
                          child: _getAvatarImage() == null
                              ? Icon(Icons.smart_toy_rounded,
                                  size: 40, color: colorScheme.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primary,
                            child: Icon(Icons.camera_alt,
                                size: 16, color: colorScheme.onPrimary),
                          ),
                        ),
                      ],
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

                // ── 上下文轮数 ──
                Row(
                  children: [
                    Text(t.agent.assistant.context_window_label,
                        style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text('${_contextWindow.round()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        )),
                  ],
                ),
                Slider(
                  value: _contextWindow,
                  min: 2,
                  max: 100,
                  divisions: 49,
                  label: '${_contextWindow.round()}',
                  onChanged: (v) => setState(() => _contextWindow = v),
                ),
                Text(t.agent.assistant.context_window_desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    )),

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.agent.assistant.name_required)),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final service = ref.read(assistantServiceProvider);

      if (_isEditing) {
        await service.updateAssistant(
          id: widget.assistant!.id,
          name: name,
          systemPrompt: _promptController.text.trim(),
          avatarPath: _avatarPath != widget.assistant?.avatarPath
              ? _avatarPath
              : null,
          avatarRemoved: _avatarRemoved,
          contextWindow: _contextWindow.round(),
          isDefault: _isDefault,
        );
      } else {
        await service.createAssistant(
          name: name,
          systemPrompt: _promptController.text.trim(),
          avatarPath: _avatarPath,
          contextWindow: _contextWindow.round(),
          isDefault: _isDefault,
        );
      }

      // 刷新列表
      ref.invalidate(assistantListStreamProvider);
      ref.invalidate(assistantListProvider);
      ref.invalidate(defaultAssistantProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
              final service = ref.read(assistantServiceProvider);
              await service.deleteAssistant(widget.assistant!.id);
              ref.invalidate(assistantListStreamProvider);
              ref.invalidate(assistantListProvider);
              ref.invalidate(defaultAssistantProvider);
              if (mounted) Navigator.of(context).pop(true);
            },
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }
}
