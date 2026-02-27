import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../i18n/strings.g.dart';
import '../providers/shared_preferences_provider.dart';

class LocaleNotifier extends Notifier<AppLocale> {
  static const String _keyLocale = 'app_locale';

  late SharedPreferences _prefs;

  @override
  AppLocale build() {
    _prefs = ref.watch(sharedPreferencesProvider);

    final localeTag = _prefs.getString(_keyLocale);
    if (localeTag == null) {
      // main.dart has already called useDeviceLocale(), so this is now safe
      return LocaleSettings.instance.currentLocale;
    }

    try {
      final locale = AppLocaleUtils.parse(localeTag);
      // main.dart has already loaded this, so currentLocale should match
      return locale;
    } catch (_) {
      return LocaleSettings.instance.currentLocale;
    }
  }

  Future<void> setLocale(AppLocale? locale) async {
    if (locale == null) {
      await _prefs.remove(_keyLocale);
      state = await LocaleSettings.useDeviceLocale();
    } else {
      await _prefs.setString(
        _keyLocale,
        locale.languageCode +
            (locale.countryCode != null ? '-${locale.countryCode}' : ''),
      );
      await LocaleSettings.setLocale(locale);
      state = locale;
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);
