import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../l10n/app_strings.dart';
import '../l10n/study_strings.dart';
import '../lab/lab_tutorial.dart';
import '../models/chemical.dart';
import '../state/lab_controller.dart';
import '../widgets/chemical_shelf.dart';
import '../widgets/goal_status_bar.dart';
import '../widgets/language_toggle.dart';
import '../widgets/smart_warning_dialog.dart';
import '../widgets/workstation_beaker.dart';

/// Opens the tutorial. It marks itself seen as soon as it opens, so it is
/// shown once by default however it is left (finished, skipped or Back).
Future<void> openLabTutorial(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LabTutorialScreen()));

/// First-time lab tutorial: explains the shelf, the beaker, the goal bar,
/// wrong choices, Reset and the completion screen, shows an animated drag,
/// then lets the student do one real drag.
///
/// It uses the real shelf, beaker, goal bar and Smart Warning on its own
/// [LabController] for [LabTutorial.practical] — never the real lab's — so
/// it cannot advance an experiment, change a burette reading or save an
/// attempt. Only the "seen" flag is stored.
class LabTutorialScreen extends StatefulWidget {
  const LabTutorialScreen({super.key});

  @override
  State<LabTutorialScreen> createState() => _LabTutorialScreenState();
}

class _LabTutorialScreenState extends State<LabTutorialScreen> with SingleTickerProviderStateMixin {
  final _lab = LabController(LabTutorial.practical);
  late final AnimationController _pointer = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  final _stackKey = GlobalKey();
  final _shelfKey = GlobalKey();
  final _beakerKey = GlobalKey();
  TutorialStep _step = TutorialStep.welcome;
  WrongDrop? _lastWrong;
  Rect? _from;
  Rect? _to;

  static const _pages = TutorialStep.values;

  @override
  void initState() {
    super.initState();
    // Shown once by default: opening it counts, however it is left.
    LabTutorial.markSeen(context.read<SharedPreferences>());
  }

  @override
  void dispose() {
    _pointer.dispose();
    _lab.dispose();
    super.dispose();
  }

  void _go(TutorialStep step) {
    setState(() {
      _step = step;
      _lastWrong = null;
    });
    if (step == TutorialStep.demo) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      _pointer.repeat();
    } else {
      _pointer.stop();
    }
    // The guided drag always starts from an empty beaker.
    if (step == TutorialStep.tryIt) _lab.reset();
  }

  void _next() => _go(_pages[(_step.index + 1).clamp(0, _pages.length - 1)]);

  void _replay() {
    _lab.reset();
    _go(TutorialStep.welcome);
  }

  void _close() => Navigator.of(context).pop();

  /// Where the demo pointer starts (the water bottle) and ends (the beaker).
  void _measure() {
    if (!mounted) return;
    Rect? rectOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || stack == null || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    }

    setState(() {
      _from = rectOf(_shelfKey);
      _to = rectOf(_beakerKey);
    });
  }

  DropResult _onDrop(Chemical chemical) {
    final result = _lab.attemptAdd(chemical);
    switch (result) {
      case WrongDrop():
        setState(() => _lastWrong = result);
        SmartWarningDialog.show(context, result);
      case PracticalCompleted():
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _go(TutorialStep.wellDone);
        });
      default:
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final st = context.study;
    final water = LabTutorial.practical.chemicalById('h2o');
    final (title, body) = switch (_step) {
      TutorialStep.welcome => (st.tutorialWelcome, st.tutorialWelcomeBody),
      TutorialStep.shelf => (st.tutorialShelf, st.tutorialShelfBody),
      TutorialStep.beaker => (st.tutorialBeaker, st.tutorialBeakerBody),
      TutorialStep.progress => (st.tutorialProgress, st.tutorialProgressBody),
      TutorialStep.demo => (st.tutorialDemo, st.tutorialDemoBody),
      TutorialStep.wrongChoice => (st.tutorialWrong, st.tutorialWrongBody),
      TutorialStep.reset => (st.tutorialReset, st.tutorialResetBody),
      TutorialStep.completion => (st.tutorialComplete, st.tutorialCompleteBody),
      TutorialStep.tryIt => switch (_lastWrong) {
          final w? => (st.tutorialTryWrong, '${st.tutorialTryWrongBody(s.chemical(w.actual), s.chemical(w.expected))} ${w.hint == null ? '' : s.tr(w.hint!)}'),
          null => (st.tutorialTry, st.tutorialTryBody(s.chemical(water))),
        },
      TutorialStep.wellDone => (st.tutorialWellDone, st.tutorialWellDoneBody),
    };

    return ChangeNotifierProvider<LabController>.value(
      value: _lab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(st.tutorialTitle),
          actions: [
            _Highlight(
              active: _step == TutorialStep.reset,
              radius: 24,
              child: IconButton(tooltip: s.restart, icon: const Icon(Icons.restart_alt_rounded), onPressed: _lab.reset),
            ),
            const LanguageToggle(),
          ],
        ),
        // On short phones or with a large font the page gets a minimum
        // height and scrolls, so the beaker and shelf never get squeezed out.
        body: LayoutBuilder(
          builder: (context, box) {
            final height = math.max(box.maxHeight, 520 * MediaQuery.textScalerOf(context).scale(14) / 14);
            return SingleChildScrollView(
              child: SizedBox(
                height: height,
                child: Stack(
                  key: _stackKey,
                  children: [
                    Column(
                      children: [
                        _Highlight(active: _step == TutorialStep.progress, child: const GoalStatusBar(compact: true)),
                        // Capped so the beaker keeps room on short phones and with a
                        // large font; past the cap the card's text scrolls.
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: height * 0.3),
                          child: _CoachCard(
                            title: title,
                            body: body,
                            index: _step.index + 1,
                            total: _pages.length,
                            warning: _step == TutorialStep.tryIt && _lastWrong != null,
                            actions: [
                              if (_step != TutorialStep.wellDone) TextButton(onPressed: _close, child: Text(st.skip)),
                              if (_step == TutorialStep.wellDone) TextButton(onPressed: _replay, child: Text(st.replay)),
                              if (_step == TutorialStep.wellDone)
                                FilledButton(onPressed: _close, child: Text(st.startLab))
                              else if (_step != TutorialStep.tryIt)
                                FilledButton(onPressed: _next, child: Text(_step == TutorialStep.welcome ? st.continueLabel : st.next)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 0.85,
                                child: _Highlight(
                                  active: _step == TutorialStep.beaker || _step == TutorialStep.wrongChoice,
                                  child: KeyedSubtree(key: _beakerKey, child: WorkstationBeaker(onChemicalDropped: _onDrop)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottles can only be dragged when it is the student's turn.
                        IgnorePointer(
                          ignoring: _step != TutorialStep.tryIt,
                          child: _Highlight(
                            active: _step == TutorialStep.shelf || _step == TutorialStep.tryIt,
                            child: KeyedSubtree(
                              key: _shelfKey,
                              child: ChemicalShelf(
                                chemicals: LabTutorial.practical.chemicals,
                                onChemicalTap: (c) => ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(s.chemical(c)))),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_step == TutorialStep.demo && _from != null && _to != null)
                      Positioned.fill(child: IgnorePointer(child: _DemoPointer(animation: _pointer, shelf: _from!, beaker: _to!, bottles: LabTutorial.practical.chemicals.length, index: 1))),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: LabColors.ink.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(10)),
                            child: Text(st.tutorialPracticeOnly, style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Draws a coloured outline around [child] while [active].
class _Highlight extends StatelessWidget {
  const _Highlight({required this.active, required this.child, this.radius = 18});

  final bool active;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: active ? LabColors.warning : Colors.transparent, width: 3),
      ),
      child: child,
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.title, required this.body, required this.index, required this.total, required this.actions, this.warning = false});

  final String title;
  final String body;
  final int index;
  final int total;
  final List<Widget> actions;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? LabColors.danger : LabColors.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The text scrolls when the card hits its height cap; the buttons
          // below always stay visible.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: AppText.display(15, color: color))),
                      Text(context.study.stepNofM(index, total), style: const TextStyle(fontSize: 12, color: LabColors.muted)),
                      const SizedBox(width: 6),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(height: 1.4, color: LabColors.ink)),
                ],
              ),
            ),
          ),
          Wrap(alignment: WrapAlignment.end, spacing: 4, children: actions),
        ],
      ),
    );
  }
}

/// A pointer that presses a bottle, carries it to the beaker and lets go —
/// only an animation; the real controller is not touched.
class _DemoPointer extends StatelessWidget {
  const _DemoPointer({required this.animation, required this.shelf, required this.beaker, required this.bottles, required this.index});

  final Animation<double> animation;
  final Rect shelf;
  final Rect beaker;
  final int bottles;

  /// Which bottle in the shelf row (0-based) is being dragged.
  final int index;

  @override
  Widget build(BuildContext context) {
    // ChemicalShelf spaces one row of bottles evenly; centre of bottle [index].
    const w = 72.0;
    final gap = (shelf.width - 24 - bottles * w) / (bottles + 1);
    final start = Offset(shelf.left + 12 + gap * (index + 1) + w * index + w / 2, shelf.top + 80);
    final end = beaker.center;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final move = Curves.easeInOut.transform(((t - 0.15) / 0.6).clamp(0.0, 1.0));
        final pos = Offset.lerp(start, end, move)!;
        final pressed = t > 0.1 && t < 0.8;
        final opacity = t > 0.9 ? (1 - t) * 10 : 1.0;
        return Stack(
          children: [
            if (pressed)
              Positioned(
                left: pos.dx - 18,
                top: pos.dy - 46,
                child: Opacity(
                  opacity: 0.85,
                  child: Transform.rotate(angle: -0.35, child: const Icon(Icons.science_rounded, size: 40, color: Color(0xFF7FA7C9))),
                ),
              ),
            Positioned(
              left: pos.dx - 6,
              top: pos.dy - 4,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: AnimatedScale(
                  scale: pressed ? 0.85 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.touch_app_rounded, size: 44, color: LabColors.ink),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
