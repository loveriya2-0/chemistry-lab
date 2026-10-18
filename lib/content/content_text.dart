import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';

/// Where a Hindi string came from, so unreviewed text can be flagged.
enum HindiSource {
  /// Copied from an NCERT Hindi textbook.
  ncert,

  /// Decoded from an NCERT Hindi PDF's legacy font and proofread.
  ncertDecoded,

  /// Written by us; needs review by a Hindi-medium teacher.
  translated;

  static HindiSource? parse(String? value) => switch (value) {
        'ncert' => ncert,
        'ncert-decoded' => ncertDecoded,
        'translated' => translated,
        null => null,
        _ => throw FormatException('Unknown hiSrc "$value"'),
      };
}

/// Bilingual text loaded from content files.
///
/// Unlike the compile-time [LocalizedText], Hindi may be missing for content
/// that is still being prepared; [of] then falls back to English.
@immutable
class ContentText {
  const ContentText({required this.en, this.hi, this.hiSource});

  factory ContentText.fromJson(Map<String, Object?> json) => ContentText(
        en: json['en']! as String,
        hi: json['hi'] as String?,
        hiSource: HindiSource.parse(json['hiSrc'] as String?),
      );

  final String en;
  final String? hi;
  final HindiSource? hiSource;

  bool get hasHindi => hi != null && hi!.isNotEmpty;

  String of(AppLanguage language) => switch (language) {
        AppLanguage.en => en,
        AppLanguage.hi => hasHindi ? hi! : en,
      };
}

/// Reads an optional [ContentText] field.
ContentText? contentTextOrNull(Object? json) =>
    json == null ? null : ContentText.fromJson(json as Map<String, Object?>);
