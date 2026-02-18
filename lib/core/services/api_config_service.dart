import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { gemini, openai }

class ApiConfigService {
  static const String _keyProvider = 'ai_provider';
  static const String _keyGeminiBaseUrl = 'gemini_base_url';
  static const String _keyOpenAiBaseUrl = 'openai_base_url';
  static const String _keyGeminiApiKey = 'gemini_api_key';
  static const String _keyOpenAiApiKey = 'openai_api_key';
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

  String get geminiBaseUrl => _prefs.getString(_keyGeminiBaseUrl) ?? '';
  String get openAiBaseUrl => _prefs.getString(_keyOpenAiBaseUrl) ?? '';

  String get baseUrl {
    if (provider == AiProvider.gemini) {
      return geminiBaseUrl;
    }
    return openAiBaseUrl;
  }

  String get geminiApiKey => _prefs.getString(_keyGeminiApiKey) ?? '';
  String get openAiApiKey => _prefs.getString(_keyOpenAiApiKey) ?? '';

  String get apiKey {
    if (provider == AiProvider.gemini) {
      return geminiApiKey;
    }
    return openAiApiKey;
  }

  String get model {
    final val = _prefs.getString(_keyModel);
    if (val != null && val.isNotEmpty) return val;
    // Default values
    if (provider == AiProvider.gemini) return 'gemini-3-flash-preview';
    return ''; // OpenAI default empty
  }

  Future<void> setProvider(AiProvider provider) async {
    await _prefs.setString(_keyProvider, provider.name);
  }

  Future<void> setBaseUrl(String value) async {
    if (provider == AiProvider.gemini) {
      await _prefs.setString(_keyGeminiBaseUrl, value);
    } else {
      await _prefs.setString(_keyOpenAiBaseUrl, value);
    }
  }

  Future<void> setGeminiBaseUrl(String value) async {
    await _prefs.setString(_keyGeminiBaseUrl, value);
  }

  Future<void> setOpenAiBaseUrl(String value) async {
    await _prefs.setString(_keyOpenAiBaseUrl, value);
  }

  Future<void> setApiKey(String value) async {
    if (provider == AiProvider.gemini) {
      await _prefs.setString(_keyGeminiApiKey, value);
    } else {
      await _prefs.setString(_keyOpenAiApiKey, value);
    }
  }

  Future<void> setGeminiApiKey(String value) async {
    await _prefs.setString(_keyGeminiApiKey, value);
  }

  Future<void> setOpenAiApiKey(String value) async {
    await _prefs.setString(_keyOpenAiApiKey, value);
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
