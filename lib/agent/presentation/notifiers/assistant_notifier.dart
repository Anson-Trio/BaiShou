/// 伙伴管理状态
///
/// 管理 AI 伙伴的 CRUD 操作和列表展示

import 'dart:io';
import 'package:baishou/agent/database/agent_database.dart';
import 'package:baishou/agent/session/assistant_repository.dart';
import 'package:baishou/i18n/strings.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// 监听伙伴列表（Stream）
final assistantListStreamProvider = StreamProvider<List<AgentAssistant>>((ref) {
  final repo = ref.watch(assistantRepositoryProvider);
  return repo.watchAll();
});

/// 获取所有伙伴列表（一次性）
final assistantListProvider = FutureProvider<List<AgentAssistant>>((ref) {
  final repo = ref.watch(assistantRepositoryProvider);
  return repo.getAll();
});

/// 伙伴管理服务 Provider
final assistantServiceProvider = Provider<AssistantService>((ref) {
  final repo = ref.watch(assistantRepositoryProvider);
  return AssistantService(repo);
});

/// 伙伴管理服务（无状态，纯操作）
class AssistantService {
  final AssistantRepository _repo;
  static const _uuid = Uuid();

  AssistantService(this._repo);

  /// 创建伙伴
  Future<String> createAssistant({
    required String name,
    required String systemPrompt,
    String? avatarPath,
    String? emoji,
    String description = '',
    int contextWindow = 20,
    String? providerId,
    String? modelId,
    int compressTokenThreshold = 60000,
    int compressKeepTurns = 3,
  }) async {
    final id = _uuid.v4();

    String? savedAvatarPath;
    if (avatarPath != null) {
      savedAvatarPath = await _saveAvatar(id, avatarPath);
    }

    await _repo.insert(
      AgentAssistantsCompanion.insert(
        id: id,
        name: name,
        emoji: Value(emoji),
        description: Value(description),
        systemPrompt: Value(systemPrompt),
        avatarPath: Value(savedAvatarPath),
        contextWindow: Value(contextWindow),
        providerId: Value(providerId),
        modelId: Value(modelId),
        compressTokenThreshold: Value(compressTokenThreshold),
        compressKeepTurns: Value(compressKeepTurns),
      ),
    );

    return id;
  }

  /// 更新伙伴
  Future<void> updateAssistant({
    required String id,
    String? name,
    String? systemPrompt,
    String? avatarPath,
    bool? avatarRemoved,
    String? emoji,
    String? description,
    int? contextWindow,
    String? providerId,
    String? modelId,
    int? compressTokenThreshold,
    int? compressKeepTurns,
    bool clearModel = false,
  }) async {

    String? savedAvatarPath;
    if (avatarRemoved == true) {
      final existing = await _repo.get(id);
      if (existing?.avatarPath != null) {
        try {
          await File(existing!.avatarPath!).delete();
        } catch (_) {}
      }
    } else if (avatarPath != null) {
      savedAvatarPath = await _saveAvatar(id, avatarPath);
    }

    await _repo.updateAssistant(
      AgentAssistantsCompanion(
        id: Value(id),
        name: name != null ? Value(name) : const Value.absent(),
        emoji: emoji != null ? Value(emoji) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        systemPrompt: systemPrompt != null
            ? Value(systemPrompt)
            : const Value.absent(),
        avatarPath: avatarRemoved == true
            ? const Value(null)
            : (savedAvatarPath != null
                  ? Value(savedAvatarPath)
                  : const Value.absent()),
        contextWindow: contextWindow != null
            ? Value(contextWindow)
            : const Value.absent(),
        providerId: clearModel
            ? const Value(null)
            : (providerId != null ? Value(providerId) : const Value.absent()),
        modelId: clearModel
            ? const Value(null)
            : (modelId != null ? Value(modelId) : const Value.absent()),
        compressTokenThreshold: compressTokenThreshold != null
            ? Value(compressTokenThreshold)
            : const Value.absent(),
        compressKeepTurns: compressKeepTurns != null
            ? Value(compressKeepTurns)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 删除伙伴（不允许删除最后一个）
  Future<void> deleteAssistant(String id) async {
    final all = await _repo.getAll();
    if (all.length <= 1) {
      throw Exception(t.agent.assistant.keep_one_error);
    }
    final existing = await _repo.get(id);
    if (existing?.avatarPath != null) {
      try {
        await File(existing!.avatarPath!).delete();
      } catch (_) {}
    }
    await _repo.deleteById(id);
  }

  /// 确保至少有一个伙伴（首次启动时调用）
  Future<AgentAssistant> ensureAtLeastOneAssistant() async {
    final all = await _repo.getAll();
    if (all.isNotEmpty) {
      return all.first;
    }
    // 创建初始伙伴
    final id = await createAssistant(
      name: t.agent.assistant.default_assistant_name,
      emoji: '🍵',
      description: t.agent.assistant.default_assistant_desc,
      systemPrompt: '',
    );
    return (await _repo.get(id))!;
  }

  /// 保存头像到应用数据目录
  Future<String> _saveAvatar(String assistantId, String sourcePath) async {
    final sourceFile = File(sourcePath);
    final ext = sourcePath.split('.').last;
    final appDir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${appDir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    final targetPath = '${avatarsDir.path}/$assistantId.$ext';
    await sourceFile.copy(targetPath);
    return targetPath;
  }
}
