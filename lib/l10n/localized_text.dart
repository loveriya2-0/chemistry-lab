import 'package:flutter/foundation.dart';

import 'app_language.dart';

/// A piece of curriculum content in every supported language.
///
/// Every language is a required parameter, so new chapters, topics or
/// practicals cannot be added without their Hindi text.
@immutable
class LocalizedText {
  const LocalizedText({required this.en, required this.hi});

  final String en;
  final String hi;

  String of(AppLanguage language) => switch (language) {
        AppLanguage.en => en,
        AppLanguage.hi => hi,
      };
}
