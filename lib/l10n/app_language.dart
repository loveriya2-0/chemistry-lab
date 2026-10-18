import 'package:flutter/widgets.dart';

/// Languages the app ships with.
///
/// To add a language: add a value here, a field to [LocalizedText], and an
/// [AppStrings] subclass. The compiler then points at every missing string.
enum AppLanguage {
  en('en', 'English', 'EN'),
  hi('hi', 'हिंदी', 'हिं');

  const AppLanguage(this.code, this.nativeName, this.shortName);

  /// ISO 639-1 code, also used as the persisted value.
  final String code;

  /// The language's name written in itself, for the switcher.
  final String nativeName;

  /// Two-to-three letter label for compact switches.
  final String shortName;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => en);
}
