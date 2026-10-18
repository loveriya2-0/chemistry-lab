import 'package:flutter/material.dart';

import '../l10n/localized_text.dart';
import '../models/chemical.dart';
import '../models/lab_step.dart';
import '../models/practical.dart';

/// Outcome of dropping a chemical into the beaker.
sealed class DropResult {
  const DropResult();
}

/// Right chemical; the practical moved on to the next step.
final class CorrectDrop extends DropResult {
  const CorrectDrop(this.step);
  final LabStep step;
}

/// Right chemical and it was the final step.
final class PracticalCompleted extends DropResult {
  const PracticalCompleted(this.step);
  final LabStep step;
}

/// Wrong chemical; state is unchanged.
final class WrongDrop extends DropResult {
  const WrongDrop({required this.expected, required this.actual, this.hint, this.outOfOrder = false});
  final Chemical expected;
  final Chemical actual;

  /// Why this chemical does not work here, when the lab explains it.
  final LocalizedText? hint;

  /// The chemical is used later in this practical — wrong order, not
  /// wrong chemical.
  final bool outOfOrder;
}

/// Dropped after the practical was already finished.
final class IgnoredDrop extends DropResult {
  const IgnoredDrop();
}

/// Right chemical for a titration step: the burette is filled and the
/// student now runs it in portions. Nothing is added yet.
final class TitrantReady extends DropResult {
  const TitrantReady(this.step);
  final LabStep step;
}

/// A burette portion that did not reach the end point.
final class TitrantAdded extends DropResult {
  const TitrantAdded(this.readingMl);
  final double readingMl;
}

/// A burette portion that went past the end point. As in a real rough
/// titration this is not a mistake: the reading brackets the end point,
/// and the titration is repeated (after [LabController.reset]) for an
/// accurate reading.
final class Overshot extends DropResult {
  const Overshot({required this.readingMl, required this.portionMl});
  final double readingMl;
  final double portionMl;
}

/// Refused because the run was spoiled (end point passed); reset first.
final class NeedsReset extends DropResult {
  const NeedsReset();
}

/// Validation engine + beaker state for one practical session.
///
/// Pure Dart/ChangeNotifier – no widgets – so it is fully unit-testable.
/// Every practical, including those from the reaction engine, runs here.
class LabController extends ChangeNotifier {
  LabController(this.practical) {
    reset();
  }

  /// Fresh-water look of an empty beaker.
  static const emptyColor = Color(0x00FFFFFF);

  final Practical practical;

  late int _stepIndex;
  late Color _beakerColor;
  late double _volumeMl;
  late int _mistakes;
  late bool _bubbling;
  LocalizedText? _lastObservation;
  String? _gasLabel;
  Color? _precipitateColor;
  Color? _solidColor;
  bool _warm = false;
  bool _heating = false;
  bool _sunlight = false;
  Color? _fumesColor;
  final List<Chemical> _added = [];
  double _titrantMl = 0;
  bool _titrantReady = false;
  bool _spoiled = false;

  /// Burette reading: volume run in during the current titration step
  /// (kept after the end point so the result can be shown).
  double get titrantMl => _titrantMl;

  /// The correct titrant has been chosen and the burette can be run.
  bool get titrantReady => _titrantReady;

  /// The end point was passed; nothing more can be added until [reset].
  bool get isSpoiled => _spoiled;

  int get stepIndex => _stepIndex;
  int get totalSteps => practical.steps.length;
  bool get isComplete => _stepIndex >= totalSteps;
  LabStep? get currentStep => isComplete ? null : practical.steps[_stepIndex];
  Color get beakerColor => _beakerColor;
  double get volumeMl => _volumeMl;
  int get mistakes => _mistakes;
  bool get isBubbling => _bubbling;
  LocalizedText? get lastObservation => _lastObservation;
  List<Chemical> get addedChemicals => List.unmodifiable(_added);

  /// Gas rising from the beaker right now ("H₂ ↑"), if any.
  String? get gasLabel => _gasLabel;

  /// Colour of the settled precipitate, if one has formed.
  Color? get precipitateColor => _precipitateColor;

  /// Colour of the solid pieces in the beaker, if any were added.
  Color? get solidColor => _solidColor;

  /// The mixture has warmed up (exothermic reaction).
  bool get isWarm => _warm;
  bool get isHeating => _heating;
  bool get inSunlight => _sunlight;
  Color? get fumesColor => _fumesColor;

  /// 0..1 fill ratio for the painter.
  double get fillLevel =>
      (_volumeMl / practical.beakerCapacityMl).clamp(0.0, 1.0);

  /// 0..1 progress for the status bar.
  double get progress => _stepIndex / totalSteps;

  /// The chemical the student should pick next (null when done).
  Chemical? get expectedChemical => currentStep == null
      ? null
      : practical.chemicalById(currentStep!.requiredChemicalId);

  /// 1–3 stars based on mistakes made.
  int get stars => switch (_mistakes) {
        0 => 3,
        <= 2 => 2,
        _ => 1,
      };

  /// Core validation: checks [chemical] against the current step.
  ///
  /// On a titration step the first correct drop only fills the burette
  /// ([TitrantReady]); each later call must give [portionMl], one of the
  /// step's burette portions.
  DropResult attemptAdd(Chemical chemical, {double? portionMl}) {
    final step = currentStep;
    if (step == null) return const IgnoredDrop();
    if (_spoiled) return const NeedsReset();

    if (chemical.id != step.requiredChemicalId) {
      _mistakes++;
      notifyListeners();
      final later = practical.steps.skip(_stepIndex + 1).any((s) => s.requiredChemicalId == chemical.id);
      return WrongDrop(
        expected: expectedChemical!,
        actual: chemical,
        hint: practical.hints[chemical.id],
        outOfOrder: later,
      );
    }

    if (step.titration case final t?) {
      if (portionMl == null) {
        _titrantReady = true;
        notifyListeners();
        return TitrantReady(step);
      }
      if (!t.portionsMl.contains(portionMl)) {
        throw ArgumentError.value(portionMl, 'portionMl', 'not a burette portion of this step');
      }
      if (!_added.contains(chemical)) _added.add(chemical);
      // Work in hundredths of a mL so repeated 0.1 mL portions add exactly.
      _titrantMl = ((_titrantMl + portionMl) * 100).roundToDouble() / 100;
      _volumeMl += portionMl;
      final over = _titrantMl - t.endPointMl;
      if (over < -0.001) {
        _lastObservation = -over <= TitrationSpec.nearMl + 0.001 ? t.nearObservation : t.duringObservation;
        notifyListeners();
        return TitrantAdded(_titrantMl);
      }
      if (over > 0.001) {
        _spoiled = true;
        _beakerColor = t.overshootColor;
        _lastObservation = null;
        notifyListeners();
        return Overshot(readingMl: _titrantMl, portionMl: portionMl);
      }
      return _complete(step, chemical);
    }

    _added.add(chemical);
    _volumeMl += step.volumeMl;
    return _complete(step, chemical);
  }

  /// Applies a correctly finished step and moves on.
  DropResult _complete(LabStep step, Chemical chemical) {
    _beakerColor = step.resultColor;
    _bubbling = step.bubbling;
    _gasLabel = step.gasLabel;
    _heating = step.heating;
    _sunlight = step.sunlight;
    _fumesColor = step.fumesColor;
    _warm = _warm || step.warms;
    if (chemical.state == ChemicalState.solid) _solidColor = chemical.color;
    if (step.solidColor != null) _solidColor = step.solidColor;
    if (step.precipitateColor != null) _precipitateColor = step.precipitateColor;
    _lastObservation = step.observation;
    _stepIndex++;
    // The burette closes; its reading stays for the result.
    _titrantReady = false;
    notifyListeners();

    return isComplete ? PracticalCompleted(step) : CorrectDrop(step);
  }

  void reset() {
    _stepIndex = 0;
    _beakerColor = emptyColor;
    _volumeMl = 0;
    _mistakes = 0;
    _bubbling = false;
    _lastObservation = null;
    _gasLabel = null;
    _precipitateColor = null;
    _solidColor = null;
    _warm = false;
    _heating = false;
    _sunlight = false;
    _fumesColor = null;
    _added.clear();
    _titrantMl = 0;
    _titrantReady = false;
    _spoiled = false;
    notifyListeners();
  }
}
