import 'package:flutter/foundation.dart';

import 'syllabus.dart' show Json;

/// How far a piece of learning content has been checked.
enum ReviewStatus {
  draft,
  needsReview,

  /// Written by us from the cited official source (NCERT text, CBSE paper
  /// or marking scheme) and checked against it; not yet reviewed by a
  /// subject teacher.
  sourceChecked,

  /// Reviewed by a subject teacher.
  verified;

  static ReviewStatus parse(String? value) => switch (value) {
        null || 'draft' => draft,
        'needsReview' => needsReview,
        'sourceChecked' => sourceChecked,
        'verified' => verified,
        _ => throw FormatException('Unknown review status "$value"'),
      };

  /// Only checked content is shown to students.
  bool get isPublishable => this == sourceChecked || this == verified;
}

/// Reads `{"review": {"status": …}}`.
ReviewStatus reviewOf(Json json) => ReviewStatus.parse((json['review'] as Json?)?['status'] as String?);

/// A pointer into a curriculum source ("ncert-10-en", section "2.3").
@immutable
class SourceRef {
  const SourceRef({required this.sourceId, this.section});

  factory SourceRef.fromJson(Json json) =>
      SourceRef(sourceId: json['sourceId']! as String, section: json['section'] as String?);

  final String sourceId;

  /// Textbook section, activity or question number, if any.
  final String? section;
}

List<SourceRef> sourceRefsOf(Object? json) =>
    [for (final s in (json as List<Object?>? ?? const [])) SourceRef.fromJson(s! as Json)];
