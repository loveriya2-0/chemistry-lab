import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../l10n/localized_text.dart';

/// How a shelf item enters the beaker.
enum ChemicalState {
  /// Poured as a liquid or solution.
  liquid,

  /// Dropped in as pieces, granules or powder.
  solid,

  /// Not a chemical: a condition such as heat or sunlight.
  tool;

  static ChemicalState parse(String? value) => switch (value) {
        null || 'liquid' => liquid,
        'solid' => solid,
        'tool' => tool,
        _ => throw FormatException('Unknown chemical state "$value"'),
      };
}

/// A reagent that can sit on the chemical shelf and be poured into the beaker.
@immutable
class Chemical {
  const Chemical({
    required this.id,
    required this.name,
    required this.formula,
    required this.color,
    this.hazard,
    this.state = ChemicalState.liquid,
  });

  /// Stable identifier used by [LabStep.requiredChemicalId].
  final String id;

  /// Human-readable name, e.g. "Hydrochloric Acid".
  final LocalizedText name;

  /// Short label printed on the bottle, e.g. "HCl". Formulae are the same in
  /// every language.
  final String formula;

  /// Colour of the liquid/solid inside the bottle.
  final Color color;

  /// Optional safety note shown on long-press.
  final LocalizedText? hazard;

  final ChemicalState state;

  /// True when there is no real formula and [formula] just repeats the
  /// English name (e.g. Phenolphthalein), so it should be translated too.
  bool get _formulaIsName => name.en == formula;

  /// Bottle label: the formula, or the translated name if there is none.
  String label(AppLanguage language) =>
      _formulaIsName ? name.of(language) : formula;

  /// "Hydrochloric Acid (HCl)" – used in instructions and warnings.
  String displayName(AppLanguage language) => _formulaIsName
      ? name.of(language)
      : '${name.of(language)} ($formula)';

  @override
  bool operator ==(Object other) => other is Chemical && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
