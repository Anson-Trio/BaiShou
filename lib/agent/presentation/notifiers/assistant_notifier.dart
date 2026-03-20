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
    int contextWindow = 20,
    bool isDefault = false,
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
      systemPrompt: Value(systemPrompt),
      avatarPath: Value(savedAvatarPath),
      contextWindow: Value(contextWindow),
      isDefault: Value(isDefault),
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
    int? contextWindow,
    bool? isDefault,
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
      systemPrompt: systemPrompt != null ? Value(systemPrompt) : const Value.absent(),
      avatarPath: avatarRemoved == true
          ? const Value(null)
          : (savedAvatarPath != null ? Value(savedAvatarPath) : const Value.absent()),
      contextWindow: contextWindow != null ? Value(contextWindow) : const Value.absent(),
      isDefault: isDefault != null ? Value(isDefault) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 删除助手
  Future<void> deleteAssistant(String id) async {
    final existing = await _repo.get(id);
    if (existing?.avatarPath != null) {
      try { await File(existing!.avatarPath!).delete(); } catch (_) {}
    }
    await _repo.deleteById(id);
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
