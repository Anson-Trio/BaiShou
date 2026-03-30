import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

import '../../../../core/providers/shared_preferences_provider.dart';
import 'package:baishou/i18n/strings.g.dart';

class UserProfile {
  final String nickname;
  final String? avatarPath;
  final String activePersonaId;
  final Map<String, Map<String, String>> personas;

  const UserProfile({
    required this.nickname,
    this.avatarPath,
    this.activePersonaId = '默认身份',
    this.personas = const {},
  });

  Map<String, String> get identityFacts => personas[activePersonaId] ?? {};

  UserProfile copyWith({
    String? nickname,
    String? avatarPath,
    String? activePersonaId,
    Map<String, Map<String, String>>? personas,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      avatarPath: avatarPath ?? this.avatarPath,
      activePersonaId: activePersonaId ?? this.activePersonaId,
      personas: personas ?? this.personas,
    );
  }

  /// 将当前身份卡序列化为 Markdown 格式，用于注入 System Prompt
  String toMarkdownBlock() {
    final facts = identityFacts;
    if (facts.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('### User Profile');
    for (final entry in facts.entries) {
      buffer.writeln('- **${entry.key}**: ${entry.value}');
    }
    return buffer.toString();
  }
}

class UserProfileNotifier extends Notifier<UserProfile> {
  static const String _keyNickname = 'user_nickname';
  static const String _keyAvatarPath = 'user_avatar_path';
  static const String _keyIdentityFacts = 'user_identity_facts'; // 旧版单卡口
  static const String _keyPersonas = 'user_personas';
  static const String _keyActivePersonaId = 'user_active_persona_id';
  late SharedPreferences _prefs;

  @override
  UserProfile build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    
    // 加载并向下兼容旧数据
    Map<String, Map<String, String>> loadedPersonas = _loadPersonas();
    if (loadedPersonas.isEmpty) {
       final legacyFacts = _loadLegacyFacts();
       loadedPersonas = {'默认身份': legacyFacts};
       _savePersonas(loadedPersonas);
    }
    
    String activeId = _prefs.getString(_keyActivePersonaId) ?? '默认身份';
    if (!loadedPersonas.containsKey(activeId)) {
        activeId = loadedPersonas.keys.first;
    }

    return UserProfile(
      nickname: _prefs.getString(_keyNickname) ?? t.settings.default_nickname,
      avatarPath: _prefs.getString(_keyAvatarPath),
      activePersonaId: activeId,
      personas: loadedPersonas,
    );
  }

  Map<String, String> _loadLegacyFacts() {
    final jsonStr = _prefs.getString(_keyIdentityFacts);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  Map<String, Map<String, String>> _loadPersonas() {
    final jsonStr = _prefs.getString(_keyPersonas);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = <String, Map<String, String>>{};
      decoded.forEach((key, value) {
        if (value is Map) {
          result[key] = value.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePersonas(Map<String, Map<String, String>> personas) async {
    await _prefs.setString(_keyPersonas, jsonEncode(personas));
  }

  Future<void> updateNickname(String nickname) async {
    await _prefs.setString(_keyNickname, nickname);
    state = state.copyWith(nickname: nickname);
  }

  // --- 多身份卡管理逻辑 ---

  Future<void> setActivePersona(String personaId) async {
    if (!state.personas.containsKey(personaId)) return;
    await _prefs.setString(_keyActivePersonaId, personaId);
    state = state.copyWith(activePersonaId: personaId);
  }

  Future<void> addPersona(String personaId) async {
    if (state.personas.containsKey(personaId)) return;
    final updated = Map<String, Map<String, String>>.from(state.personas);
    updated[personaId] = {};
    await _savePersonas(updated);
    state = state.copyWith(personas: updated);
    await setActivePersona(personaId);
  }

  Future<void> removePersona(String personaId) async {
    if (state.personas.length <= 1) return; // 至少保留一张
    final updated = Map<String, Map<String, String>>.from(state.personas);
    updated.remove(personaId);
    await _savePersonas(updated);
    
    String activeId = state.activePersonaId;
    if (activeId == personaId) {
      activeId = updated.keys.first;
      await _prefs.setString(_keyActivePersonaId, activeId);
    }
    state = state.copyWith(personas: updated, activePersonaId: activeId);
  }

  Future<void> renamePersona(String oldId, String newId) async {
    if (oldId == newId || state.personas.containsKey(newId)) return;
    final updated = Map<String, Map<String, String>>.from(state.personas);
    final facts = updated.remove(oldId)!;
    updated[newId] = facts;
    await _savePersonas(updated);
    
    String activeId = state.activePersonaId;
    if (activeId == oldId) {
      activeId = newId;
      await _prefs.setString(_keyActivePersonaId, activeId);
    }
    state = state.copyWith(personas: updated, activePersonaId: activeId);
  }

  /// 复制身份卡
  Future<void> duplicatePersona(String sourceId, String newId) async {
    if (state.personas.containsKey(newId) || !state.personas.containsKey(sourceId)) return;
    final updated = Map<String, Map<String, String>>.from(state.personas);
    updated[newId] = Map<String, String>.from(updated[sourceId]!);
    await _savePersonas(updated);
    state = state.copyWith(personas: updated);
    await setActivePersona(newId);
  }

  // --- 当前活动身份卡的增删查改 ---

  /// 添加或更新当前活动身份卡的一条事实
  Future<void> addFact(String key, String value) async {
    final updatedPersonas = Map<String, Map<String, String>>.from(state.personas);
    final facts = Map<String, String>.from(updatedPersonas[state.activePersonaId] ?? {});
    facts[key] = value;
    updatedPersonas[state.activePersonaId] = facts;
    await _savePersonas(updatedPersonas);
    state = state.copyWith(personas: updatedPersonas);
  }

  /// 删除当前活动身份卡的一条事实
  Future<void> removeFact(String key) async {
    final updatedPersonas = Map<String, Map<String, String>>.from(state.personas);
    final facts = Map<String, String>.from(updatedPersonas[state.activePersonaId] ?? {});
    facts.remove(key);
    updatedPersonas[state.activePersonaId] = facts;
    await _savePersonas(updatedPersonas);
    state = state.copyWith(personas: updatedPersonas);
  }

  /// 批量更新当前活动身份卡的所有事实
  Future<void> updateAllFacts(Map<String, String> facts) async {
    final updatedPersonas = Map<String, Map<String, String>>.from(state.personas);
    updatedPersonas[state.activePersonaId] = facts;
    await _savePersonas(updatedPersonas);
    state = state.copyWith(personas: updatedPersonas);
  }

  Future<void> updateAvatar(File newAvatar) async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(path.join(appDir.path, 'avatars'));

    if (!avatarDir.existsSync()) {
      await avatarDir.create(recursive: true);
    }

    final fileName =
        'avatar_${DateTime.now().millisecondsSinceEpoch}${path.extension(newAvatar.path)}';
    final savedImage = await newAvatar.copy(
      path.join(avatarDir.path, fileName),
    );

    // 如果存在旧头像且不同，则删除
    if (state.avatarPath != null) {
      final oldFile = File(state.avatarPath!);
      if (oldFile.existsSync()) {
        try {
          await oldFile.delete();
        } catch (e) {
          // ignore error
        }
      }
    }

    await _prefs.setString(_keyAvatarPath, savedImage.path);
    state = state.copyWith(avatarPath: savedImage.path);
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
