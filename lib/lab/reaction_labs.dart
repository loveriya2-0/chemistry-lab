import 'package:flutter/material.dart';

import '../content/content_catalog.dart';
import '../content/content_text.dart';
import '../content/models/reaction_lab.dart';
import '../l10n/localized_text.dart';
import '../models/chemical.dart';
import '../models/lab_step.dart';
import '../models/practical.dart';
import '../models/reaction_info.dart';

/// The reaction engine: turns verified reaction data ([ReactionLab]) into
/// the same [Practical] every lab runs on, so the bench, warnings, Focus
/// Mode, analytics and bookmarks work for each new experiment without new
/// code. Adding a Class 9–12 experiment means adding data, not widgets.
abstract final class ReactionLabs {
  /// Every reaction lab of every available board (each id once).
  static List<Practical> fromCatalog(ContentCatalog catalog) {
    final byId = <String, Practical>{};
    for (final board in catalog.registry.available) {
      final c = catalog.curriculum(board.id);
      if (c == null) continue;
      for (final r in c.reactions.values) {
        if (r.review.isPublishable) byId.putIfAbsent(r.id, () => toPractical(r, c.reagents));
      }
    }
    return byId.values.toList();
  }

  static Practical toPractical(ReactionLab r, Map<String, LabReagent> reagents) {
    final shelf = [for (final id in r.shelf) chemical(reagents[id]!)];
    final last = r.steps.last.effects;
    return Practical(
      id: r.id,
      title: _t(r.title),
      description: _t(r.aim),
      aim: _t(r.aim),
      icon: switch (last) {
        ReactionEffects(heating: true) => Icons.local_fire_department_rounded,
        ReactionEffects(sunlight: true) => Icons.wb_sunny_rounded,
        ReactionEffects(precipitate: _?) => Icons.grain_rounded,
        ReactionEffects(bubbles: true) => Icons.bubble_chart_rounded,
        ReactionEffects(warms: true) => Icons.thermostat_rounded,
        _ => Icons.science_rounded,
      },
      accent: const Color(0xFF0F766E),
      chemicals: shelf,
      beakerCapacityMl: r.beakerMl,
      steps: [
        for (final s in r.steps)
          LabStep(
            instruction: _t(s.instruction),
            requiredChemicalId: s.reagentId,
            volumeMl: s.volumeMl,
            resultColor: Color(s.effects.color),
            observation: _t(s.observation),
            bubbling: s.effects.bubbles,
            gasLabel: s.effects.gas,
            precipitateColor: _color(s.effects.precipitate),
            solidColor: _color(s.effects.solid),
            warms: s.effects.warms,
            heating: s.effects.heating,
            sunlight: s.effects.sunlight,
            fumesColor: _color(s.effects.fumes),
          ),
      ],
      conclusion: LocalizedText(en: '${r.equation}. ${r.whatHappened.en}', hi: '${r.equation}। ${_t(r.whatHappened).hi}'),
      reaction: ReactionInfo(
        kind: _t(r.kind),
        equation: r.equation,
        reactants: [for (final x in r.reactants) _t(x)],
        products: [for (final x in r.products) _t(x)],
        whatHappened: _t(r.whatHappened),
        why: _t(r.why),
        realLife: _t(r.realLife),
        examPoint: _t(r.examPoint),
        sources: r.sources,
        review: r.review,
      ),
      hints: {for (final e in r.hints.entries) e.key: _t(e.value)},
    );
  }

  static Chemical chemical(LabReagent x) => Chemical(
        id: x.id,
        name: _t(x.name),
        // A shelf item without a formula shows its (translated) name.
        formula: x.formula ?? x.name.en,
        color: Color(x.color),
        hazard: x.hazard == null ? null : _t(x.hazard!),
        state: ChemicalState.parse(x.state),
      );

  static Color? _color(int? argb) => argb == null ? null : Color(argb);

  // The validator guarantees Hindi on every published text.
  static LocalizedText _t(ContentText t) => LocalizedText(en: t.en, hi: t.hi ?? t.en);
}
