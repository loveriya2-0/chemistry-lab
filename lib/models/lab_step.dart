import 'package:flutter/material.dart';

import '../l10n/localized_text.dart';

/// How the amount poured in a step is handled. The lab never presents an
/// animated pour as a measurement unless the apparatus really measures it.
enum StepAmount {
  /// A rough amount ("a little", "2 drops"). [LabStep.volumeMl] only
  /// drives the liquid level; the student does not measure anything.
  approximate,

  /// Delivered by fixed-volume apparatus such as a pipette, so exactly
  /// [LabStep.volumeMl] is added.
  fixed,

  /// Added from a burette in portions the student chooses, until the end
  /// point ([LabStep.titration]). The burette reading is the measurement.
  titration,
}

/// The burette part of a titration step.
@immutable
class TitrationSpec {
  const TitrationSpec({
    required this.endPointMl,
    required this.duringObservation,
    required this.nearObservation,
    required this.overshootColor,
    this.portionsMl = const [1.0, 0.1],
  });

  /// Burette reading at which the indicator just changes colour.
  final double endPointMl;

  /// Portions the student can run in: a quick one and a "drop by drop" one.
  final List<double> portionsMl;

  /// What is seen after a portion that stops well short of the end point.
  final LocalizedText duringObservation;

  /// The real cue that the end point is close (within [nearMl]): the
  /// colour change takes longer to reverse on swirling.
  final LocalizedText nearObservation;

  static const nearMl = 0.5;

  /// Colour of the flask once the end point has been passed.
  final Color overshootColor;
}

/// One action in a practical: "add [volumeMl] of [requiredChemicalId]".
///
/// The resulting beaker state ([resultColor], [bubbling]) is applied once the
/// student pours the correct chemical.
@immutable
class LabStep {
  const LabStep({
    required this.instruction,
    required this.requiredChemicalId,
    required this.volumeMl,
    required this.resultColor,
    required this.observation,
    this.bubbling = false,
    this.gasLabel,
    this.precipitateColor,
    this.solidColor,
    this.warms = false,
    this.heating = false,
    this.sunlight = false,
    this.fumesColor,
    this.amount = StepAmount.approximate,
    this.titration,
  }) : assert((amount == StepAmount.titration) == (titration != null), 'titration steps need a TitrationSpec');

  /// Goal text shown in the top status bar.
  final LocalizedText instruction;

  /// [Chemical.id] that must be dropped to complete this step.
  final String requiredChemicalId;

  /// Volume added to the beaker (drives the liquid level).
  final double volumeMl;

  /// Colour of the beaker contents after this step.
  final Color resultColor;

  /// What the student "sees" after the step (shown as feedback).
  final LocalizedText observation;

  /// Whether the reaction produces gas bubbles after this step.
  final bool bubbling;

  /// Gas shown rising from the beaker, e.g. "H₂ ↑".
  final String? gasLabel;

  /// An insoluble solid forms and settles (null: no precipitate).
  final Color? precipitateColor;

  /// New colour of the solid pieces in the beaker (e.g. copper coating).
  final Color? solidColor;

  /// The mixture gets warm (exothermic).
  final bool warms;

  /// A burner heats the beaker during this step.
  final bool heating;

  /// The contents are kept in sunlight.
  final bool sunlight;

  /// Visible fumes or vapours rise.
  final Color? fumesColor;

  final StepAmount amount;

  /// Set exactly when [amount] is [StepAmount.titration].
  final TitrationSpec? titration;
}
