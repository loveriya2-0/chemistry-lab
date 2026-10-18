import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'review.dart';
import 'syllabus.dart' show Json;

List<ContentText> _texts(Object? json) =>
    [for (final e in (json as List<Object?>? ?? const [])) ContentText.fromJson(e! as Json)];

List<T> _list<T>(Object? json, T Function(Json) parse) =>
    [for (final e in (json as List<Object?>? ?? const [])) parse(e! as Json)];

/// One item a practical needs: a piece of apparatus or a chemical.
@immutable
class GuideMaterial {
  const GuideMaterial({required this.name, this.formula, this.quantity, this.hazard});

  factory GuideMaterial.fromJson(Json json) => GuideMaterial(
        name: ContentText.fromJson(json['name']! as Json),
        formula: json['formula'] as String?,
        quantity: contentTextOrNull(json['quantity']),
        hazard: contentTextOrNull(json['hazard']),
      );

  final ContentText name;

  /// Chemical formula, the same in every language; null for apparatus.
  final String? formula;

  /// How much is needed, where it matters ("About 20–30 mL").
  final ContentText? quantity;

  /// Safety note for this chemical.
  final ContentText? hazard;

  Iterable<ContentText> get texts => [name, ?quantity, ?hazard];
}

/// One step of the real laboratory procedure.
@immutable
class GuideStep {
  const GuideStep({required this.instruction, this.observation, this.explanation});

  factory GuideStep.fromJson(Json json) => GuideStep(
        instruction: ContentText.fromJson(json['instruction']! as Json),
        observation: contentTextOrNull(json['observation']),
        explanation: contentTextOrNull(json['explanation']),
      );

  final ContentText instruction;

  /// What the student should expect to see, if anything visible happens.
  final ContentText? observation;

  /// Why the step is done this way, or why the observation happens.
  final ContentText? explanation;

  Iterable<ContentText> get texts => [instruction, ?observation, ?explanation];
}

/// One viva voce question an examiner may ask about the practical, with a
/// short model answer.
@immutable
class VivaQuestion {
  const VivaQuestion({required this.question, required this.answer});

  factory VivaQuestion.fromJson(Json json) => VivaQuestion(
        question: ContentText.fromJson(json['question']! as Json),
        answer: ContentText.fromJson(json['answer']! as Json),
      );

  final ContentText question;
  final ContentText answer;

  Iterable<ContentText> get texts => [question, answer];
}

/// The written guide for one interactive lab: how the experiment is done in
/// a real school laboratory, and how the virtual lab differs from it.
///
/// Board-independent: lives in the shared content library and is keyed by
/// the lab id. Where the lab sits in a board's syllabus is board data (the
/// manifest's `labs` entries).
@immutable
class PracticalGuide {
  const PracticalGuide({
    required this.id,
    required this.aim,
    required this.apparatus,
    required this.chemicals,
    required this.steps,
    required this.result,
    required this.safety,
    required this.simulationLimits,
    required this.sources,
    required this.review,
    this.equation,
    this.viva = const [],
  });

  factory PracticalGuide.fromJson(Json json) => PracticalGuide(
        id: json['id']! as String,
        aim: ContentText.fromJson(json['aim']! as Json),
        equation: json['equation'] as String?,
        apparatus: _list(json['apparatus'], GuideMaterial.fromJson),
        chemicals: _list(json['chemicals'], GuideMaterial.fromJson),
        steps: _list(json['steps'], GuideStep.fromJson),
        result: ContentText.fromJson(json['result']! as Json),
        safety: _texts(json['safety']),
        simulationLimits: _texts(json['simulationLimits']),
        viva: _list(json['viva'], VivaQuestion.fromJson),
        sources: sourceRefsOf(json['sources']),
        review: reviewOf(json),
      );

  /// Id of the interactive lab this guide belongs to.
  final String id;
  final ContentText aim;

  /// Balanced equation, in display form.
  final String? equation;
  final List<GuideMaterial> apparatus;
  final List<GuideMaterial> chemicals;

  /// The real laboratory procedure, in order.
  final List<GuideStep> steps;
  final ContentText result;
  final List<ContentText> safety;

  /// How the virtual lab is simpler than the real experiment.
  final List<ContentText> simulationLimits;

  /// Viva voce practice: questions with model answers.
  final List<VivaQuestion> viva;
  final List<SourceRef> sources;
  final ReviewStatus review;

  /// Every bilingual text, for validation.
  Iterable<ContentText> get texts => [
        aim,
        for (final m in [...apparatus, ...chemicals]) ...m.texts,
        for (final s in steps) ...s.texts,
        result,
        ...safety,
        ...simulationLimits,
        for (final v in viva) ...v.texts,
      ];
}
