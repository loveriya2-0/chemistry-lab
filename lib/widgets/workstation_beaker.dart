import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/chemical.dart';
import '../state/lab_controller.dart';
import 'beaker_painter.dart';

/// The central beaker: a [DragTarget] that accepts [Chemical]s, forwards
/// them to [onChemicalDropped] and animates the result:
/// * correct  → pour stream (falling granules for a solid, nothing for a
///   tool such as a burner) + smooth colour/level change
/// * wrong    → the beaker shakes
///
/// The reaction's visible effects (bubbles, gas, precipitate, solid pieces,
/// fumes, heating, sunlight, warmth) come from the [LabController].
class WorkstationBeaker extends StatefulWidget {
  const WorkstationBeaker({super.key, required this.onChemicalDropped});

  /// Validates the drop (usually [LabController.attemptAdd]) and returns the
  /// result so the beaker can pick the matching animation.
  final DropResult Function(Chemical chemical) onChemicalDropped;

  @override
  State<WorkstationBeaker> createState() => _WorkstationBeakerState();
}

class _WorkstationBeakerState extends State<WorkstationBeaker>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  late final AnimationController _pour = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  Color? _pourColor;
  bool _pourSolid = false;

  @override
  void dispose() {
    _wave.dispose();
    _pour.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _handleAccept(Chemical chemical) {
    final result = widget.onChemicalDropped(chemical);
    switch (result) {
      case CorrectDrop() || PracticalCompleted():
        // A burner or sunlight is a condition, not something poured in.
        if (chemical.state == ChemicalState.tool) return;
        setState(() {
          _pourColor = chemical.color;
          _pourSolid = chemical.state == ChemicalState.solid;
        });
        _pour.forward(from: 0);
      case WrongDrop() || NeedsReset():
        _shake.forward(from: 0);
      // Filling the burette pours nothing; burette portions are run from
      // the burette panel, not dropped.
      case IgnoredDrop() || TitrantReady() || TitrantAdded() || Overshot():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lab = context.watch<LabController>();

    return DragTarget<Chemical>(
      onWillAcceptWithDetails: (_) => !lab.isComplete,
      onAcceptWithDetails: (details) => _handleAccept(details.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        // Implicit tweens give smooth colour + level transitions whenever
        // the controller reports a new beaker state.
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: lab.beakerColor),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, color, _) => TweenAnimationBuilder<double>(
            tween: Tween(end: lab.fillLevel),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, level, _) => AnimatedBuilder(
              animation: Listenable.merge([_wave, _pour, _shake]),
              builder: (context, _) {
                final s = _shake.value;
                final dx = math.sin(s * math.pi * 6) * 10 * (1 - s);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: AnimatedScale(
                    scale: hovering ? 1.05 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: CustomPaint(
                      painter: BeakerPainter(
                        liquidColor: color ?? LabController.emptyColor,
                        fillLevel: level,
                        wavePhase: _wave.value,
                        capacityMl: lab.practical.beakerCapacityMl,
                        bubbling: lab.isBubbling,
                        pourColor: _pourColor,
                        pourProgress: _pour.value,
                        highlighted: hovering,
                        solidColor: lab.solidColor,
                        precipitateColor: lab.precipitateColor,
                        fumesColor: lab.fumesColor,
                        pourSolid: _pourSolid,
                      ),
                      child: _BeakerOverlay(
                        hovering: hovering,
                        gasLabel: lab.gasLabel,
                        phase: _wave.value,
                        heating: lab.isHeating,
                        sunlight: lab.inSunlight,
                        warm: lab.isWarm,
                        precipitate: lab.precipitateColor,
                        fumes: lab.fumesColor != null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Text hints drawn on top of the beaker ("Drop here", the rising gas) and
/// badges for the conditions of the reaction (heating, sunlight, warmth,
/// precipitate, fumes).
class _BeakerOverlay extends StatelessWidget {
  const _BeakerOverlay({
    required this.hovering,
    required this.gasLabel,
    required this.phase,
    required this.heating,
    required this.sunlight,
    required this.warm,
    required this.precipitate,
    required this.fumes,
  });

  final bool hovering;
  final String? gasLabel;
  final double phase;
  final bool heating;
  final bool sunlight;
  final bool warm;
  final Color? precipitate;
  final bool fumes;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final badges = [
      if (heating) (Icons.local_fire_department_rounded, s.effectHeating, const Color(0xFFEA580C)),
      if (sunlight) (Icons.wb_sunny_rounded, s.effectSunlight, const Color(0xFFCA8A04)),
      if (warm) (Icons.thermostat_rounded, s.effectWarm, LabColors.danger),
      if (precipitate != null) (Icons.grain_rounded, s.effectPrecipitate, LabColors.ink),
      if (fumes) (Icons.cloud_rounded, s.effectFumes, LabColors.muted),
    ];
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (sunlight)
            Align(
              alignment: Alignment.topRight,
              child: Transform.rotate(
                angle: phase * 2 * math.pi / 8,
                child: const Icon(Icons.wb_sunny_rounded, size: 40, color: Color(0xFFFACC15)),
              ),
            ),
          if (heating)
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scale: 0.9 + 0.15 * math.sin(phase * 2 * math.pi),
                child: const Icon(Icons.local_fire_department_rounded, size: 34, color: Color(0xFFF97316)),
              ),
            ),
          if (badges.isNotEmpty)
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (icon, label, color) in badges)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (hovering)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LabColors.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s.releaseToPour,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          if (gasLabel case final gas?)
            Align(
              alignment: Alignment(0, -1 + 0.15 * (1 - phase)),
              child: Opacity(
                opacity: 1 - phase,
                child: Text(
                  gas,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: LabColors.secondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
