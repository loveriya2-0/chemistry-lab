import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'syllabus.dart' show Json;

/// How much of a practical in the board's list the app can do.
enum PracticalLevel {
  /// Every part of the listed procedure is a working virtual lab.
  fullyInteractive,

  /// Some parts are working virtual labs; the rest is not simulated.
  partiallyInteractive,

  /// A written guide but no virtual lab.
  guideOnly,

  /// Nothing yet (at most a related lab that is not part of it).
  notImplemented;

  static PracticalLevel parse(String value) => switch (value) {
        'fullyInteractive' => fullyInteractive,
        'partiallyInteractive' => partiallyInteractive,
        'guideOnly' => guideOnly,
        'notImplemented' => notImplemented,
        _ => throw FormatException('Unknown practical level "$value"'),
      };
}

/// The manifest's statement of what a listed practical can do in the app,
/// written by us and checked by the validator against the linked labs.
@immutable
class PracticalCoverage {
  const PracticalCoverage({required this.practicalId, required this.level, required this.covered, this.notCovered});

  factory PracticalCoverage.fromJson(Json json) => PracticalCoverage(
        practicalId: json['practicalId']! as String,
        level: PracticalLevel.parse(json['level']! as String),
        covered: ContentText.fromJson(json['covered']! as Json),
        notCovered: contentTextOrNull(json['notCovered']),
      );

  final String practicalId;
  final PracticalLevel level;

  /// The parts that can be done in a virtual lab.
  final ContentText covered;

  /// The parts that are not simulated; null only when fully interactive.
  final ContentText? notCovered;
}

/// A listed practical's status as shown to students.
@immutable
class PracticalStatus {
  const PracticalStatus({required this.level, required this.labIds, this.coverage});

  final PracticalLevel level;

  /// Virtual labs linked to the practical (parts of it, or related).
  final List<String> labIds;
  final PracticalCoverage? coverage;
}
