import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../models/chemical.dart';
import '../models/lab_step.dart';
import '../state/lab_controller.dart';

/// Top card: step counter, animated progress and the current goal.
///
/// [compact] tightens it on short screens so the bench keeps its room.
class GoalStatusBar extends StatelessWidget {
  const GoalStatusBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lab = context.watch<LabController>();
    final step = lab.currentStep;
    final accent = lab.practical.accent;
    final s = context.strings;

    return Card(
      margin: EdgeInsets.fromLTRB(16, 4, 16, compact ? 4 : 8),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    lab.isComplete
                        ? s.completedBadge
                        : s.stepOf(lab.stepIndex + 1, lab.totalSteps),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.close_rounded,
                          size: 18,
                          color: lab.mistakes > 0 ? LabColors.danger : LabColors.muted),
                      Flexible(
                        child: Text(
                          ' ${s.mistakes(lab.mistakes)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: lab.mistakes > 0 ? LabColors.danger : LabColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 10),
            TweenAnimationBuilder<double>(
              tween: Tween(end: lab.progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.12),
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  lab.isComplete ? Icons.emoji_events_rounded : Icons.flag_rounded,
                  color: lab.isComplete ? LabColors.warning : accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.1, 0), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      step == null ? s.allStepsDone : s.tr(step.instruction),
                      key: ValueKey(lab.stepIndex),
                      // Keeps the bench visible on small phones; the full
                      // procedure is always in the lab's info sheet.
                      maxLines: compact ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        color: LabColors.ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Says honestly whether this step measures anything.
            if (step != null && lab.expectedChemical?.state != ChemicalState.tool)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 32),
                child: Text(
                  switch (step.amount) {
                    StepAmount.approximate => s.amountApproximate,
                    StepAmount.fixed => s.amountFixed(step.volumeMl.toStringAsFixed(1)),
                    StepAmount.titration => s.amountTitration,
                  },
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: LabColors.muted, height: 1.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
