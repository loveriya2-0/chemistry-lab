import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a study focus session ended.
enum StudySessionStatus {
  /// The timer ran down to zero.
  completed,

  /// The student ended it early.
  ended,

  /// The app was closed or killed while it ran; saved on the next launch
  /// with the time counted up to the last checkpoint.
  interrupted;

  static StudySessionStatus parse(String value) => values.byName(value);
}

/// What a study session was for. Every field is optional: a session can
/// be for a class, a chapter, a topic or a listed practical.
@immutable
class StudyTarget {
  const StudyTarget({required this.boardId, this.classLevel, this.chapterId, this.topicId, this.practicalId});

  final String boardId;
  final int? classLevel;
  final String? chapterId;
  final String? topicId;

  /// A listed practical ("cbse-11-pE").
  final String? practicalId;

  Map<String, Object?> toJson() => {
        'boardId': boardId,
        'classLevel': classLevel,
        'chapterId': chapterId,
        'topicId': topicId,
        'practicalId': practicalId,
      };

  factory StudyTarget.fromJson(Map<String, Object?> json) => StudyTarget(
        boardId: json['boardId'] as String? ?? 'cbse',
        classLevel: json['classLevel'] as int?,
        chapterId: json['chapterId'] as String?,
        topicId: json['topicId'] as String?,
        practicalId: json['practicalId'] as String?,
      );
}

/// One study focus session (outside the lab). Lab focus sessions are
/// still saved as [FocusSession]s; summaries add the two together.
@immutable
class StudySession {
  const StudySession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.status,
    required this.target,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;

  /// Time the timer actually ran, excluding pauses.
  final int focusedSeconds;
  final StudySessionStatus status;
  final StudyTarget target;

  static const schemaVersion = 1;

  Map<String, Object?> toJson() => {
        'v': schemaVersion,
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'plannedSeconds': plannedSeconds,
        'focusedSeconds': focusedSeconds,
        'status': status.name,
        ...target.toJson(),
      };

  factory StudySession.fromJson(Map<String, Object?> json) => StudySession(
        id: json['id']! as String,
        startedAt: DateTime.parse(json['startedAt']! as String),
        endedAt: DateTime.parse(json['endedAt']! as String),
        plannedSeconds: json['plannedSeconds']! as int,
        focusedSeconds: json['focusedSeconds']! as int,
        status: StudySessionStatus.parse(json['status']! as String),
        target: StudyTarget.fromJson(json),
      );
}

/// Focus Mode preferences beyond the default length kept in [AppState].
class FocusSettings extends ChangeNotifier {
  FocusSettings(this._prefs);

  static const customKey = 'focus_custom_minutes';
  static const breakKey = 'focus_break_minutes';
  static const goalKey = 'focus_daily_goal_minutes';

  static const minMinutes = 5;
  static const maxMinutes = 180;
  static const minBreak = 1;
  static const maxBreak = 30;
  static const minGoal = 10;
  static const maxGoal = 600;

  final SharedPreferences _prefs;

  /// Clamps a session length to the allowed 5–180 minutes.
  static int validMinutes(int m) => m.clamp(minMinutes, maxMinutes);
  static int validBreak(int m) => m.clamp(minBreak, maxBreak);
  static int validGoal(int m) => m.clamp(minGoal, maxGoal);

  /// The student's own session length (used when "Custom" is picked).
  int get customMinutes => validMinutes(_prefs.getInt(customKey) ?? 25);
  int get breakMinutes => validBreak(_prefs.getInt(breakKey) ?? 5);
  int get dailyGoalMinutes => validGoal(_prefs.getInt(goalKey) ?? 30);

  void setCustomMinutes(int m) => _set(customKey, validMinutes(m));
  void setBreakMinutes(int m) => _set(breakKey, validBreak(m));
  void setDailyGoalMinutes(int m) => _set(goalKey, validGoal(m));

  void _set(String key, int value) {
    if (_prefs.getInt(key) == value) return;
    _prefs.setInt(key, value);
    notifyListeners();
  }
}

/// Saved study sessions plus the checkpoint of the one running now.
class StudySessionStore {
  StudySessionStore(this._prefs);

  static const storageKey = 'study_focus_sessions';
  static const activeKey = 'study_focus_active';

  final SharedPreferences _prefs;

  List<StudySession> all() {
    final out = <StudySession>[];
    for (final raw in _prefs.getStringList(storageKey) ?? const <String>[]) {
      try {
        out.add(StudySession.fromJson(jsonDecode(raw) as Map<String, Object?>));
      } catch (e) {
        debugPrint('Skipping unreadable study session: $e');
      }
    }
    return out;
  }

  /// Adds [session] unless a session with its id is already saved, so a
  /// session can never be counted twice.
  Future<void> add(StudySession session) async {
    if (all().any((s) => s.id == session.id)) return;
    await _prefs.setStringList(storageKey, [...?_prefs.getStringList(storageKey), jsonEncode(session.toJson())]);
  }

  /// Saves the running session's state so it survives the app being killed.
  Future<void> checkpoint(StudySession running) => _prefs.setString(activeKey, jsonEncode(running.toJson()));

  Future<void> clearCheckpoint() => _prefs.remove(activeKey);

  /// A session left running when the app was closed is saved as
  /// [StudySessionStatus.interrupted] with the time up to its last
  /// checkpoint. Returns it, or null if there was none (or no time ran).
  Future<StudySession?> recoverInterrupted() async {
    final raw = _prefs.getString(activeKey);
    if (raw == null) return null;
    await clearCheckpoint();
    try {
      final s = StudySession.fromJson(jsonDecode(raw) as Map<String, Object?>);
      if (s.focusedSeconds <= 0) return null;
      final saved = StudySession(
        id: s.id,
        startedAt: s.startedAt,
        endedAt: s.endedAt,
        plannedSeconds: s.plannedSeconds,
        focusedSeconds: s.focusedSeconds,
        status: StudySessionStatus.interrupted,
        target: s.target,
      );
      await add(saved);
      return saved;
    } catch (e) {
      debugPrint('Dropping unreadable focus checkpoint: $e');
      return null;
    }
  }
}

/// Phases of the study timer.
enum StudyTimerPhase { ready, focusing, paused, finished, onBreak, breakOver }

/// Countdown for one study session, then an optional break.
///
/// Time is measured from the clock, not by counting ticks, so a late or
/// skipped tick never changes the result. While focusing it checkpoints
/// every [checkpointEvery] so a killed app loses at most that much.
class StudyFocusController extends ChangeNotifier {
  StudyFocusController({
    required this.store,
    required this.target,
    required Duration duration,
    required this.breakDuration,
    DateTime Function()? clock,
    this.checkpointEvery = const Duration(seconds: 15),
    this.tick = const Duration(seconds: 1),
  })  : duration = Duration(minutes: FocusSettings.validMinutes(duration.inMinutes)),
        _clock = clock ?? DateTime.now;

  final StudySessionStore store;
  final StudyTarget target;
  final Duration duration;
  final Duration breakDuration;
  final Duration checkpointEvery;
  final Duration tick;
  final DateTime Function() _clock;

  StudyTimerPhase _phase = StudyTimerPhase.ready;
  DateTime? _startedAt;
  DateTime? _runningSince;
  Duration _banked = Duration.zero;
  DateTime? _lastCheckpoint;
  DateTime? _breakStarted;
  Timer? _timer;
  StudySession? _result;

  StudyTimerPhase get phase => _phase;
  bool get isRunning => _phase == StudyTimerPhase.focusing;
  bool get isPaused => _phase == StudyTimerPhase.paused;

  /// The saved session, once it is over.
  StudySession? get result => _result;

  Duration get focused {
    final run = _runningSince == null ? Duration.zero : _clock().difference(_runningSince!);
    final total = _banked + run;
    return total > duration ? duration : total;
  }

  Duration get remaining => duration - focused;
  double get progress => duration.inSeconds == 0 ? 1 : focused.inSeconds / duration.inSeconds;

  Duration get breakRemaining {
    if (_breakStarted == null) return breakDuration;
    final left = breakDuration - _clock().difference(_breakStarted!);
    return left.isNegative ? Duration.zero : left;
  }

  void start() {
    if (_phase != StudyTimerPhase.ready) return;
    _startedAt = _clock();
    _runningSince = _startedAt;
    _lastCheckpoint = _startedAt;
    _phase = StudyTimerPhase.focusing;
    _runTicker();
    _checkpoint();
    notifyListeners();
  }

  void pause() {
    if (_phase != StudyTimerPhase.focusing) return;
    _banked = focused;
    _runningSince = null;
    _phase = StudyTimerPhase.paused;
    _timer?.cancel();
    _checkpoint();
    notifyListeners();
  }

  void resume() {
    if (_phase != StudyTimerPhase.paused) return;
    _runningSince = _clock();
    _phase = StudyTimerPhase.focusing;
    _runTicker();
    notifyListeners();
  }

  /// Ends the session early (or saves it if it has just finished).
  /// Calling it again returns the first result unchanged.
  Future<StudySession?> end() async {
    if (_result != null) return _result;
    if (_phase == StudyTimerPhase.ready) return null;
    return _finish(StudySessionStatus.ended);
  }

  /// Checks the clock; finishes the session when time is up.
  void _onTick() {
    if (_phase == StudyTimerPhase.focusing) {
      if (remaining <= Duration.zero) {
        _finish(StudySessionStatus.completed);
        return;
      }
      final now = _clock();
      if (now.difference(_lastCheckpoint!) >= checkpointEvery) {
        _lastCheckpoint = now;
        _checkpoint();
      }
      notifyListeners();
    } else if (_phase == StudyTimerPhase.onBreak) {
      if (breakRemaining <= Duration.zero) {
        _timer?.cancel();
        _phase = StudyTimerPhase.breakOver;
      }
      notifyListeners();
    }
  }

  /// Test hook: runs one tick now.
  @visibleForTesting
  void tickNow() => _onTick();

  Future<StudySession?> _finish(StudySessionStatus status) async {
    _timer?.cancel();
    final seconds = focused.inSeconds;
    _banked = focused;
    _runningSince = null;
    _phase = StudyTimerPhase.finished;
    final session = StudySession(
      id: _startedAt!.microsecondsSinceEpoch.toString(),
      startedAt: _startedAt!,
      endedAt: _clock(),
      plannedSeconds: duration.inSeconds,
      focusedSeconds: seconds,
      status: status,
      target: target,
    );
    _result = session;
    notifyListeners();
    await store.clearCheckpoint();
    // A session ended before any time ran is not worth a record.
    if (seconds > 0) await store.add(session);
    return session;
  }

  void startBreak() {
    if (_phase != StudyTimerPhase.finished || breakDuration == Duration.zero) return;
    _breakStarted = _clock();
    _phase = StudyTimerPhase.onBreak;
    _runTicker();
    notifyListeners();
  }

  void skipBreak() {
    if (_phase != StudyTimerPhase.onBreak) return;
    _timer?.cancel();
    _phase = StudyTimerPhase.breakOver;
    notifyListeners();
  }

  void _checkpoint() {
    if (_startedAt == null) return;
    store.checkpoint(StudySession(
      id: _startedAt!.microsecondsSinceEpoch.toString(),
      startedAt: _startedAt!,
      endedAt: _clock(),
      plannedSeconds: duration.inSeconds,
      focusedSeconds: focused.inSeconds,
      status: StudySessionStatus.interrupted,
      target: target,
    ));
  }

  void _runTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => _onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Focus time per day, summed from lab focus sessions and study sessions.
@immutable
class FocusSummary {
  const FocusSummary({required this.todaySeconds, required this.week, required this.weekSeconds, required this.allTimeSeconds, required this.sessions});

  /// [days] are (day, seconds) of lab and study focus combined.
  factory FocusSummary.build({
    required Iterable<(DateTime, int)> entries,
    required DateTime now,
  }) {
    final list = entries.toList();
    DateTime day(DateTime t) {
      final l = t.toLocal();
      return DateTime(l.year, l.month, l.day);
    }

    final today = day(now);
    final week = [
      for (var i = 6; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          return (d, list.where((e) => day(e.$1) == d).fold(0, (sum, e) => sum + e.$2));
        }(),
    ];
    return FocusSummary(
      todaySeconds: week.last.$2,
      week: week,
      weekSeconds: week.fold(0, (sum, e) => sum + e.$2),
      allTimeSeconds: list.fold(0, (sum, e) => sum + e.$2),
      sessions: list.length,
    );
  }

  final int todaySeconds;

  /// Oldest first, ending today.
  final List<(DateTime, int)> week;
  final int weekSeconds;
  final int allTimeSeconds;
  final int sessions;
}
