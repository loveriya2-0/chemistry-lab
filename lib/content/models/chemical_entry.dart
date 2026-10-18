import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'review.dart';
import 'syllabus.dart' show Json;

enum ChemicalKind {
  compound,
  element,
  reaction;

  static ChemicalKind parse(String value) => values.byName(value);
}

/// Board-independent card for one chemical or one named reaction.
///
/// Topics link here through their notes, so "related topics" are found by
/// looking up which notes mention the entry.
@immutable
class ChemicalEntry {
  const ChemicalEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.formula,
    required this.properties,
    required this.uses,
    required this.equations,
    required this.explanation,
    required this.practicalNote,
    required this.sources,
    required this.review,
  });

  factory ChemicalEntry.fromJson(Json json) => ChemicalEntry(
        id: json['id']! as String,
        kind: ChemicalKind.parse(json['kind']! as String),
        name: ContentText.fromJson(json['name']! as Json),
        formula: json['formula'] as String?,
        properties: [for (final p in (json['properties'] as List<Object?>? ?? const [])) ContentText.fromJson(p! as Json)],
        uses: [for (final u in (json['uses'] as List<Object?>? ?? const [])) ContentText.fromJson(u! as Json)],
        equations: [for (final e in (json['equations'] as List<Object?>? ?? const [])) e! as String],
        explanation: ContentText.fromJson(json['explanation']! as Json),
        practicalNote: contentTextOrNull(json['practicalNote']),
        sources: sourceRefsOf(json['sources']),
        review: reviewOf(json),
      );

  final String id;
  final ChemicalKind kind;
  final ContentText name;

  /// Chemical formula for a compound or element; null for a reaction.
  final String? formula;
  final List<ContentText> properties;
  final List<ContentText> uses;

  /// Balanced equations, in display form.
  final List<String> equations;
  final ContentText explanation;

  /// How the chemical or reaction appears in a school practical.
  final ContentText? practicalNote;
  final List<SourceRef> sources;
  final ReviewStatus review;

  Iterable<ContentText> get texts sync* {
    yield name;
    yield* properties;
    yield* uses;
    yield explanation;
    if (practicalNote != null) yield practicalNote!;
  }
}
