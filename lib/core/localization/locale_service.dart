import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/strings.g.dart';
import '../providers/shared_preferences_provider.dart';

class LocaleNotifier extends Notifier<AppLocale?> {
  static const String _keyLocale = 'app_locale';

  late SharedPreferences _prefs;

  @override
  AppLocale? build() {
    _prefs = ref.watch(sharedPreferencesProvider);

    final localeTag = _prefs.getString(_keyLocale);
    if (localeTag == null) {
      // Use device locale by default
      LocaleSettings.useDeviceLocale();
      return null;
    }

    try {
      final locale = AppLocaleUtils.parse(localeTag);
      // Immediately apply the locale to slang
      LocaleSettings.setLocale(locale);
      return locale;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLocale(AppLocale? locale) async {
    if (locale == null) {
      await _prefs.remove(_keyLocale);
      LocaleSettings.useDeviceLocale();
    } else {
      await _prefs.setString(
        _keyLocale,
        locale.languageCode +
            (locale.countryCode != null ? '-${locale.countryCode}' : ''),
      );
      LocaleSettings.setLocale(locale);
    }
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale?>(
  LocaleNotifier.new,
);
