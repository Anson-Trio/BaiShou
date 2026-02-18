import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

import '../../../../core/services/api_config_service.dart';

class UserProfile {
  final String nickname;
  final String? avatarPath;

  const UserProfile({required this.nickname, this.avatarPath});

  UserProfile copyWith({String? nickname, String? avatarPath}) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfile> {
  static const String _keyNickname = 'user_nickname';
  static const String _keyAvatarPath = 'user_avatar_path';
  late SharedPreferences _prefs;

  @override
  UserProfile build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return UserProfile(
      nickname: _prefs.getString(_keyNickname) ?? '白守用户',
      avatarPath: _prefs.getString(_keyAvatarPath),
    );
  }

  Future<void> updateNickname(String nickname) async {
    await _prefs.setString(_keyNickname, nickname);
    state = state.copyWith(nickname: nickname);
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
        // 可选：删除旧头像以节省空间
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
