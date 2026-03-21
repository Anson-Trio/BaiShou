/// 助手管理状态
///
/// 管理 AI 助手的 CRUD 操作和列表展示

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// 监听助手列表（Stream）
final assistantListStreamProvider = StreamProvider<List<AgentAssistant>>((ref) {
  final repo = ref.watch(assistantRepositoryProvider);
  return repo.watchAll();
});

/// 获取所有助手列表（一次性）
final assistantListProvider = FutureProvider<List<AgentAssistant>>((ref) {
  final repo = ref.watch(assistantRepositoryProvider);
  return repo.getAll();
});

/// 获取默认助手
final defaultAssistantProvider = FutureProvider<AgentAssistant?>((ref) {
  final repo = ref.watch(assistantRepositoryProvider);
  return repo.getDefault();
});

/// 助手管理服务 Provider
final assistantServiceProvider = Provider<AssistantService>((ref) {
  final repo = ref.watch(assistantRepositoryProvider);
  return AssistantService(repo);
});

/// 助手管理服务（无状态，纯操作）
class AssistantService {
  final AssistantRepository _repo;
  static const _uuid = Uuid();

  AssistantService(this._repo);

  /// 创建助手
  Future<String> createAssistant({
    required String name,
    required String systemPrompt,
    String? avatarPath,
    String? emoji,
    String description = '',
    int contextWindow = 20,
    bool isDefault = false,
    String? providerId,
    String? modelId,
    int compressTokenThreshold = 8000,
    int truncateTokenThreshold = 4000,
  }) async {
    final id = _uuid.v4();

    if (isDefault) {
      await _repo.clearDefault();
    }

    String? savedAvatarPath;
    if (avatarPath != null) {
      savedAvatarPath = await _saveAvatar(id, avatarPath);
    }

    await _repo.insert(AgentAssistantsCompanion.insert(
      id: id,
      name: name,
      emoji: Value(emoji),
      description: Value(description),
      systemPrompt: Value(systemPrompt),
      avatarPath: Value(savedAvatarPath),
      contextWindow: Value(contextWindow),
      isDefault: Value(isDefault),
      providerId: Value(providerId),
      modelId: Value(modelId),
      compressTokenThreshold: Value(compressTokenThreshold),
      truncateTokenThreshold: Value(truncateTokenThreshold),
    ));

    return id;
  }

  /// 更新助手
  Future<void> updateAssistant({
    required String id,
    String? name,
    String? systemPrompt,
    String? avatarPath,
    bool? avatarRemoved,
    String? emoji,
    String? description,
    int? contextWindow,
    bool? isDefault,
    String? providerId,
    String? modelId,
    int? compressTokenThreshold,
    int? truncateTokenThreshold,
    bool clearModel = false,
  }) async {
    if (isDefault == true) {
      await _repo.clearDefault();
    }

    String? savedAvatarPath;
    if (avatarRemoved == true) {
      final existing = await _repo.get(id);
      if (existing?.avatarPath != null) {
        try { await File(existing!.avatarPath!).delete(); } catch (_) {}
      }
    } else if (avatarPath != null) {
      savedAvatarPath = await _saveAvatar(id, avatarPath);
    }

    await _repo.updateAssistant(AgentAssistantsCompanion(
      id: Value(id),
      name: name != null ? Value(name) : const Value.absent(),
      emoji: emoji != null ? Value(emoji) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      systemPrompt: systemPrompt != null ? Value(systemPrompt) : const Value.absent(),
      avatarPath: avatarRemoved == true
          ? const Value(null)
          : (savedAvatarPath != null ? Value(savedAvatarPath) : const Value.absent()),
      contextWindow: contextWindow != null ? Value(contextWindow) : const Value.absent(),
      isDefault: isDefault != null ? Value(isDefault) : const Value.absent(),
      providerId: clearModel ? const Value(null) : (providerId != null ? Value(providerId) : const Value.absent()),
      modelId: clearModel ? const Value(null) : (modelId != null ? Value(modelId) : const Value.absent()),
      compressTokenThreshold: compressTokenThreshold != null ? Value(compressTokenThreshold) : const Value.absent(),
      truncateTokenThreshold: truncateTokenThreshold != null ? Value(truncateTokenThreshold) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 删除助手（不允许删除最后一个）
  Future<void> deleteAssistant(String id) async {
    final all = await _repo.getAll();
    if (all.length <= 1) {
      throw Exception('至少保留一个助手');
    }
    final existing = await _repo.get(id);
    if (existing?.avatarPath != null) {
      try { await File(existing!.avatarPath!).delete(); } catch (_) {}
    }
    await _repo.deleteById(id);
    // 如果删的是默认，把第一个设为默认
    if (existing?.isDefault == true) {
      final remaining = await _repo.getAll();
      if (remaining.isNotEmpty) {
        await _repo.setDefault(remaining.first.id);
      }
    }
  }

  /// 确保至少有一个助手（首次启动时调用）
  Future<AgentAssistant> ensureDefaultAssistant() async {
    final existing = await _repo.getDefault();
    if (existing != null) return existing;
    final all = await _repo.getAll();
    if (all.isNotEmpty) {
      await _repo.setDefault(all.first.id);
      return all.first;
    }
    // 创建默认助手
    final id = await createAssistant(
      name: '默认助手',
      emoji: '⭐',
      description: '通用 AI 助手',
      systemPrompt: '',
      isDefault: true,
    );
    return (await _repo.get(id))!;
  }

  /// 设置默认助手
  Future<void> setDefault(String id) async {
    await _repo.setDefault(id);
  }

  /// 保存头像到应用数据目录
  Future<String> _saveAvatar(String assistantId, String sourcePath) async {
    final sourceFile = File(sourcePath);
    final ext = sourcePath.split('.').last;
    final appDir = sourceFile.parent.parent;
    final avatarsDir = Directory('${appDir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    final targetPath = '${avatarsDir.path}/$assistantId.$ext';
    await sourceFile.copy(targetPath);
    return targetPath;
  }
}
