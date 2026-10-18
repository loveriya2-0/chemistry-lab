import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../l10n/localized_text.dart';
import '../models/chemical.dart';
import '../models/practical_path.dart';
import '../state/focus_controller.dart';
import '../state/lab_controller.dart';
import '../widgets/chemical_shelf.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/focus_bar.dart';
import '../widgets/focus_session_host.dart';
import '../widgets/goal_status_bar.dart';
import '../widgets/lab_attempt_recorder.dart';
import '../widgets/language_toggle.dart';
import '../widgets/smart_warning_dialog.dart';
import '../widgets/workstation_beaker.dart';
import 'lab_tutorial_screen.dart';

/// Route to the lab for [path]. With [focusDuration] the lab runs inside a
/// Focus Mode session; without it, it behaves exactly as a plain lab.
Route<void> labRoute(PracticalPath path, {Duration? focusDuration}) {
  return MaterialPageRoute(
    // Each lab session gets its own controllers, disposed with the route.
    builder: (_) => MultiProvider(
      providers: [
        Provider<PracticalPath?>.value(value: path),
        ChangeNotifierProvider(create: (_) => LabController(path.practical)),
        if (focusDuration != null)
          ChangeNotifierProvider(
            create: (_) => FocusController(path: path, duration: focusDuration),
          ),
      ],
      // Records the visit for Analytics without touching the lab itself.
      child: LabAttemptRecorder(
        path: path,
        child: focusDuration == null
            ? const VirtualLabScreen()
            : const FocusSessionHost(child: VirtualLabScreen()),
      ),
    ),
  );
}

/// Screen 5 – the interactive lab bench.
///
/// Expects a [LabController] (and optionally a [FocusController]) above it.
class VirtualLabScreen extends StatelessWidget {
  const VirtualLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lab = context.read<LabController>();
    final inFocus = context.read<FocusController?>() != null;
    final s = context.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr(lab.practical.title)),
        actions: [
          const LanguageToggle(),
          IconButton(
            tooltip: s.aim,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showAim(context, lab),
          ),
          IconButton(
            tooltip: s.restart,
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: lab.reset,
          ),
          IconButton(
            tooltip: context.study.replayTutorial,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _replayTutorial(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        // Short screens (small phones, Focus Mode) get a compact status bar
        // so the beaker stays big enough to drop onto.
        builder: (context, box) => Column(
          children: [
            if (inFocus) FocusBar(onExit: () => FocusSessionHost.requestExit(context)),
            GoalStatusBar(compact: box.maxHeight < 560),
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Lab bench surface.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 26,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [LabColors.bench, LabColors.benchDark],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        const _ObservationChip(),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 0.85,
                            child: WorkstationBeaker(
                              onChemicalDropped: (c) => _handleDrop(context, c),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // While the burette is in use it replaces the shelf: nothing else
            // is poured during a titration.
            Selector<LabController, bool>(
              selector: (_, l) => l.currentStep?.titration != null && l.titrantReady,
              builder: (context, burette, _) => burette
                  ? _BurettePanel(onRun: (portion) => _runBurette(context, portion))
                  : ChemicalShelf(
                      chemicals: lab.practical.chemicals,
                      onChemicalTap: (c) => _showChemicalInfo(context, c),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Replays the lab tutorial. It runs on its own practice controller, so
  /// this lab is untouched; a running focus timer waits meanwhile.
  Future<void> _replayTutorial(BuildContext context) async {
    final focus = context.read<FocusController?>();
    final wasRunning = focus != null && focus.isStarted && !focus.isPaused && !focus.hasEnded;
    focus?.pause();
    await openLabTutorial(context);
    if (wasRunning && !focus.hasEnded) focus.resume();
  }

  /// Bridges the beaker's drop event to the validation engine and the UI.
  DropResult _handleDrop(BuildContext context, Chemical chemical) =>
      _handleResult(context, context.read<LabController>().attemptAdd(chemical));

  /// Runs one portion of titrant from the burette.
  void _runBurette(BuildContext context, double portionMl) {
    final lab = context.read<LabController>();
    _handleResult(context, lab.attemptAdd(lab.expectedChemical!, portionMl: portionMl));
  }

  DropResult _handleResult(BuildContext context, DropResult result) {
    final lab = context.read<LabController>();
    final focus = context.read<FocusController?>();
    focus?.recordDrop(result);

    switch (result) {
      case WrongDrop():
        HapticFeedback.heavyImpact();
        SmartWarningDialog.show(context, result);
      case CorrectDrop():
        HapticFeedback.lightImpact();
      case PracticalCompleted():
        HapticFeedback.mediumImpact();
        // Let the pour/colour animation finish before celebrating.
        Future.delayed(const Duration(milliseconds: 1400), () async {
          // The focus timer may have ended the session in the meantime.
          if (!context.mounted || (focus?.hasEnded ?? false)) return;
          final action = await CompletionDialog.show(context, lab);
          if (!context.mounted) return;
          switch (action) {
            case CompletionAction.exit:
              Navigator.of(context).pop();
            case CompletionAction.repeat:
              lab.reset();
            case null: // Closed by the focus timer ending.
              break;
          }
        });
      case TitrantReady() || TitrantAdded():
        HapticFeedback.selectionClick();
      case Overshot(:final readingMl, :final portionMl):
        HapticFeedback.mediumImpact();
        _showOvershot(context, lab, readingMl: readingMl, portionMl: portionMl);
      case NeedsReset():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(context.readStrings.needsResetMessage),
            action: SnackBarAction(label: context.readStrings.restart, onPressed: lab.reset),
          ));
      case IgnoredDrop():
        break;
    }
    return result;
  }

  /// The end point was passed: the reading only brackets it, so the
  /// titration must be repeated, as after a rough titration in a real lab.
  void _showOvershot(BuildContext context, LabController lab, {required double readingMl, required double portionMl}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final s = dialogContext.strings;
        return AlertDialog(
          icon: const Icon(Icons.water_drop_rounded, color: LabColors.warning, size: 36),
          title: Text(s.overshotTitle),
          content: Text(
            s.overshotMessage((readingMl - portionMl).toStringAsFixed(1), readingMl.toStringAsFixed(1)),
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                lab.reset();
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(s.restart),
            ),
          ],
        );
      },
    );
  }

  void _showChemicalInfo(BuildContext context, Chemical c) {
    final s = context.readStrings;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          c.hazard == null ? s.chemical(c) : '${s.chemical(c)} – ${s.tr(c.hazard!)}',
        ),
        duration: const Duration(seconds: 2),
      ));
  }

  void _showAim(BuildContext context, LabController lab) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final s = sheetContext.strings;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.aim, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(s.tr(lab.practical.aim), style: const TextStyle(fontSize: 16, height: 1.4)),
              const SizedBox(height: 16),
              Text(s.procedure, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final (i, step) in lab.practical.steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${i + 1}. ${s.tr(step.instruction)}'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Shows what happened after the last correct pour.
class _ObservationChip extends StatelessWidget {
  const _ObservationChip();

  @override
  Widget build(BuildContext context) {
    final observation = context.select<LabController, LocalizedText?>(
      (l) => l.lastObservation,
    );
    return SizedBox(
      height: 48,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: observation == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(observation),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: LabColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_rounded, size: 18, color: LabColors.success),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.strings.tr(observation),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LabColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Burette controls, shown in place of the shelf while a titration step
/// has its titrant filled: the current reading and one button per portion.
class _BurettePanel extends StatelessWidget {
  const _BurettePanel({required this.onRun});

  final ValueChanged<double> onRun;

  @override
  Widget build(BuildContext context) {
    final lab = context.watch<LabController>();
    final spec = lab.currentStep?.titration;
    if (spec == null) return const SizedBox.shrink();
    final s = context.strings;
    final accent = lab.practical.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(s.buretteTitle, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: accent)),
              ),
              // Shrinks rather than overflows with a large phone font.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    s.buretteReading(lab.titrantMl.toStringAsFixed(1)),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: LabColors.ink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, portion) in spec.portionsMl.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: lab.isSpoiled ? null : () => onRun(portion),
                    child: Text(s.addPortion(portion.toStringAsFixed(1))),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
