import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_language.dart';

/// Holds the UI language and remembers it across launches.
///
/// With no saved choice, Hindi devices start in Hindi and everyone else in
/// English.
class LanguageController extends ChangeNotifier {
  LanguageController(this._prefs)
      : _language = _prefs.containsKey(_key)
            ? AppLanguage.fromCode(_prefs.getString(_key))
            : AppLanguage.fromCode(PlatformDispatcher.instance.locale.languageCode);

  static const _key = 'app_language';

  final SharedPreferences _prefs;
  AppLanguage _language;

  AppLanguage get language => _language;

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    _prefs.setString(_key, language.code);
  }

  /// Cycles to the next language (EN ⇄ HI with two languages).
  void toggle() => setLanguage(
        AppLanguage.values[(_language.index + 1) % AppLanguage.values.length],
      );
}
