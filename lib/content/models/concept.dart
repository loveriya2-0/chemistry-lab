import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'review.dart';
import 'syllabus.dart' show Json;

enum ConceptType {
  concept,
  reaction,
  compound,
  law,
  process;

  static ConceptType parse(String value) => values.byName(value);
}

/// Board-independent chemistry content ("neutralisation" is the same in
/// every board). Topic notes point here by id; "related topics" are found
/// from those notes.
@immutable
class Concept {
  const Concept({
    required this.id,
    required this.type,
    required this.title,
    required this.sections,
    required this.equations,
    required this.labIds,
    required this.sources,
    required this.review,
    this.relatedConceptIds = const [],
  });

  factory Concept.fromJson(Json json) => Concept(
        id: json['id']! as String,
        type: ConceptType.parse(json['type']! as String),
        title: ContentText.fromJson(json['title']! as Json),
        sections: {
          for (final e in (json['sections']! as Json).entries)
            ConceptSection.values.byName(e.key): ContentText.fromJson(e.value! as Json),
        },
        equations: [for (final e in (json['equations'] as List<Object?>? ?? const [])) e! as String],
        labIds: [for (final e in (json['labIds'] as List<Object?>? ?? const [])) e! as String],
        relatedConceptIds: [for (final e in (json['relatedConceptIds'] as List<Object?>? ?? const [])) e! as String],
        sources: sourceRefsOf(json['sources']),
        review: reviewOf(json),
      );

  final String id;
  final ConceptType type;
  final ContentText title;
  final Map<ConceptSection, ContentText> sections;
  final List<String> equations;
  final List<String> labIds;
  final List<String> relatedConceptIds;
  final List<SourceRef> sources;
  final ReviewStatus review;

  bool get isPublishable => review.isPublishable;
}

/// The learning sections shown on a concept page, in display order.
enum ConceptSection {
  whatIsIt,
  howItWorks,
  whyImportant,
  realLifeUses,
  keyObservations,

  /// Exam relevance: what students must be able to write or do.
  rememberForExam,
  commonMistakes,
}
