import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider {
  gemini,
  openai,
}

class ApiConfigService {
  static const String _keyProvider = 'ai_provider';
  static const String _keyBaseUrl = 'api_base_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyModel = 'api_model';

  final SharedPreferences _prefs;

  ApiConfigService(this._prefs);

  AiProvider get provider {
    final value = _prefs.getString(_keyProvider);
    return AiProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AiProvider.gemini,
    );
  }

  String get baseUrl => _prefs.getString(_keyBaseUrl) ?? '';
  String get apiKey => _prefs.getString(_keyApiKey) ?? '';
  String get model => _prefs.getString(_keyModel) ?? '';

  Future<void> setProvider(AiProvider provider) async {
    await _prefs.setString(_keyProvider, provider.name);
  }

  Future<void> setBaseUrl(String value) async {
    await _prefs.setString(_keyBaseUrl, value);
  }

  Future<void> setApiKey(String value) async {
    await _prefs.setString(_keyApiKey, value);
  }

  Future<void> setModel(String value) async {
    await _prefs.setString(_keyModel, value);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final apiConfigServiceProvider = Provider<ApiConfigService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiConfigService(prefs);
});
