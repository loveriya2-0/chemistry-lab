import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../state/lab_controller.dart';

/// Modal shown when the student drops the wrong chemical: what was expected,
/// why the chosen one does not work here (when the lab explains it) or that
/// it belongs to a later step, and its safety note.
class SmartWarningDialog extends StatelessWidget {
  const SmartWarningDialog({super.key, required this.result});

  final WrongDrop result;

  static Future<void> show(BuildContext context, WrongDrop result) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => SmartWarningDialog(result: result),
      transitionBuilder: (_, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final hazard = result.actual.hazard;
    final hint = result.hint;
    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: LabColors.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: const Icon(Icons.warning_amber_rounded, color: LabColors.danger, size: 40),
      ),
      title: Text(
        s.smartWarning,
        style: const TextStyle(fontWeight: FontWeight.w900, color: LabColors.danger),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.wrongDropMessage(s.chemical(result.expected), s.chemical(result.actual)),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4, color: LabColors.ink),
            ),
            if (result.outOfOrder) ...[
              const SizedBox(height: 8),
              Text(
                s.outOfOrderNote(s.chemical(result.actual)),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: LabColors.warning),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: LabColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: LabColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.whyNotTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(s.tr(hint), style: const TextStyle(fontSize: 13, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (hazard != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: LabColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.health_and_safety_rounded, color: LabColors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.safety(result.actual.label(s.language), s.tr(hazard)), style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: LabColors.danger),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.replay_rounded),
          label: Text(s.tryAgain),
        ),
      ],
    );
  }
}
