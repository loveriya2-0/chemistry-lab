import 'package:flutter/foundation.dart';

import '../content_text.dart';
import 'review.dart';
import 'syllabus.dart' show Json;

/// Parses "#RRGGBB" (or "#AARRGGBB") into an ARGB int.
int parseHexColor(String hex) {
  final h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (!RegExp(r'^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(h)) {
    throw FormatException('Bad colour "$hex"');
  }
  return int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
}

int? _colorOrNull(Object? v) => v == null ? null : parseHexColor(v as String);

List<ContentText> _texts(Object? json) =>
    [for (final e in (json as List<Object?>? ?? const [])) ContentText.fromJson(e! as Json)];

/// A bottle (or tool such as a burner) on the reaction lab's shelf.
/// Board-independent: lives in the shared content library.
@immutable
class LabReagent {
  const LabReagent({
    required this.id,
    required this.name,
    required this.formula,
    required this.color,
    required this.state,
    this.hazard,
  });

  factory LabReagent.fromJson(Json json) => LabReagent(
        id: json['id']! as String,
        name: ContentText.fromJson(json['name']! as Json),
        formula: json['formula'] as String?,
        color: parseHexColor(json['color']! as String),
        state: json['state'] as String? ?? 'liquid',
        hazard: contentTextOrNull(json['hazard']),
      );

  final String id;
  final ContentText name;

  /// Formula printed on the bottle; null for tools and mixtures.
  final String? formula;
  final int color;

  /// liquid / solid / tool.
  final String state;
  final ContentText? hazard;
}

/// What the student sees after one step of a reaction lab.
@immutable
class ReactionEffects {
  const ReactionEffects({
    required this.color,
    this.bubbles = false,
    this.gas,
    this.precipitate,
    this.solid,
    this.warms = false,
    this.heating = false,
    this.sunlight = false,
    this.fumes,
  });

  factory ReactionEffects.fromJson(Json json) => ReactionEffects(
        color: parseHexColor(json['color']! as String),
        bubbles: json['bubbles'] as bool? ?? false,
        gas: json['gas'] as String?,
        precipitate: _colorOrNull(json['precipitate']),
        solid: _colorOrNull(json['solid']),
        warms: json['warms'] as bool? ?? false,
        heating: json['heating'] as bool? ?? false,
        sunlight: json['sunlight'] as bool? ?? false,
        fumes: _colorOrNull(json['fumes']),
      );

  /// Colour of the beaker contents.
  final int color;
  final bool bubbles;

  /// Gas label shown rising, e.g. "H₂ ↑".
  final String? gas;
  final int? precipitate;

  /// New colour of solid pieces (e.g. copper coating on iron).
  final int? solid;
  final bool warms;
  final bool heating;
  final bool sunlight;
  final int? fumes;
}

@immutable
class ReactionStep {
  const ReactionStep({
    required this.reagentId,
    required this.volumeMl,
    required this.instruction,
    required this.observation,
    required this.effects,
  });

  factory ReactionStep.fromJson(Json json) => ReactionStep(
        reagentId: json['reagent']! as String,
        volumeMl: (json['ml'] as num? ?? 0).toDouble(),
        instruction: ContentText.fromJson(json['instruction']! as Json),
        observation: ContentText.fromJson(json['observation']! as Json),
        effects: ReactionEffects.fromJson(json['effects']! as Json),
      );

  final String reagentId;
  final double volumeMl;
  final ContentText instruction;
  final ContentText observation;
  final ReactionEffects effects;
}

/// One experiment of the reaction engine: a verified reaction, the shelf,
/// the ordered steps with their visible effects, and what to learn from it.
///
/// Board-independent; boards place it on their topics in the manifest
/// (`reactionLabs`). Its [equation] must be one already in the
/// source-checked notes or chemical library — the validator checks this,
/// so no equation is ever invented for the lab.
@immutable
class ReactionLab {
  const ReactionLab({
    required this.id,
    required this.kind,
    required this.title,
    required this.aim,
    required this.equation,
    required this.reactants,
    required this.products,
    required this.shelf,
    required this.beakerMl,
    required this.steps,
    required this.hints,
    required this.whatHappened,
    required this.why,
    required this.realLife,
    required this.examPoint,
    required this.sources,
    required this.review,
  });

  factory ReactionLab.fromJson(Json json) => ReactionLab(
        id: json['id']! as String,
        kind: ContentText.fromJson(json['kind']! as Json),
        title: ContentText.fromJson(json['title']! as Json),
        aim: ContentText.fromJson(json['aim']! as Json),
        equation: json['equation']! as String,
        reactants: _texts(json['reactants']),
        products: _texts(json['products']),
        shelf: [for (final e in json['shelf']! as List<Object?>) e! as String],
        beakerMl: (json['beakerMl'] as num? ?? 40).toDouble(),
        steps: [for (final s in json['steps']! as List<Object?>) ReactionStep.fromJson(s! as Json)],
        hints: {
          for (final e in ((json['hints'] as Json?) ?? const {}).entries) e.key: ContentText.fromJson(e.value! as Json),
        },
        whatHappened: ContentText.fromJson(json['what']! as Json),
        why: ContentText.fromJson(json['why']! as Json),
        realLife: ContentText.fromJson(json['realLife']! as Json),
        examPoint: ContentText.fromJson(json['examPoint']! as Json),
        sources: sourceRefsOf(json['sources']),
        review: reviewOf(json),
      );

  final String id;
  final ContentText kind;
  final ContentText title;
  final ContentText aim;
  final String equation;
  final List<ContentText> reactants;
  final List<ContentText> products;

  /// Reagent ids on the shelf: everything the steps need plus distractors.
  final List<String> shelf;
  final double beakerMl;
  final List<ReactionStep> steps;

  /// Why a distractor does not work, by reagent id.
  final Map<String, ContentText> hints;
  final ContentText whatHappened;
  final ContentText why;
  final ContentText realLife;
  final ContentText examPoint;
  final List<SourceRef> sources;
  final ReviewStatus review;

  /// Every text block, for completeness checks.
  Iterable<ContentText> get texts sync* {
    yield kind;
    yield title;
    yield aim;
    yield* reactants;
    yield* products;
    for (final s in steps) {
      yield s.instruction;
      yield s.observation;
    }
    yield* hints.values;
    yield whatHappened;
    yield why;
    yield realLife;
    yield examPoint;
  }
}
