import 'package:baishou/features/settings/domain/services/user_profile_service.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 身份卡设置卡片
class IdentitySettingsCard extends ConsumerStatefulWidget {
  const IdentitySettingsCard({super.key});

  @override
  ConsumerState<IdentitySettingsCard> createState() =>
      _IdentitySettingsCardState();
}

class _IdentitySettingsCardState extends ConsumerState<IdentitySettingsCard> {
  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final facts = userProfile.identityFacts;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  t.settings.identity_card,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  tooltip: t.settings.add_identity_entry,
                  onPressed: () => _showIdentityEntryDialog(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t.settings.identity_card_desc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // --- 多身份卡选项卡区 ---
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...userProfile.personas.keys.map((personaId) {
                    final isActive = personaId == userProfile.activePersonaId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(personaId),
                        selected: isActive,
                        showCheckmark: false,
                        onSelected: (val) {
                          if (val && !isActive) {
                            ref.read(userProfileProvider.notifier).setActivePersona(personaId);
                          } else if (isActive) {
                            // 点击当前的重命名
                            _showRenamePersonaDialog(personaId);
                          }
                        },
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: userProfile.personas.length > 1
                            ? () => _confirmDeletePersona(personaId)
                            : null, // 至少保留一张
                      ),
                    );
                  }),
                  ActionChip(
                    label: const Text('新建身份'), // 借用通用或硬编码，原 i18n 无此翻译
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: _showAddPersonaDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (facts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.settings.identity_card_empty_hint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...facts.entries.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.label_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(entry.value),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        onPressed: () => _showIdentityEntryDialog(
                          existingKey: entry.key,
                          existingValue: entry.value,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () => _confirmDeleteFact(entry.key),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPersonaDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建身份卡'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '例如: 工作, 旅行, 运动'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(t.common.save),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(userProfileProvider.notifier).addPersona(name);
    }
  }

  Future<void> _showRenamePersonaDialog(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名身份卡'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入新的身份名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(t.common.save),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != oldName) {
      await ref.read(userProfileProvider.notifier).renamePersona(oldName, newName);
    }
  }

  Future<void> _confirmDeletePersona(String personaId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除身份卡: $personaId'),
        content: const Text('确定要删除这个身份卡吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(userProfileProvider.notifier).removePersona(personaId);
    }
  }

  Future<void> _showIdentityEntryDialog({
    String? existingKey,
    String? existingValue,
  }) async {
    final keyController = TextEditingController(text: existingKey ?? '');
    final valueController = TextEditingController(text: existingValue ?? '');
    final isEditing = existingKey != null;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing
              ? t.settings.edit_identity_entry
              : t.settings.add_identity_entry,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: InputDecoration(
                labelText: t.settings.identity_key,
                hintText: t.settings.identity_key_hint,
              ),
              enabled: !isEditing,
              autofocus: !isEditing,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: t.settings.identity_value,
                hintText: t.settings.identity_value_hint,
              ),
              autofocus: isEditing,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              if (key.isNotEmpty && value.isNotEmpty) {
                Navigator.pop(context, {'key': key, 'value': value});
              }
            },
            child: Text(t.common.save),
          ),
        ],
      ),
    );

    if (result != null) {
      if (isEditing && existingKey != result['key']) {
        await ref.read(userProfileProvider.notifier).removeFact(existingKey);
      }
      await ref
          .read(userProfileProvider.notifier)
          .addFact(result['key']!, result['value']!);
    }
  }

  Future<void> _confirmDeleteFact(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.settings.delete_identity_confirm(key: key)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(userProfileProvider.notifier).removeFact(key);
    }
  }
}
