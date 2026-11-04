import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'review.dart';
import 'syllabus.dart' show Json;

/// Ids of the hand-drawn diagrams the app can show with a note
/// (drawn in widgets/topic_diagrams.dart).
const topicDiagramIds = {
  'ph-scale',
  'reaction-types',
  'activity-series',
  'ionic-bond-nacl',
  'covalent-methane',
  'bohr-sodium',
  'gold-foil',
  'tyndall-effect',
  'paper-chromatography',
  'periodic-trends',
  'vsepr-shapes',
  'daniell-cell',
  'activation-energy',
  'soap-micelle',
  'dynamic-equilibrium',
};

List<ContentText> _texts(Object? json) =>
    [for (final e in (json as List<Object?>? ?? const [])) ContentText.fromJson(e! as Json)];

List<String> _strings(Object? json) => [for (final e in (json as List<Object?>? ?? const [])) e! as String];

/// A memory aid: a mnemonic or shortcut and what it helps recall.
///
/// Only added where it genuinely helps; a note may have none.
@immutable
class MemoryTrick {
  const MemoryTrick({required this.trick, required this.recall});

  factory MemoryTrick.fromJson(Json json) => MemoryTrick(
        trick: ContentText.fromJson(json['trick']! as Json),
        recall: ContentText.fromJson(json['recall']! as Json),
      );

  /// The mnemonic or shortcut itself.
  final ContentText trick;

  /// What the trick stands for, so it is never learnt without its meaning.
  final ContentText recall;
}

/// A last-minute summary of a note.
@immutable
class QuickRevision {
  const QuickRevision({required this.oneLine, this.formula, required this.points});

  factory QuickRevision.fromJson(Json json) => QuickRevision(
        oneLine: ContentText.fromJson(json['oneLine']! as Json),
        formula: json['formula'] as String?,
        points: _texts(json['points']),
      );

  /// One-line definition.
  final ContentText oneLine;

  /// The one formula or reaction to remember, taken from the note's own
  /// [TopicNote.formulas].
  final String? formula;

  /// Two or three must-remember points.
  final List<ContentText> points;
}

/// Study notes for one syllabus topic (or a chapter without topics).
///
/// Board-specific: [targetId] is a topic or chapter id of one syllabus.
/// A note may also cover the target's sub-topics ([coveredIds]) so that
/// every topic is explained exactly once.
@immutable
class TopicNote {
  const TopicNote({
    required this.id,
    required this.targetId,
    required this.coveredIds,
    required this.definition,
    required this.explanation,
    required this.keyPoints,
    required this.realLife,
    required this.examFocus,
    required this.commonMistakes,
    required this.formulas,
    required this.practicalIds,
    required this.conceptIds,
    required this.chemicalIds,
    required this.sources,
    required this.review,
    this.memoryTricks = const [],
    this.quickRevision,
    this.diagrams = const [],
  });

  factory TopicNote.fromJson(Json json) => TopicNote(
        id: json['id']! as String,
        targetId: json['targetId']! as String,
        coveredIds: _strings(json['covers']),
        definition: ContentText.fromJson(json['definition']! as Json),
        explanation: ContentText.fromJson(json['explanation']! as Json),
        keyPoints: _texts(json['keyPoints']),
        realLife: ContentText.fromJson(json['realLife']! as Json),
        examFocus: ContentText.fromJson(json['examFocus']! as Json),
        commonMistakes: _texts(json['commonMistakes']),
        formulas: _strings(json['formulas']),
        practicalIds: _strings(json['practicalIds']),
        conceptIds: _strings(json['conceptIds']),
        chemicalIds: _strings(json['chemicalIds']),
        sources: sourceRefsOf(json['sources']),
        review: reviewOf(json),
        memoryTricks: [for (final t in (json['memoryTricks'] as List<Object?>? ?? const [])) MemoryTrick.fromJson(t! as Json)],
        quickRevision: switch (json['quickRevision']) {
          final Json q => QuickRevision.fromJson(q),
          _ => null,
        },
        diagrams: _strings(json['diagrams']),
      );

  final String id;
  final String targetId;

  /// Sub-topics explained inside this note.
  final List<String> coveredIds;
  final ContentText definition;

  /// The idea in simple words.
  final ContentText explanation;
  final List<ContentText> keyPoints;
  final ContentText realLife;

  /// What students should be able to do in the exam. Never a claim about
  /// how often it is asked — that comes from PYQ data.
  final ContentText examFocus;
  final List<ContentText> commonMistakes;

  /// Formulas and balanced equations, in display form.
  final List<String> formulas;
  final List<String> practicalIds;
  final List<String> conceptIds;
  final List<String> chemicalIds;
  final List<SourceRef> sources;
  final ReviewStatus review;

  /// Optional; empty when no trick is genuinely useful for this topic.
  final List<MemoryTrick> memoryTricks;

  /// Optional last-minute summary.
  final QuickRevision? quickRevision;

  /// Built-in drawings that explain this note (ids from [topicDiagramIds]).
  final List<String> diagrams;

  Iterable<String> get allTargetIds sync* {
    yield targetId;
    yield* coveredIds;
  }

  /// Every text block, for completeness checks.
  Iterable<ContentText> get texts sync* {
    yield definition;
    yield explanation;
    yield* keyPoints;
    yield realLife;
    yield examFocus;
    yield* commonMistakes;
    for (final t in memoryTricks) {
      yield t.trick;
      yield t.recall;
    }
    if (quickRevision case final q?) {
      yield q.oneLine;
      yield* q.points;
    }
  }
}
