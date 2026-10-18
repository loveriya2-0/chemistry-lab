import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/focus_session.dart';
import '../models/practical_path.dart';
import 'lab_controller.dart';

/// Countdown + action tally for one Focus Mode session.
///
/// It only *observes* drop results from [LabController]; validation stays
/// entirely in the lab controller.
class FocusController extends ChangeNotifier {
  FocusController({
    required this.path,
    required this.duration,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        _remaining = duration;

  /// Session lengths offered on the setup screen.
  static const options = [Duration(minutes: 10), Duration(minutes: 15)];

  final PracticalPath path;
  final Duration duration;
  final DateTime Function() _clock;

  Timer? _timer;
  DateTime? _startedAt;
  Duration _remaining;
  bool _paused = false;
  FocusSession? _result;

  int _correct = 0;
  int _wrong = 0;
  int _completions = 0;

  Duration get remaining => _remaining;
  bool get isPaused => _paused;
  bool get isStarted => _startedAt != null;
  bool get isTimeUp => _remaining == Duration.zero;

  /// Set once the session is over; no further changes after that.
  FocusSession? get result => _result;
  bool get hasEnded => _result != null;

  int get correctActions => _correct;
  int get wrongActions => _wrong;
  int get practicalsCompleted => _completions;

  /// 1 → 0 as time runs out (for the ring).
  double get remainingFraction => _remaining.inSeconds / duration.inSeconds;

  void start() {
    if (isStarted || hasEnded) return;
    _startedAt = _clock();
    _runTimer();
    notifyListeners();
  }

  void pause() {
    if (!isStarted || _paused || hasEnded) return;
    _paused = true;
    _timer?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!_paused || hasEnded) return;
    _paused = false;
    _runTimer();
    notifyListeners();
  }

  void togglePause() => _paused ? resume() : pause();

  /// Tallies the outcome of a drop that the lab already validated.
  void recordDrop(DropResult result) {
    if (hasEnded) return;
    switch (result) {
      case CorrectDrop():
        _correct++;
      case PracticalCompleted():
        _correct++;
        _completions++;
      case WrongDrop():
        _wrong++;
      // Burette actions are neither a finished step nor a mistake (passing
      // the end point gives a rough reading, as in a real lab).
      case IgnoredDrop() || TitrantReady() || TitrantAdded() || Overshot() || NeedsReset():
        return;
    }
    notifyListeners();
  }

  /// Stops the timer and freezes the session. Calling it again returns the
  /// first result unchanged.
  FocusSession finish(
    FocusStatus status, {
    required int stepsCompleted,
    required int totalSteps,
  }) {
    if (_result != null) return _result!;
    _timer?.cancel();
    final now = _clock();
    final startedAt = _startedAt ?? now;
    _result = FocusSession(
      id: startedAt.microsecondsSinceEpoch.toString(),
      startedAt: startedAt,
      endedAt: now,
      plannedSeconds: duration.inSeconds,
      focusedSeconds: (duration - _remaining).inSeconds,
      status: status,
      boardId: path.boardId,
      classLevel: path.classLevel,
      chapterId: path.chapter?.id,
      topicId: path.topic?.id,
      listedPracticalId: path.listedPractical?.id,
      practicalId: path.practical.id,
      correctActions: _correct,
      wrongActions: _wrong,
      practicalsCompleted: _completions,
      stepsCompleted: stepsCompleted,
      totalSteps: totalSteps,
    );
    notifyListeners();
    return _result!;
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining -= const Duration(seconds: 1);
      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        _timer?.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// "09:05" – timer digits are the same in English and Hindi.
String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
