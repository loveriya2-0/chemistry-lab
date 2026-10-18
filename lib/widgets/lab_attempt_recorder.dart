import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/practical_attempt_store.dart';
import '../models/practical_attempt.dart';
import '../models/practical_path.dart';
import '../state/focus_controller.dart';
import '../state/lab_controller.dart';

/// Records the lab visit below it as a [PracticalAttempt] when the route
/// closes. It only *watches* [LabController]; the lab itself is unchanged.
///
/// Each controller notification is exactly one of: a correct pour (step +1),
/// a wrong pour (mistakes +1, same step) or a reset (both back to 0), so the
/// tally can be read from state changes alone. Visits with no pours are not
/// saved.
///
/// Place it *above* [FocusSessionHost] so the host saves its session first
/// and the attempt can link to it.
class LabAttemptRecorder extends StatefulWidget {
  const LabAttemptRecorder({super.key, required this.path, required this.child});

  final PracticalPath path;
  final Widget child;

  @override
  State<LabAttemptRecorder> createState() => _LabAttemptRecorderState();
}

class _LabAttemptRecorderState extends State<LabAttemptRecorder> {
  late final LabController _lab;
  late final PracticalAttemptStore _store;
  late final FocusController? _focus;
  final DateTime _startedAt = DateTime.now();

  late int _prevStep;
  late int _prevMistakes;
  int _correct = 0;
  int _wrong = 0;
  int _completions = 0;
  int _bestSteps = 0;

  @override
  void initState() {
    super.initState();
    _lab = context.read<LabController>();
    _store = context.read<PracticalAttemptStore>();
    _focus = context.read<FocusController?>();
    _prevStep = _lab.stepIndex;
    _prevMistakes = _lab.mistakes;
    _lab.addListener(_onLabChanged);
  }

  void _onLabChanged() {
    final step = _lab.stepIndex;
    final mistakes = _lab.mistakes;
    if (step == _prevStep + 1) {
      _correct++;
      _bestSteps = math.max(_bestSteps, step);
      if (_lab.isComplete) _completions++;
    } else if (step == _prevStep && mistakes == _prevMistakes + 1) {
      _wrong++;
    }
    // Anything else is a reset; just resync.
    _prevStep = step;
    _prevMistakes = mistakes;
  }

  @override
  void dispose() {
    _lab.removeListener(_onLabChanged);
    if (_correct + _wrong > 0) {
      final path = widget.path;
      _store.add(PracticalAttempt(
        id: _startedAt.microsecondsSinceEpoch.toString(),
        startedAt: _startedAt,
        endedAt: DateTime.now(),
        boardId: path.boardId,
        classLevel: path.classLevel,
        chapterId: path.chapter?.id,
        topicId: path.topic?.id,
        listedPracticalId: path.listedPractical?.id,
        practicalId: path.practical.id,
        correctActions: _correct,
        wrongActions: _wrong,
        completions: _completions,
        bestSteps: _bestSteps,
        totalSteps: _lab.totalSteps,
        focusSessionId: _focus?.result?.id,
      ));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
