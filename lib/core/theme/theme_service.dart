import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_config_service.dart';

class AppThemeState {
  final ThemeMode mode;
  final Color seedColor;

  const AppThemeState({required this.mode, required this.seedColor});

  AppThemeState copyWith({ThemeMode? mode, Color? seedColor}) {
    return AppThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

class ThemeNotifier extends Notifier<AppThemeState> {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keySeedColor = 'theme_seed_color';

  late SharedPreferences _prefs;

  @override
  AppThemeState build() {
    _prefs = ref.watch(sharedPreferencesProvider);

    final modeIndex = _prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    final colorValue =
        _prefs.getInt(_keySeedColor) ?? 0xFF137FEC; // Default Blue

    return AppThemeState(
      mode: ThemeMode.values[modeIndex],
      seedColor: Color(colorValue),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_keyThemeMode, mode.index);
    state = state.copyWith(mode: mode);
  }

  Future<void> setSeedColor(Color color) async {
    await _prefs.setInt(_keySeedColor, color.value);
    state = state.copyWith(seedColor: color);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeState>(
  ThemeNotifier.new,
);
