import 'package:flutter/material.dart';

import '../l10n/localized_text.dart';
import 'chemical.dart';
import 'lab_step.dart';
import 'reaction_info.dart';

/// A complete lab experiment: the shelf of chemicals plus the ordered steps.
@immutable
class Practical {
  const Practical({
    required this.id,
    required this.title,
    required this.description,
    required this.aim,
    required this.icon,
    required this.accent,
    required this.chemicals,
    required this.steps,
    required this.beakerCapacityMl,
    required this.conclusion,
    this.reaction,
    this.hints = const {},
    this.calculation,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final LocalizedText aim;
  final IconData icon;
  final Color accent;

  /// Everything on the shelf – includes distractors, not just required ones.
  final List<Chemical> chemicals;

  /// Ordered sequence the student must follow.
  final List<LabStep> steps;

  /// Volume that fills the beaker to the brim (for the level animation).
  final double beakerCapacityMl;

  /// Summary shown when the practical is completed.
  final LocalizedText conclusion;

  /// Set for labs from the reaction engine: the verified reaction shown
  /// when the experiment is complete.
  final ReactionInfo? reaction;

  /// Why a particular wrong chemical does not work here, by chemical id.
  final Map<String, LocalizedText> hints;

  /// For a titration: how the burette reading gives the unknown
  /// concentration.
  final TitrationCalculation? calculation;

  Chemical chemicalById(String id) => chemicals.firstWhere((c) => c.id == id);
}

/// c(unknown) from a titration: c(known) × V(known) × ν(unknown) ÷ ν(known)
/// ÷ V(unknown), where ν are the coefficients in the balanced equation and
/// one of the two volumes is the burette reading.
@immutable
class TitrationCalculation {
  const TitrationCalculation({
    required this.knownFormula,
    required this.knownMolarity,
    required this.unknownFormula,
    this.knownVolumeMl,
    this.unknownVolumeMl,
    this.knownCoefficient = 1,
    this.unknownCoefficient = 1,
  }) : assert((knownVolumeMl == null) != (unknownVolumeMl == null), 'exactly one volume is the burette reading');

  final String knownFormula;
  final double knownMolarity;

  /// Volume taken with a pipette; null when this solution is in the burette.
  final double? knownVolumeMl;
  final String unknownFormula;
  final double? unknownVolumeMl;
  final int knownCoefficient;
  final int unknownCoefficient;

  double unknownMolarity(double buretteReadingMl) =>
      knownMolarity *
      (knownVolumeMl ?? buretteReadingMl) *
      unknownCoefficient /
      knownCoefficient /
      (unknownVolumeMl ?? buretteReadingMl);

  /// "c(NaOH) = 0.1 × 8.0 ÷ 10.0 = 0.080 M", with the mole ratio when it
  /// is not 1 : 1.
  String working(double buretteReadingMl) {
    String ml(double v) => v.toStringAsFixed(1);
    final ratio = unknownCoefficient / knownCoefficient;
    final factor = ratio == 1 ? '' : '${ratio == ratio.roundToDouble() ? ratio.round() : ratio} × ';
    return 'c($unknownFormula) = $factor$knownMolarity × ${ml(knownVolumeMl ?? buretteReadingMl)} ÷ '
        '${ml(unknownVolumeMl ?? buretteReadingMl)} = ${unknownMolarity(buretteReadingMl).toStringAsFixed(3)} M';
  }
}
