import 'package:flutter/foundation.dart';

import '../content/models/review.dart';
import '../l10n/localized_text.dart';

/// The verified reaction behind a reaction-engine lab, shown when the
/// experiment is complete.
@immutable
class ReactionInfo {
  const ReactionInfo({
    required this.kind,
    required this.equation,
    required this.reactants,
    required this.products,
    required this.whatHappened,
    required this.why,
    required this.realLife,
    required this.examPoint,
    required this.sources,
    required this.review,
  });

  /// "Displacement reaction", "Decomposition reaction", …
  final LocalizedText kind;

  /// Balanced equation, exactly as in the source-checked notes.
  final String equation;
  final List<LocalizedText> reactants;
  final List<LocalizedText> products;
  final LocalizedText whatHappened;
  final LocalizedText why;
  final LocalizedText realLife;

  /// What to write in the exam (the PYQ-based importance is computed
  /// separately, never stored here).
  final LocalizedText examPoint;
  final List<SourceRef> sources;
  final ReviewStatus review;
}
